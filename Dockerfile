# Utiliser une image de base légère et sécurisée
FROM node:18-alpine

# Créer le répertoire de l'application
WORKDIR /usr/src/app

# Copier uniquement les fichiers nécessaires pour l'installation des dépendances
COPY app/package*.json ./

# Installer uniquement les dépendances de production
RUN npm install --only=production

# Copier le reste des fichiers de l'application
COPY app/ .

# Exposer le port de l'application
EXPOSE 3000

# Définir l'utilisateur non-root par sécurité (déjà présent dans l'image node)
USER node

# Commande de démarrage
CMD ["node", "server.js"]
