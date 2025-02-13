import re
from ldap3 import ALL_ATTRIBUTES, Server, Connection, SUBTREE, ALL
import csv
import sys
from typing import Dict, List, Any, Set
import getpass
from enum import IntFlag
from dataclasses import dataclass
from collections import defaultdict


class GroupType(IntFlag):
    SYSTEM_CREATED = 0x00000001
    APP_BASIC = 0x00000010
    APP_QUERY = 0x00000020


@dataclass
class ADGroup:
    name: str
    cn: str
    dn: str
    group_type: int
    sam_account_type: int
    mail_enabled: bool
    hidden_from_gal: bool
    recipient_type: int
    member_count: int

    @classmethod
    def from_properties(
        cls, properties: Dict[str, Any], member_count: int = 0
    ) -> "ADGroup":
        group_type = int(properties.get("groupType", 0))

        return cls(
            name=properties.get("name", ""),
            cn=properties.get("cn", ""),
            dn=properties.get("distinguishedName", ""),
            group_type=group_type,
            sam_account_type=int(properties.get("sAMAccountType", 0)),
            mail_enabled=bool(properties.get("mail")),
            hidden_from_gal=bool(properties.get("msExchHideFromAddressLists", False)),
            recipient_type=int(properties.get("msExchRecipientDisplayType", 0)),
            member_count=member_count,
        )


class LDAPGroupAnalyzer:
    @staticmethod
    def _get_recipient_type(recipient_type: int) -> str:
        recipient_types = {
            0: "Regular Mailbox",
            1: "GAL Only User",
            6: "Mail Contact",
            7: "Mail User",
            1073741824: "Universal Security Group",  # 0x40000000
            2147483392: "Universal Distribution Group",
            -2147483642: "Non-Universal Security Group",
            -2147483390: "Non-Universal Distribution Group",
        }
        return recipient_types.get(recipient_type, f"Unknown ({hex(recipient_type)})")

    def __init__(self, ldap_url: str, base_dn: str):
        self.server = Server(ldap_url, use_ssl=True, get_info=ALL)
        self.base_dn = base_dn
        self.conn = None
        self.groups: Dict[str, ADGroup] = {}
        # Add caches
        self.member_cache: Dict[str, Set[str]] = {}
        self.group_properties_cache: Dict[str, Dict[str, Any]] = {}
        self.dn_to_cn_cache: Dict[str, str] = {}

    def connect(self, username: str, password: str):
        """Connect to LDAP server"""
        self.conn = Connection(
            self.server,
            user=f"{username}@ad.unil.ch",
            password=password,
            authentication="SIMPLE",
        )
        if not self.conn.bind():
            raise Exception(f"Failed to bind: {self.conn.result}")

    def batch_get_group_properties(
        self, group_names: List[str]
    ) -> Dict[str, Dict[str, Any]]:
        """Get properties for multiple groups in one query"""
        if not group_names or self.conn is None:
            return {}

        try:
            # Create OR filter for all groups
            group_filter = "(|" + "".join(f"(cn={name})" for name in group_names) + ")"
            self.conn.search(
                self.base_dn,
                f"(&(objectClass=group){group_filter})",
                SUBTREE,
                attributes=ALL_ATTRIBUTES,
            )

            results = {}
            for entry in self.conn.entries:
                props = {attr: entry[attr].value for attr in entry.entry_attributes}
                cn = props.get("cn", "")
                if cn:
                    results[cn] = props
                    self.dn_to_cn_cache[props.get("distinguishedName", "")] = cn
                    self.group_properties_cache[cn] = props

            return results

        except Exception as e:
            print(f"Error in batch get properties: {e}")
            return {}

    def get_all_group_members(self, group_dns: Set[str]) -> Dict[str, Set[str]]:
        """Get members for multiple groups in parallel"""
        if not group_dns or self.conn is None:
            return {}

        results = {}
        try:
            # Create filter for all groups
            group_filter = (
                "(|" + "".join(f"(distinguishedName={dn})" for dn in group_dns) + ")"
            )
            self.conn.search(
                self.base_dn,
                f"(&(objectClass=group){group_filter})",
                SUBTREE,
                attributes=["member", "distinguishedName", "objectClass"],
            )

            # First pass: collect direct members
            for entry in self.conn.entries:
                dn = entry.distinguishedName.value
                if hasattr(entry, "member"):
                    results[dn] = {member_dn for member_dn in entry.member.values}
                else:
                    results[dn] = set()

            # Second pass: resolve nested groups (up to 3 levels deep to prevent infinite recursion)
            for _ in range(3):
                changes_made = False
                for group_dn, members in results.items():
                    new_members = set()
                    for member_dn in members:
                        if member_dn in results:  # If member is a group
                            new_members.update(results[member_dn])
                    if new_members:
                        changes_made = True
                        members.update(new_members)
                if not changes_made:
                    break

            # Convert DNs to CNs
            final_results = {}
            for group_dn, members in results.items():
                final_results[group_dn] = set()
                for member_dn in members:
                    cn_match = re.search(r"CN=([^,]+)", member_dn, re.IGNORECASE)
                    if cn_match:
                        final_results[group_dn].add(cn_match.group(1).lower())
                self.member_cache[group_dn] = final_results[group_dn]

            return final_results

        except Exception as e:
            print(f"Error in batch get members: {e}")
            return {}

    def analyze_target_group(self, target_group: str):
        """Analyze target group and all related groups"""
        if self.conn is None:
            return

        try:
            print("Getting target group properties...")
            target_props = self.batch_get_group_properties([target_group])
            if not target_props:
                return

            target_dn = target_props[target_group]["distinguishedName"]

            print("Getting target group members...")
            all_members = self.get_all_group_members({target_dn})
            if not all_members:
                return

            target_members = all_members[target_dn]
            print(f"Found {len(target_members)} total members in target group")

            # Get related groups in batch
            print("Getting related groups...")
            # Split into chunks of 100 members to avoid LDAP size limits
            member_chunks = [
                list(target_members)[i : i + 100]
                for i in range(0, len(target_members), 100)
            ]
            related_groups = set()

            for i, chunk in enumerate(member_chunks, 1):
                member_filter = (
                    "(|" + "".join(f"(cn={member})" for member in chunk) + ")"
                )
                self.conn.search(
                    self.base_dn,
                    f"(&(objectClass=user){member_filter})",
                    SUBTREE,
                    attributes=["memberOf"],
                )

                for entry in self.conn.entries:
                    if hasattr(entry, "memberOf"):
                        for group_dn in entry.memberOf.values:
                            cn_match = re.search(r"CN=([^,]+)", group_dn)
                            if cn_match:
                                related_groups.add(cn_match.group(1))
                print(
                    f"Processed chunk {i}/{len(member_chunks)} ({len(related_groups)} groups found so far)"
                )

            print(f"Found {len(related_groups)} total related groups")

            # Batch get properties for all related groups
            print("Getting properties for all groups...")
            group_properties = self.batch_get_group_properties(list(related_groups))
            print(f"Retrieved properties for {len(group_properties)} groups")

            # Get all members for all groups at once
            group_dns = {
                props["distinguishedName"] for props in group_properties.values()
            }
            print(f"Getting members for {len(group_dns)} groups...")
            all_group_members = self.get_all_group_members(group_dns)

            # Create ADGroup objects
            processed_count = 0
            total_groups = len(group_properties)
            for group_name, properties in group_properties.items():
                group_dn = properties["distinguishedName"]
                members = all_group_members.get(group_dn, set())
                if members and target_members:
                    member_count = len(members.intersection(target_members))
                else:
                    member_count = 0

                self.groups[group_name] = ADGroup.from_properties(
                    properties, member_count=member_count
                )

                processed_count += 1
                if processed_count % 25 == 0:
                    print(f"Processed {processed_count}/{total_groups} groups")

            print(f"Analysis complete. Processed {total_groups} groups in total.")

        except Exception as e:
            print(f"Error analyzing target group: {e}")

    def generate_report(self, output_file: str = "group_analysis.md"):
        """Generate detailed report in Markdown format"""
        with open(output_file, "w", encoding="utf-8") as f:
            # Header
            f.write("# Active Directory Group Analysis\n\n")

            # Summary section
            total_groups = len(self.groups)
            mail_enabled = sum(1 for g in self.groups.values() if g.mail_enabled)
            hidden = sum(1 for g in self.groups.values() if g.hidden_from_gal)

            f.write("## Summary\n\n")
            f.write(f"- Total Groups: {total_groups}\n")
            f.write(f"- Mail-Enabled Groups: {mail_enabled}\n")
            f.write(f"- Hidden Groups: {hidden}\n\n")

            # Groups section
            f.write("## Groups\n\n")

            # Sort groups by member count
            sorted_groups = sorted(
                self.groups.values(), key=lambda g: g.member_count, reverse=True
            )

            for group in sorted_groups:
                f.write(f"### {group.name}\n\n")
                f.write("**Properties:**\n\n")
                f.write(f"- Distinguished Name: `{group.dn}`\n")
                f.write(f"- Member Count: {group.member_count}\n")
                f.write(f"- Mail Enabled: {group.mail_enabled}\n")
                f.write(f"- Hidden from GAL: {group.hidden_from_gal}\n")
                f.write(
                    f"- Recipient Type: {self._get_recipient_type(group.recipient_type)}\n\n"
                )

                members = self.member_cache.get(group.dn, set())
                if members:
                    f.write("**Members:**\n\n")
                    for member in sorted(members):
                        f.write(f"- {member}\n")
                else:
                    f.write("*No members*\n")
                f.write("\n---\n\n")

            print(f"Report generated: {output_file}")

    def generate_visual_report(self):
        """Generate visual representations of the group analysis"""
        import matplotlib.pyplot as plt
        import seaborn as sns

        # Set style and color palette
        plt.style.use("seaborn-v0_8-dark")
        colors = sns.color_palette("husl", 8)

        # Create figure with adjusted size and spacing
        fig = plt.figure(figsize=(20, 15))
        gs = fig.add_gridspec(2, 2, hspace=0.3, wspace=0.3)

        # 1. Member count distribution (horizontal bar chart)
        ax1 = fig.add_subplot(gs[0, :])  # Span both columns
        groups_by_members = sorted(
            self.groups.values(), key=lambda x: x.member_count, reverse=True
        )[:20]

        names = [g.name for g in groups_by_members]
        members = [g.member_count for g in groups_by_members]

        bars = ax1.barh(range(len(names)), members, color=colors[0])
        ax1.set_title("Top 20 Groups by Member Count", pad=20, fontsize=14)
        ax1.set_ylabel("Group Name", fontsize=12)
        ax1.set_xlabel("Number of Members", fontsize=12)
        plt.yticks(range(len(names)), names, fontsize=10)

        # Add value labels on the bars
        for bar in bars:
            width = bar.get_width()
            ax1.text(
                width,
                bar.get_y() + bar.get_height() / 2,
                f"{width:,}",
                ha="left",
                va="center",
                fontsize=10,
                fontweight="bold",
            )

        # 2. Mail Configuration (pie chart)
        ax2 = fig.add_subplot(gs[1, 0])
        mail_counts = {
            "Mail Enabled": sum(1 for g in self.groups.values() if g.mail_enabled),
            "Not Mail Enabled": sum(
                1 for g in self.groups.values() if not g.mail_enabled
            ),
        }
        ax2.pie(
            mail_counts.values(),
            labels=[
                f"{k}\n({v} groups, {v / sum(mail_counts.values()) * 100:.1f}%)"
                for k, v in mail_counts.items()
            ],
            colors=[colors[1], colors[2]],
            startangle=90,
        )
        ax2.set_title("Mail Configuration Distribution", pad=20, fontsize=14)

        # 3. Recipient Types (pie chart)
        ax3 = fig.add_subplot(gs[1, 1])
        recipient_counts = defaultdict(int)
        for group in self.groups.values():
            recipient_type = self._get_recipient_type(group.recipient_type)
            recipient_counts[recipient_type] += 1

        # Sort by count for better visualization
        sorted_recipients = dict(
            sorted(recipient_counts.items(), key=lambda x: x[1], reverse=True)
        )
        total_recipients = sum(sorted_recipients.values())

        ax3.pie(
            sorted_recipients.values(),
            labels=[
                f"{k}\n({v} groups, {v / total_recipients * 100:.1f}%)"
                for k, v in sorted_recipients.items()
            ],
            colors=colors[3:],
            startangle=90,
        )
        ax3.set_title("Recipient Type Distribution", pad=20, fontsize=14)

        # Add main title
        plt.suptitle("Active Directory Group Analysis", fontsize=16, y=0.95)

        # Save with high quality
        plt.savefig(
            "group_analysis.png", dpi=300, bbox_inches="tight", facecolor="white"
        )
        plt.close()

        print("Visual report generated: group_analysis.png")

    def generate_readme(self, report_file: str = "group_analysis.md"):
        """Generate a README with documentation and links to reports"""
        readme_content = """# Active Directory Group Analysis Tool

## Overview
This tool analyzes Active Directory groups and their memberships, providing detailed information about group configurations, types, and member relationships.

## Reports
- [Detailed Group Analysis](./{report_file}) - Full analysis of each group and its members
- [Visual Analysis](./group_analysis.png) - Visual representation of group statistics

![Group Analysis](./group_analysis.png)

## Property Explanations

### Group Properties
- **distinguishedName**: The unique LDAP path that identifies where the object is located in the directory
- **mailEnabled**: Whether the group can receive emails
- **hiddenFromGAL**: Whether the group is hidden from the Global Address List
- **memberCount**: Number of members in the group (including nested group members)

### Recipient Types
Each group has a specific recipient type that defines its behavior in Exchange:

{recipient_types}

## Statistics
Total number of analyzed groups: {total_groups}
- Mail-enabled groups: {mail_enabled}
- Groups hidden from GAL: {hidden}

## Understanding Group Types
The tool analyzes several aspects of each group:

### Mail Configuration
- **Mail-Enabled**: Groups that can receive email
- **Not Mail-Enabled**: Groups used for permissions only

### Visibility
- **Hidden from GAL**: Not visible in the Global Address List
- **Visible**: Appears in address lists and GAL

## Report Structure
The detailed report ([{report_file}](./{report_file})) contains:
1. Overall summary of analyzed groups
2. Detailed information for each group:
- Basic properties
- Configuration settings
- Complete member list
"""

        # Get recipient type explanations
        recipient_types = []
        for recipient_type in [
            0,
            1,
            6,
            7,
            1073741824,
            2147483392,
            -2147483642,
            -2147483390,
        ]:
            name = self._get_recipient_type(recipient_type)
            recipient_types.append(f"- `{hex(recipient_type)}`: {name}")

        # Format the content
        content = readme_content.format(
            report_file=report_file,
            recipient_types="\n".join(recipient_types),
            total_groups=len(self.groups),
            mail_enabled=sum(1 for g in self.groups.values() if g.mail_enabled),
            hidden=sum(1 for g in self.groups.values() if g.hidden_from_gal),
        )

        # Write to file
        with open("README.md", "w", encoding="utf-8") as f:
            f.write(content)

        print("README file generated.")


def main():
    LDAP_URL = "ldaps://dc1.ad.unil.ch:636"
    BASE_DN = "DC=ad,DC=unil,DC=ch"
    TARGET_GROUP = "tous-bcu-g"

    username = input("Username: ")
    password = getpass.getpass("Password: ")

    analyzer = LDAPGroupAnalyzer(LDAP_URL, BASE_DN)

    try:
        analyzer.connect(username, password)
        analyzer.analyze_target_group(TARGET_GROUP)
        analyzer.generate_report()
        analyzer.generate_visual_report()
        analyzer.generate_readme()

        print("Analysis complete.")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
