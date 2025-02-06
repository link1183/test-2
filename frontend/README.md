## Portail IT BCUL

Ce document explique comment maintenir l'application Portail IT BCUL, une application Flutter pour le web. Ce guide est destiné à ceux qui ne connaissent pas Flutter.

### Prérequis

- **Flutter** : Assurez-vous d'avoir Flutter installé sur votre machine. Vous pouvez suivre les instructions d'installation sur le site officiel de Flutter : [Installation de Flutter](https://flutter.dev/docs/get-started/install).
- **Docker** : L'application utilise Docker pour le déploiement. Assurez-vous d'avoir Docker installé : [Installation de Docker](https://docs.docker.com/get-docker/).

### Structure du Projet

Voici un aperçu des principaux fichiers et dossiers du projet :

- **lib/** : Contient le code source de l'application.
  - **middlewares/** : Contient les middlewares pour la gestion de l'authentification.
  - **routes.dart** : Définit les routes de l'application.
  - **screens/** : Contient les différentes pages de l'application.
    - **home/** : Contient les widgets et la logique pour la page d'accueil.
    - **login/** : Contient les widgets et la logique pour la page de connexion.
    - **shared/** : Contient les widgets partagés entre différentes pages (ex. : header, footer).
  - **theme/** : Contient les définitions de thèmes pour l'application.
- **assets/** : Contient les ressources statiques comme les images et les polices.
- **pubspec.yaml** : Fichier de configuration pour les dépendances Flutter.
- **Dockerfile** : Fichier de configuration pour la création de l'image Docker.
- **nginx.conf** : Configuration Nginx pour servir l'application Flutter.

### Installation des Dépendances

Pour installer les dépendances du projet, exécutez la commande suivante à la racine du projet :

```sh
flutter pub get
```

### Lancer l'Application en Local

Pour lancer l'application en mode développement, utilisez la commande suivante :

```sh
flutter run -d chrome
```

### Construction de l'Image Docker

Pour construire l'image Docker de l'application, exécutez les commandes suivantes :

```sh
docker build -t portail-it-bcul .
```

### Déploiement avec Docker

Pour déployer l'application en utilisant Docker, exécutez la commande suivante :

```sh
docker run -d -p 80:80 portail-it-bcul
```

### Configuration Nginx

Le fichier `nginx.conf` configure Nginx pour servir l'application Flutter et proxy les requêtes API vers un backend. Voici un extrait de la configuration :

```nginx
server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://backend:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Gestion de l'Authentification

L'application utilise un middleware pour gérer l'authentification. Le middleware vérifie le token stocké dans les préférences partagées et redirige l'utilisateur vers la page de connexion si le token est invalide.

### Thème de l'Application

Le thème de l'application est défini dans `lib/theme/theme.dart`. Vous pouvez personnaliser les couleurs et les styles de texte en modifiant ce fichier.

### Maintenance des Widgets

Les widgets sont les composants de base de l'interface utilisateur dans Flutter. Voici quelques widgets importants et leur rôle :

- **Header** : Affiche l'en-tête de l'application avec le logo et les informations utilisateur.
- **Footer** : Affiche le pied de page de l'application.
- **LoginForm** : Formulaire de connexion pour les utilisateurs.
- **CategorySection** : Affiche une section de catégories avec des liens.

### Conclusion

Ce guide fournit une vue d'ensemble de la maintenance de l'application Portail IT BCUL. Pour toute question ou assistance supplémentaire, veuillez consulter la documentation officielle de Flutter ou contacter l'équipe de développement.
