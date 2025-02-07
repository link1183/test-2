from ldap3 import Server, Connection, SUBTREE, ALL
import re
import json
import sys
from typing import Dict, List, Any
import getpass


class LDAPGroupAnalyzer:
    def __init__(self, ldap_url: str, base_dn: str):
        self.server = Server(ldap_url, use_ssl=True, get_info=ALL)
        self.base_dn = base_dn
        self.conn = None

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

    def get_group_members(self, target_group: str) -> List[Dict[str, Any]]:
        if self.conn is None:
            return []

        try:
            print(f"Searching for group: {target_group}")
            group_filter = f"(&(objectClass=group)(cn={target_group}))"
            self.conn.search(self.base_dn, group_filter, SUBTREE, attributes=["member"])

            member_dns = []

            for entry in self.conn.entries:
                print(f"Found group: {entry.entry_dn}")
                if hasattr(entry, "member"):
                    member_dns.extend(entry.member.values)

            print(f"Found {len(member_dns)} direct members in the group")
            if member_dns:
                print(f"Sample member DN: {member_dns[0]}")

            main_group_members = set()
            for member_dn in member_dns:
                cn_match = re.search(r"CN=([^,]+)", member_dn)
                if cn_match:
                    main_group_members.add(cn_match.group(1))

            print(f"Extracted {len(main_group_members)} member CNs")
            if main_group_members:
                print(f"Sample member CN: {next(iter(main_group_members))}")

            # Get all groups these members belong to
            group_set = set()
            for member_cn in main_group_members:
                try:
                    print(f"Getting groups for member: {member_cn}")
                    member_filter = f"(cn={member_cn})"
                    self.conn.search(
                        self.base_dn, member_filter, SUBTREE, attributes=["memberOf"]
                    )

                    for entry in self.conn.entries:
                        if hasattr(entry, "memberOf"):
                            groups = []
                            for group_dn in entry.memberOf.values:
                                cn_match = re.search(r"CN=([^,]+)", group_dn)
                                if cn_match:
                                    groups.append(cn_match.group(1))
                            group_set.update(groups)
                            print(f"Found {len(groups)} groups for member {member_cn}")

                except Exception as e:
                    print(f"Error processing member {member_cn}: {e}")
                    continue

            print(f"Found {len(group_set)} total unique groups")

            # For each group, get all effective members
            groups_with_members = []

            for group_name in group_set:
                try:
                    # Get group type first
                    group_filter = f"(cn={group_name})"
                    self.conn.search(
                        self.base_dn,
                        group_filter,
                        SUBTREE,
                        attributes=["groupType", "member"],
                    )

                    is_security_group = False
                    group_members = set()

                    for entry in self.conn.entries:
                        print(f"Checking group: {group_name}")
                        if hasattr(entry, "groupType"):
                            group_type = int(entry.groupType.value)
                            is_security_group = (group_type & 0x80000000) != 0
                            print(
                                f"Group {group_name} is security group: {is_security_group}"
                            )

                        if hasattr(entry, "member"):
                            for member_dn in entry.member.values:
                                cn_match = re.search(r"CN=([^,]+)", member_dn)
                                if cn_match:
                                    group_members.add(cn_match.group(1))

                    if not is_security_group:
                        continue

                    # Find intersection with main group members
                    common_members = group_members.intersection(main_group_members)

                    if common_members:
                        # Get display names for common members
                        common_members_map = {}
                        for member_cn in common_members:
                            member_filter = f"(cn={member_cn})"
                            self.conn.search(
                                self.base_dn,
                                member_filter,
                                SUBTREE,
                                attributes=["displayName"],
                            )

                            for entry in self.conn.entries:
                                display_name = (
                                    entry.displayName.value
                                    if hasattr(entry, "displayName")
                                    else member_cn
                                )
                                common_members_map[member_cn] = display_name

                        print(
                            f"Group {group_name} has {len(common_members)} common members"
                        )
                        groups_with_members.append(
                            {
                                "name": group_name,
                                "commonMemberCount": len(common_members_map),
                                "commonMembers": sorted(common_members_map.values()),
                            }
                        )

                except Exception as e:
                    print(f"Error processing group {group_name}: {e}")
                    continue

            # Sort by common member count descending
            groups_with_members.sort(key=lambda x: x["commonMemberCount"], reverse=True)

            print(f"Found {len(groups_with_members)} relevant security groups")
            return groups_with_members

        except Exception as e:
            print(f"Error in get_group_members: {e}")
            return []


def main():
    LDAP_URL = "ldaps://dc1.ad.unil.ch:636"
    BASE_DN = "DC=ad,DC=unil,DC=ch"
    TARGET_GROUP = "tous-bcu-g"

    username = input("Username: ")
    password = getpass.getpass("Password: ")

    analyzer = LDAPGroupAnalyzer(LDAP_URL, BASE_DN)

    try:
        analyzer.connect(username, password)
        results = analyzer.get_group_members(TARGET_GROUP)

        print("\nResults:")
        print(json.dumps(results, indent=2, ensure_ascii=False))

        with open("group_analysis.json", "w", encoding="utf-8") as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
            print("\nResults saved to group_analysis.json")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
