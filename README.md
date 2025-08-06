# Script de Sauvegarde et Restauration pour Ubuntu

Un script Bash pour sauvegarder et restaurer les applications et configurations sur un système Ubuntu.

## Fonctionnalités

- Sauvegarde et restauration des paquets DEB.
- Sauvegarde et restauration des applications Flatpak.
- Sauvegarde et restauration des extensions GNOME.
- Sauvegarde et restauration des comptes utilisateurs.
- Sauvegarde et restauration des configurations de Brave et Bottles.
- Gestion des sauvegardes existantes.

## Prérequis

- Un système Ubuntu.
- Les dépendances suivantes doivent être installées : `flatpak`, `rsync`, `dconf`, `gnome-extensions`.

## Installation

1. Clonez le dépôt sur votre machine locale :

   ```bash
   git clone https://github.com/tuxgyver/Backup_PC.git


Accédez au répertoire du projet :
 cd Backup_PC


Assurez-vous que le script est exécutable :
 chmod +x backup_pc.sh


## Utilisation


Exécutez le script :
 ./backup_pc.sh


Suivez les instructions du menu pour effectuer des sauvegardes, des restaurations, ou gérer les sauvegardes existantes.


### Exemples
Effectuer une sauvegarde complète

Sélectionnez l'option 1 dans le menu principal pour effectuer une sauvegarde complète.

* Restaurer à partir d'une sauvegarde

Sélectionnez l'option 2 dans le menu principal.
Suivez les instructions pour spécifier le chemin de la sauvegarde à restaurer.

* Vérifier les applications Flatpak

Sélectionnez l'option 3 dans le menu principal pour vérifier et installer les applications Flatpak manquantes.

## Contributions
Les contributions sont les bienvenues ! Pour contribuer, veuillez suivre ces étapes :

### Fork le projet.
* Créez une nouvelle branche (git checkout -b feature-branch).
* Commitez vos modifications (git commit -am 'Add new feature').
* Poussez la branche (git push origin feature-branch).
* Ouvrez une Pull Request.

## Licence
Ce projet est sous licence MIT.

## Contact
Pour toute question ou suggestion, veuillez ouvrir une issue ou contactez-moi à johnny@free.fr.
