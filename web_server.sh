#!/bin/bash

# Définir les couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages de progression
progress() {
    echo -e "${BLUE}[PROGRESS]${NC} $1"
}

# Fonction pour afficher les messages d'erreur
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction pour afficher les messages de succès
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Fonction pour afficher les messages d'avertissement
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Mettre à jour les paquets
progress "Mise à jour des paquets..."
sudo apt-get update -qq
if [ $? -ne 0 ]; then
    error "Échec de la mise à jour des paquets."
    exit 1
fi
success "Mise à jour des paquets terminée."

# Installer Apache
progress "Installation d'Apache..."
sudo apt-get install -y apache2
if [ $? -ne 0 ]; then
    error "Échec de l'installation d'Apache."
    exit 1
fi
success "Installation d'Apache terminée."

# Installer MySQL
progress "Installation de MySQL..."
sudo apt-get install -y mysql-server
if [ $? -ne 0 ]; then
    error "Échec de l'installation de MySQL."
    exit 1
fi
success "Installation de MySQL terminée."

# Installer PHP
progress "Installation de PHP..."
sudo apt-get install -y php libapache2-mod-php php-mysql
if [ $? -ne 0 ]; then
    error "Échec de l'installation de PHP."
    exit 1
fi
success "Installation de PHP terminée."

# Activer les modules Apache
progress "Activation des modules Apache..."
sudo a2enmod php
sudo a2enmod rewrite
if [ $? -ne 0 ]; then
    error "Échec de l'activation des modules Apache."
    exit 1
fi
success "Activation des modules Apache terminée."

# Redémarrer Apache
progress "Redémarrage d'Apache..."
sudo systemctl restart apache2
if [ $? -ne 0 ]; then
    error "Échec du redémarrage d'Apache."
    exit 1
fi
success "Redémarrage d'Apache terminé."

# Afficher l'état des services
progress "Vérification de l'état des services..."
sudo systemctl status apache2
sudo systemctl status mysql
success "Vérification de l'état des services terminée."
