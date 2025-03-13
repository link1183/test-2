import 'package:backend/db/database_interface.dart';
import 'package:backend/db/migration/migration.dart';

/// Initial database schema migration
class InitialData extends Migration {
  InitialData() : super(2, 'Initial data');

  @override
  Future<void> down(DatabaseInterface db) async {
    log('Rolling back initial schema...');

    log('Initial schema rollback completed.');
  }

  @override
  Future<void> up(DatabaseInterface db) async {
    log('Inserting initial data...');

    // Insert data
    await db.execute('''
-- Insert statuses
INSERT INTO status (name) VALUES ('Active');
INSERT INTO status (name) VALUES ('Inactive');

-- Insert views
INSERT INTO view (name) VALUES ('si-bcu-g');
INSERT INTO view (name) VALUES ('User');

-- Insert categories
INSERT INTO categories (name) VALUES ('Applications métiers'),
 ('Monitoring'),
 ('Serveurs Web'),
 ('Virtualisation - BCUL'),
 ('Formulaires BCUL'),
 ('Formulaires UNIL'),
 ('Administration'),
 ('Lorawan'),
 ('Virtualisation - UNIL'),
 ('Mail'),
 ('Réseau'),
 ('Téléphonie'),
 ('Formations'),
 ('Utilitaires');

-- Insert managers
INSERT INTO link_manager (name, surname, link) VALUES 
 ('Bob', 'Brown', ''),
 ('John', 'Doe', ''),
 ('Jane', 'Smith', ''),
 ('Alice', 'Johnson', ''),
 ('Kevin', 'Pradervand', 'https://applications.unil.ch/intra/auth/php/Sy/SyPerInfo.php?PerNum=1184744'),
 ('Augustin', 'Schicker', 'https://applications.unil.ch/intra/auth/php/Sy/SyPerInfo.php?PerNum=1079784'),
 ('Brendan', 'Demierre', 'https://applications.unil.ch/intra/auth/php/Sy/SyPerInfo.php?PerNum=1279608');

-- Insert keywords
INSERT INTO keyword (keyword) VALUES ('gitlab'),
 ('monitoring'),
 ('virtualisation'),
 ('formulaires'),
 ('administration'),
 ('réseau'),
 ('téléphonie'),
 ('formations'),
 ('utilitaires'),
 ('web'),
 ('serveurs'),
 ('vMware'),
 ('grafana'),
 ('firewall'),
 ('dNS'),
 ('ip'),
 ('kubernetes'),
 ('passwords'),
 ('tickets'),
 ('inventaire'),
 ('stockage'),
 ('impression'),
 ('vulnérabilités'),
 ('sondes'),
 ('antennes'),
 ('restauration'),
 ('listes de diffusion'),
 ('annuaire'),
 ('web design'),
 ('microsoft store'),
 ('plans'),
 ('code'),
 ('support');

-- insert links and their relationships
-- applications métiers
insert into link (link, title, description, doc_link, status_id, category_id) values ('https://gitlab-bcul.unil.ch', 'gitlab', 'le gitlab de la bcul', 'https://docs.gitlab.com/', 1, 1);
insert into link_managers_links (link_id, manager_id) values (1, 1);
insert into links_views (link_id, view_id) values (1, 1);
insert into keywords_links (link_id, keyword_id) values (1, 1);
insert into keywords_links (link_id, keyword_id) values (1, 32);
insert into keywords_links (link_id, keyword_id) values (1, 31);
insert into keywords_links (link_id, keyword_id) values (1, 30);
insert into keywords_links (link_id, keyword_id) values (1, 29);
insert into keywords_links (link_id, keyword_id) values (1, 28);
insert into keywords_links (link_id, keyword_id) values (1, 18);
insert into keywords_links (link_id, keyword_id) values (1, 19);
insert into keywords_links (link_id, keyword_id) values (1, 20);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://appm-bookstack.prduks-bcul-ci4881-limited.uks.unil.ch/', 'bookstack', 'bookstack - le wiki de la bcul', 'https://www.bookstackapp.com/docs/', 1, 1);
insert into link_managers_links (link_id, manager_id) values (2, 1);
insert into links_views (link_id, view_id) values (2, 1);
insert into keywords_links (link_id, keyword_id) values (2, 1);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://itop-bcul.unil.ch/itop', 'itop', 'itop - application d''inventaire', 'https://www.itophub.io/wiki/page', 1, 1);
insert into link_managers_links (link_id, manager_id) values (3, 1);
insert into link_managers_links (link_id, manager_id) values (3, 2);
insert into links_views (link_id, view_id) values (3, 1);
insert into keywords_links (link_id, keyword_id) values (3, 1);
insert into keywords_links (link_id, keyword_id) values (3, 32);
insert into keywords_links (link_id, keyword_id) values (3, 31);
insert into keywords_links (link_id, keyword_id) values (3, 30);
insert into keywords_links (link_id, keyword_id) values (3, 29);
insert into keywords_links (link_id, keyword_id) values (3, 28);
insert into keywords_links (link_id, keyword_id) values (3, 18);
insert into keywords_links (link_id, keyword_id) values (3, 19);
insert into keywords_links (link_id, keyword_id) values (3, 20);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://apps-ocsinventory.prduks-bcul-ci4881-limited.uks.unil.ch/ocsreports/', 'ocs inventory', 'application d''inventaire des laptops', 'https://wiki.ocsinventory-ng.org/', 1, 1);
insert into link_managers_links (link_id, manager_id) values (4, 1);
insert into links_views (link_id, view_id) values (4, 1);
insert into keywords_links (link_id, keyword_id) values (4, 20);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://portal.uks.unil.ch/dashboard/auth/printin?timed-out', 'uks portal', 'portail de gestion des pods kubernetes', 'https://rancher.com/docs/', 1, 1);
insert into link_managers_links (link_id, manager_id) values (5, 1);
insert into links_views (link_id, view_id) values (5, 1);
insert into keywords_links (link_id, keyword_id) values (5, 17);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://apps-passbolt.prduks-bcul-ci4881-limited.uks.unil.ch/app/passwords', 'passbolt', 'gestionnaire de mots de passe bcul', 'https://www.passbolt.com/docs/', 1, 1);
insert into link_managers_links (link_id, manager_id) values (6, 1);
insert into links_views (link_id, view_id) values (6, 1);
insert into keywords_links (link_id, keyword_id) values (6, 18);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://helpdesk.unil.ch/otobo', 'otobo', 'interface de gestion des tickets', 'https://doc.otobo.org/', 1, 1);
insert into link_managers_links (link_id, manager_id) values (7, 1);
insert into links_views (link_id, view_id) values (7, 1);
insert into keywords_links (link_id, keyword_id) values (7, 33);
insert into keywords_links (link_id, keyword_id) values (7, 18);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://discord.gg/6vwfw3j6r4', 'discord', 'lien vers le serveur discord du service.', 'https://discord.com/developers/docs/intro', 1, 1);
insert into link_managers_links (link_id, manager_id) values (8, 1);
insert into links_views (link_id, view_id) values (8, 1);
insert into keywords_links (link_id, keyword_id) values (8, 1);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/ressource-inf/itop-inventory/index.php', 'application inventaire', 'application de scan d''inventaire connectée à itop', 'https://google.com', 1, 1);
insert into link_managers_links (link_id, manager_id) values (9, 1);
insert into link_managers_links (link_id, manager_id) values (9, 2);
insert into link_managers_links (link_id, manager_id) values (9, 3);
insert into link_managers_links (link_id, manager_id) values (9, 4);
insert into link_managers_links (link_id, manager_id) values (9, 5);
insert into link_managers_links (link_id, manager_id) values (9, 6);
insert into links_views (link_id, view_id) values (9, 1);
insert into keywords_links (link_id, keyword_id) values (9, 1);
insert into keywords_links (link_id, keyword_id) values (9, 32);
insert into keywords_links (link_id, keyword_id) values (9, 31);
insert into keywords_links (link_id, keyword_id) values (9, 30);
insert into keywords_links (link_id, keyword_id) values (9, 29);
insert into keywords_links (link_id, keyword_id) values (9, 28);
insert into keywords_links (link_id, keyword_id) values (9, 18);
insert into keywords_links (link_id, keyword_id) values (9, 19);
insert into keywords_links (link_id, keyword_id) values (9, 20);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://ephoto-bcul.unil.ch', 'e-photo', 'application e-photo de stockage de photos', '', 1, 1);
insert into link_managers_links (link_id, manager_id) values (10, 1);
insert into links_views (link_id, view_id) values (10, 1);
insert into keywords_links (link_id, keyword_id) values (10, 21);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://printunil-uniflow.unil.ch/pwbudget/', 'uniflow', 'application de gestion des crédits d''impression printunil sur les campus card', '', 1, 1);
insert into link_managers_links (link_id, manager_id) values (11, 1);
insert into links_views (link_id, view_id) values (11, 1);
insert into keywords_links (link_id, keyword_id) values (11, 22);

-- monitoring
insert into link (link, title, description, doc_link, status_id, category_id) values ('https://apps-grafana.prduks-bcul-ci4881-limited.uks.unil.ch/printin', 'grafana bcul', 'monitoring grafana de la bcul', 'https://grafana.com/docs/', 1, 2);
insert into link_managers_links (link_id, manager_id) values (12, 1);
insert into links_views (link_id, view_id) values (12, 1);
insert into keywords_links (link_id, keyword_id) values (12, 13);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://status-bcul.unil.ch/', 'cachet - application de statuts des serveurs bcul', 'application permettant la vérification des status serveur.', '', 1, 2);
insert into link_managers_links (link_id, manager_id) values (13, 1);
insert into links_views (link_id, view_id) values (13, 1);
insert into keywords_links (link_id, keyword_id) values (13, 2);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://tenable-sc.unil.ch/', 'tenable - surveillance des vulnérabilités (soc)', 'soc de surveillance des vulnérabilités des serveurs.', 'https://docs.tenable.com/', 1, 2);
insert into link_managers_links (link_id, manager_id) values (14, 1);
insert into links_views (link_id, view_id) values (14, 1);
insert into keywords_links (link_id, keyword_id) values (14, 23);

-- serveurs web
insert into link (link, title, description, doc_link, status_id, category_id) values ('https://webext-apache.prduks-bcul-ci4881.uks.unil.ch/', 'externe', 'serveur web externe', '', 1, 3);
insert into link_managers_links (link_id, manager_id) values (15, 1);
insert into links_views (link_id, view_id) values (15, 1);
insert into keywords_links (link_id, keyword_id) values (15, 10);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/', 'interne', 'serveur web interne', '', 1, 3);
insert into link_managers_links (link_id, manager_id) values (16, 1);
insert into links_views (link_id, view_id) values (16, 1);
insert into keywords_links (link_id, keyword_id) values (16, 10);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/index-it.html', 'it', 'serveur web interne du service it', '', 1, 3);
insert into link_managers_links (link_id, manager_id) values (17, 1);
insert into links_views (link_id, view_id) values (17, 1);
insert into keywords_links (link_id, keyword_id) values (17, 10);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://webtest-apache.prduks-bcul-ci4881-limited.uks.unil.ch/', 'test', 'serveur web test', '', 1, 3);
insert into link_managers_links (link_id, manager_id) values (18, 1);
insert into links_views (link_id, view_id) values (18, 1);
insert into keywords_links (link_id, keyword_id) values (18, 10);

-- virtualisation - bcul
insert into link (link, title, description, doc_link, status_id, category_id) values ('https://vcsa-vdi-bcul.unil.ch/', 'vcsa vdi', 'vcsa vdi', 'https://docs.vmware.com/en/vmware-vsphere/index.html', 1, 4);
insert into link_managers_links (link_id, manager_id) values (19, 1);
insert into links_views (link_id, view_id) values (19, 1);
insert into keywords_links (link_id, keyword_id) values (19, 12);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://vcsa-prd-bcul.unil.ch/', 'vcsa prd', 'vcsa prd', 'https://docs.vmware.com/en/vmware-vsphere/index.html', 1, 4);
insert into link_managers_links (link_id, manager_id) values (20, 1);
insert into links_views (link_id, view_id) values (20, 1);
insert into keywords_links (link_id, keyword_id) values (20, 12);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://vco-bcul.unil.ch/admin/', 'vco bcul', 'vco bcul', 'https://docs.vmware.com/fr/vmware-sd-wan/index.html', 1, 4);
insert into link_managers_links (link_id, manager_id) values (21, 1);
insert into links_views (link_id, view_id) values (21, 1);
insert into keywords_links (link_id, keyword_id) values (21, 12);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://av-bcul.unil.ch/printin', 'app volumes', 'app volumes', 'https://docs.vmware.com/en/vmware-app-volumes/index.html', 1, 4);
insert into link_managers_links (link_id, manager_id) values (22, 1);
insert into links_views (link_id, view_id) values (22, 1);
insert into keywords_links (link_id, keyword_id) values (22, 12);

-- formulaires bcul
insert into link (link, title, description, doc_link, status_id, category_id) values ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/forms/informatique/formulaire-pret.html', 'bcul - formulaire de prêt', 'formulaire de prêt de matériel', '', 1, 5);
insert into link_managers_links (link_id, manager_id) values (23, 1);
insert into links_views (link_id, view_id) values (23, 1);
insert into keywords_links (link_id, keyword_id) values (23, 4);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://webext-apache.prduks-bcul-ci4881.uks.unil.ch/forms/manuscrits/formulaire-manuscrit.html', 'manuscrits - demande de consultation', 'formulaire de demande de consultation de manuscrits', '', 1, 5);
insert into link_managers_links (link_id, manager_id) values (24, 1);
insert into links_views (link_id, view_id) values (24, 1);
insert into keywords_links (link_id, keyword_id) values (24, 4);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/forms/informatique/formulaire-entree.html', 'rh - entrée d''un collaborateur', 'formulaire d''entrée d''un collaborateur', '', 1, 5);
insert into link_managers_links (link_id, manager_id) values (25, 1);
insert into links_views (link_id, view_id) values (25, 1);
insert into keywords_links (link_id, keyword_id) values (25, 4);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/forms/informatique/formulaire-sortie.html', 'rh - sortie d''un collaborateur', 'formulaire de sortie d''un collaborateur', '', 1, 5);
insert into link_managers_links (link_id, manager_id) values (26, 1);
insert into links_views (link_id, view_id) values (26, 1);
insert into keywords_links (link_id, keyword_id) values (26, 4);

-- formulaires bcul (continued)
insert into link (link, title, description, doc_link, status_id, category_id) values ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/forms/informatique/formulaire-prolongation.html', 'rh - prolongation d''un collaborateur', 'formulaire de prolongation d''un collaborateur', '', 1, 5);
insert into link_managers_links (link_id, manager_id) values (27, 1);
insert into links_views (link_id, view_id) values (27, 1);
insert into keywords_links (link_id, keyword_id) values (27, 4);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/forms/rh/formulaire-accident.html', 'rh - déclaration d''accident', 'formulaire de déclaration d''accident', '', 1, 5);
insert into link_managers_links (link_id, manager_id) values (28, 1);
insert into links_views (link_id, view_id) values (28, 1);
insert into keywords_links (link_id, keyword_id) values (28, 4);

-- formulaires unil
insert into link (link, title, description, doc_link, status_id, category_id) values ('https://www2.unil.ch/dbcm-adm/siteformulaires/cde_materiel_unil2018.pdf', 'formulaire achats unil', 'formulaire à remplir pour les demandes d''achats à l''unil', '', 1, 6);
insert into link_managers_links (link_id, manager_id) values (29, 1);
insert into links_views (link_id, view_id) values (29, 1);
insert into keywords_links (link_id, keyword_id) values (29, 4);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://unil.ch/ci/id', 'compte informatique unil', 'toutes les opérations concernant les comptes informatiques', '', 1, 6);
insert into link_managers_links (link_id, manager_id) values (30, 1);
insert into links_views (link_id, view_id) values (30, 1);
insert into keywords_links (link_id, keyword_id) values (30, 4);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://www2.unil.ch/ci/forms_otrs/comptes/acces_intranet/acces_intranet.php', 'accès intranet unil', 'formulaire de demande d''accès à l''intranet unil', '', 1, 6);
insert into link_managers_links (link_id, manager_id) values (31, 1);
insert into links_views (link_id, view_id) values (31, 1);
insert into keywords_links (link_id, keyword_id) values (31, 4);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://www2.unil.ch/ci/forms_otrs/reseau/request.php', 'formulaire de demande de réseau de l''unil', 'formulaire de demande de réseau de l''unil', '', 1, 6);
insert into link_managers_links (link_id, manager_id) values (32, 1);
insert into links_views (link_id, view_id) values (32, 1);
insert into keywords_links (link_id, keyword_id) values (32, 4);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://www.unil.ch/ci/voip', 'activation téléphonie teams', 'permet d''activer la téléphonie sur teams', '', 1, 6);
insert into link_managers_links (link_id, manager_id) values (33, 1);
insert into links_views (link_id, view_id) values (33, 1);
insert into keywords_links (link_id, keyword_id) values (33, 7);

-- administration
insert into link (link, title, description, doc_link, status_id, category_id) values ('http://jbm6-bcul.ad.unil.ch/workflow/default.aspx?tick=988', 'jbm workflow', 'application jbm workflow permettant de noter les heures effectuées', '', 1, 7);
insert into link_managers_links (link_id, manager_id) values (34, 1);
insert into links_views (link_id, view_id) values (34, 1);
insert into keywords_links (link_id, keyword_id) values (34, 5);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://applications.unil.ch/intra/auth/php/sy/symenu.php', 'intranet unil', 'accès à sylvia - l''intranet de l''unil', '', 1, 7);
insert into link_managers_links (link_id, manager_id) values (35, 1);
insert into links_views (link_id, view_id) values (35, 1);
insert into keywords_links (link_id, keyword_id) values (35, 5);

-- lorawan
insert into link (link, title, description, doc_link, status_id, category_id) values ('http://lorawan01.unil.ch:3000/printin', 'dashboard grafana lorawan', 'dashboard de monitoring des sondes lorawan', 'https://grafana.com/docs/', 1, 8);
insert into link_managers_links (link_id, manager_id) values (36, 1);
insert into links_views (link_id, view_id) values (36, 1);
insert into keywords_links (link_id, keyword_id) values (36, 13);

insert into link (link, title, description, doc_link, status_id, category_id) values ('http://lorawan01.unil.ch:8086/signin', 'base de données influxdb', 'base de données des sondes lorawan', 'https://docs.influxdata.com/influxdb/v2/', 1, 8);
insert into link_managers_links (link_id, manager_id) values (37, 1);
insert into links_views (link_id, view_id) values (37, 1);
insert into keywords_links (link_id, keyword_id) values (37, 24);

insert into link (link, title, description, doc_link, status_id, category_id) values ('http://lorawan01.unil.ch:8080/#/printin', 'gateway des antennes lorawan', 'gateway de gestion des sondes lorawan', 'https://www.chirpstack.io/docs/', 1, 8);
insert into link_managers_links (link_id, manager_id) values (38, 1);
insert into links_views (link_id, view_id) values (38, 1);
insert into keywords_links (link_id, keyword_id) values (38, 25);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://crypto.unil.ch/secubat', 'extuni gestion mcr unibat', 'extuni gestion mcr unibat', '', 1, 8);
insert into link_managers_links (link_id, manager_id) values (39, 1);
insert into links_views (link_id, view_id) values (39, 1);
insert into keywords_links (link_id, keyword_id) values (39, 5);

-- virtualisation - unil
insert into link (link, title, description, doc_link, status_id, category_id) values ('https://xaas-di.vra.unil.ch/', 'gestion des vm ci unil (xaas)', 'l''application aria permet de simplifier et d''automatiser la gestion du cycle de vie des machines virtuelles (vm). notamment sur le provisionnement et sur les opérations de gestion.', 'https://wiki.unil.ch/ci/books/hebergement-de-machines-virtuelles-vm-hors-recherche/chapter/doc-publique', 1, 9);
insert into link_managers_links (link_id, manager_id) values (40, 1);
insert into links_views (link_id, view_id) values (40, 1);
insert into keywords_links (link_id, keyword_id) values (40, 12);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://vcsa.unil.ch', 'gestion des vm ci unil (vcsa)', 'vsca unil', 'https://docs.vmware.com/en/vmware-vsphere/index.html', 1, 9);
insert into link_managers_links (link_id, manager_id) values (41, 1);
insert into links_views (link_id, view_id) values (41, 1);
insert into keywords_links (link_id, keyword_id) values (41, 12);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://prdvdiu-vcsa02.unil.ch/', 'vsphere vdi unil', 'vsphere vdi unil', 'https://docs.vmware.com/fr/vmware-vsphere/index.html', 1, 9);
insert into link_managers_links (link_id, manager_id) values (42, 1);
insert into links_views (link_id, view_id) values (42, 1);
insert into keywords_links (link_id, keyword_id) values (42, 12);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://vdiu-srvco-max.unil.ch/admin/#/printin', 'vmware horizon unil', 'vmware horizon unil', '', 1, 9);
insert into link_managers_links (link_id, manager_id) values (43, 1);
insert into links_views (link_id, view_id) values (43, 1);
insert into keywords_links (link_id, keyword_id) values (43, 12);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://cohesity01.unil.ch/', 'cohesity', 'restauration de fichiers et de vm unil', 'https://docs.cohesity.com/ui/', 1, 9);
insert into link_managers_links (link_id, manager_id) values (44, 1);
insert into links_views (link_id, view_id) values (44, 1);
insert into keywords_links (link_id, keyword_id) values (44, 26);

-- mail
insert into link (link, title, description, doc_link, status_id, category_id) values ('https://sympa.unil.ch/sympa/home', 'listes de diffusion', 'listes de diffusion de l''unil', '', 1, 10);
insert into link_managers_links (link_id, manager_id) values (45, 1);
insert into links_views (link_id, view_id) values (45, 1);
insert into keywords_links (link_id, keyword_id) values (45, 27);

-- réseau
insert into link (link, title, description, doc_link, status_id, category_id) values ('https://web-auth.unil.ch/', 'authentification firewall unil', 'permet de s''authentifier sur le firewall de l''unil et de se connecter sur leur différents services', '', 1, 11);
insert into link_managers_links (link_id, manager_id) values (46, 1);
insert into links_views (link_id, view_id) values (46, 1);
insert into keywords_links (link_id, keyword_id) values (46, 14);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://www.unil.ch/ci/home/menuinst/cataprintue-de-services/reseau-et-telephonie/firewall-as-a-service/acceder-au-service.html', 'règles firewall (faas)', 'ajout, suppression et modification de règles pour le firewall de l''unil', '', 1, 11);
insert into link_managers_links (link_id, manager_id) values (47, 1);
insert into links_views (link_id, view_id) values (47, 1);
insert into keywords_links (link_id, keyword_id) values (47, 14);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://www.unil.ch/ci/fr/home/menuinst/cataprintue-de-services/reseau-et-telephonie/demande-d-ip-fixe.html', 'demande d''ip fixe et dns', 'pour effectuer une demande d''ip fixe et/ou de dns pour un serveur/pc/vm', '', 1, 11);
insert into link_managers_links (link_id, manager_id) values (48, 1);
insert into links_views (link_id, view_id) values (48, 1);
insert into keywords_links (link_id, keyword_id) values (48, 15);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://www2.unil.ch/ci/reseau/hosts_unil.arp', 'adresses ip unil (arp)', 'table arp regroupant toutes les adresses ip de l''unil (et les réseaux).', 'https://en.wikipedia.org/wiki/address_resolution_protocol', 1, 11);
insert into link_managers_links (link_id, manager_id) values (49, 1);
insert into links_views (link_id, view_id) values (49, 1);
insert into keywords_links (link_id, keyword_id) values (49, 16);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://apps-unificheck.prduks-bcul-ci4881-limited.uks.unil.ch/', 'portail unifi', 'portail unifi vers les devices unifi des différents sites bcul', 'https://help.ui.com/hc/en-us/categories/6583256751383-unifi', 1, 11);
insert into link_managers_links (link_id, manager_id) values (50, 1);
insert into links_views (link_id, view_id) values (50, 1);
insert into keywords_links (link_id, keyword_id) values (50, 14);

-- téléphonie
insert into link (link, title, description, doc_link, status_id, category_id) values ('https://www.unil.ch/ci/fr/home/menuinst/cataprintue-de-services/reseau-et-telephonie.html', 'formulaires unil de téléphonie', 'formulaires diverses concernant la téléphonie à l''unil', '', 1, 12);
insert into link_managers_links (link_id, manager_id) values (51, 1);
insert into links_views (link_id, view_id) values (51, 1);
insert into keywords_links (link_id, keyword_id) values (51, 7);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://annuaire.unil.ch/', 'annuaire unil', 'annuaire de l''unil', '', 1, 12);
insert into link_managers_links (link_id, manager_id) values (52, 1);
insert into links_views (link_id, view_id) values (52, 1);
insert into keywords_links (link_id, keyword_id) values (52, 28);

-- formations
insert into link (link, title, description, doc_link, status_id, category_id) values ('https://www.eni-training.com/instant-connection/default.aspx?wslogin=tmru6e1wya1ieitdutlxrg%3d%3d&wspwd=m3ojuzgox9afmgcblpka6g%3d%3d&iddomain=239&idgroup=168078', 'eni-training', 'plateforme de formation eni-training', '', 1, 13);
insert into link_managers_links (link_id, manager_id) values (53, 1);
insert into links_views (link_id, view_id) values (53, 1);
insert into keywords_links (link_id, keyword_id) values (53, 8);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://www.pressreader.com/', 'pressreader', 'plateforme de cataprintue de journaux pressreader', '', 1, 13);
insert into link_managers_links (link_id, manager_id) values (54, 1);
insert into links_views (link_id, view_id) values (54, 1);
insert into keywords_links (link_id, keyword_id) values (54, 8);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://www.elephorm.com/', 'elephorm', 'plateforme de formation elephorm', '', 1, 13);
insert into link_managers_links (link_id, manager_id) values (55, 1);
insert into links_views (link_id, view_id) values (55, 1);
insert into keywords_links (link_id, keyword_id) values (55, 8);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://www.alphorm.com/', 'alphorm', 'plateforme de formation alphorm', '', 1, 13);
insert into link_managers_links (link_id, manager_id) values (56, 1);
insert into links_views (link_id, view_id) values (56, 1);
insert into keywords_links (link_id, keyword_id) values (56, 24);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://www.packtpub.com/', 'packtpub', 'plateforme de formation packtpub', '', 1, 13);
insert into link_managers_links (link_id, manager_id) values (57, 2);
insert into links_views (link_id, view_id) values (57, 1);
insert into keywords_links (link_id, keyword_id) values (57, 24);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://m3.material.io/', 'material - web design', 'système de web design créé par google.', '', 1, 14);
insert into link_managers_links (link_id, manager_id) values (58, 3);
insert into links_views (link_id, view_id) values (58, 1);
insert into keywords_links (link_id, keyword_id) values (58, 25);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://store.rg-adguard.net/', 'microsoft store bypass', 'lien permettant de télécharger des applications du microsoft store sans passer par celui-ci', '', 1, 14);
insert into link_managers_links (link_id, manager_id) values (59, 4);
insert into links_views (link_id, view_id) values (59, 1);
insert into keywords_links (link_id, keyword_id) values (59, 25);

insert into link (link, title, description, doc_link, status_id, category_id) values ('https://planete.unil.ch/', 'planete unil', 'plans de l''unil', '', 1, 14);
insert into link_managers_links (link_id, manager_id) values (60, 1);
insert into links_views (link_id, view_id) values (60, 1);
insert into keywords_links (link_id, keyword_id) values (60, 25);''');

    log('Initial data migration completed.');
  }
}
