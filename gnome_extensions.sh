#!/bin/bash

# Script de sauvegarde et restauration des extensions GNOME
# Auteur: Fontaine Johnny
# Version: 1.0

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Répertoires
BACKUP_DIR="$HOME/Backups/gnome-extensions-backup"
EXTENSIONS_DIR="$HOME/.local/share/gnome-shell/extensions"
CONFIG_DIR="$HOME/.config"

# Fonction d'affichage avec couleurs
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction pour vérifier les prérequis
check_requirements() {
    print_info "Vérification des prérequis..."
    
    # Vérifier si GNOME Shell est en cours d'exécution
    if ! pgrep -x "gnome-shell" > /dev/null; then
        print_warning "GNOME Shell ne semble pas être en cours d'exécution"
    fi
    
    # Vérifier si dconf est installé
    if ! command -v dconf &> /dev/null; then
        print_error "dconf n'est pas installé. Veuillez l'installer avec: sudo apt install dconf-cli"
        exit 1
    fi
    
    # Vérifier si gsettings est disponible
    if ! command -v gsettings &> /dev/null; then
        print_error "gsettings n'est pas disponible"
        exit 1
    fi
    
    print_success "Prérequis vérifiés"
}

# Fonction de sauvegarde
backup_extensions() {
    print_info "Début de la sauvegarde des extensions GNOME..."
    
    # Créer le répertoire de sauvegarde
    mkdir -p "$BACKUP_DIR"
    
    # Date de la sauvegarde
    BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/gnome-extensions-$BACKUP_DATE.tar.gz"
    SETTINGS_FILE="$BACKUP_DIR/gnome-settings-$BACKUP_DATE.dconf"
    EXTENSIONS_LIST="$BACKUP_DIR/extensions-list-$BACKUP_DATE.txt"
    
    # Sauvegarder les extensions installées
    if [ -d "$EXTENSIONS_DIR" ]; then
        print_info "Sauvegarde des fichiers d'extensions..."
        tar -czf "$BACKUP_FILE" -C "$HOME/.local/share/gnome-shell" extensions/ 2>/dev/null
        if [ $? -eq 0 ]; then
            print_success "Extensions sauvegardées dans: $BACKUP_FILE"
        else
            print_warning "Aucune extension à sauvegarder ou erreur lors de l'archivage"
        fi
    else
        print_warning "Répertoire des extensions non trouvé: $EXTENSIONS_DIR"
    fi
    
    # Sauvegarder les paramètres des extensions
    print_info "Sauvegarde des paramètres des extensions..."
    dconf dump /org/gnome/shell/extensions/ > "$SETTINGS_FILE" 2>/dev/null
    if [ -s "$SETTINGS_FILE" ]; then
        print_success "Paramètres sauvegardés dans: $SETTINGS_FILE"
    else
        print_warning "Aucun paramètre d'extension à sauvegarder"
    fi
    
    # Créer une liste des extensions activées
    print_info "Sauvegarde de la liste des extensions activées..."
    gsettings get org.gnome.shell enabled-extensions > "$EXTENSIONS_LIST" 2>/dev/null
    if [ -s "$EXTENSIONS_LIST" ]; then
        print_success "Liste des extensions sauvegardée dans: $EXTENSIONS_LIST"
    else
        print_warning "Impossible de récupérer la liste des extensions activées"
    fi
    
    # Créer un fichier de métadonnées
    METADATA_FILE="$BACKUP_DIR/backup-metadata-$BACKUP_DATE.txt"
    {
        echo "=== SAUVEGARDE EXTENSIONS GNOME ==="
        echo "Date: $(date)"
        echo "Utilisateur: $USER"
        echo "Version GNOME: $(gnome-shell --version 2>/dev/null || echo 'Non disponible')"
        echo "Système: $(lsb_release -d 2>/dev/null | cut -f2 || uname -a)"
        echo ""
        echo "Fichiers créés:"
        echo "- Extensions: $(basename "$BACKUP_FILE")"
        echo "- Paramètres: $(basename "$SETTINGS_FILE")"
        echo "- Liste: $(basename "$EXTENSIONS_LIST")"
    } > "$METADATA_FILE"
    
    print_success "Sauvegarde terminée! Fichiers dans: $BACKUP_DIR"
    print_info "Métadonnées sauvegardées dans: $METADATA_FILE"
}

# Fonction de restauration
restore_extensions() {
    print_info "Restauration des extensions GNOME..."
    
    # Lister les sauvegardes disponibles
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR"/*.tar.gz 2>/dev/null)" ]; then
        print_error "Aucune sauvegarde trouvée dans $BACKUP_DIR"
        exit 1
    fi
    
    echo "Sauvegardes disponibles:"
    select backup_file in "$BACKUP_DIR"/*.tar.gz; do
        if [ -n "$backup_file" ]; then
            break
        else
            print_error "Sélection invalide"
        fi
    done
    
    # Extraire la date de la sauvegarde sélectionnée
    BACKUP_DATE=$(basename "$backup_file" | sed 's/gnome-extensions-\(.*\)\.tar\.gz/\1/')
    SETTINGS_FILE="$BACKUP_DIR/gnome-settings-$BACKUP_DATE.dconf"
    EXTENSIONS_LIST="$BACKUP_DIR/extensions-list-$BACKUP_DATE.txt"
    
    print_info "Restauration depuis: $(basename "$backup_file")"
    
    # Demander confirmation
    read -p "Voulez-vous continuer avec la restauration? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Restauration annulée"
        exit 0
    fi
    
    # Créer une sauvegarde de sécurité des extensions actuelles
    if [ -d "$EXTENSIONS_DIR" ]; then
        print_info "Création d'une sauvegarde de sécurité..."
        SAFETY_BACKUP="$BACKUP_DIR/safety-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$SAFETY_BACKUP" -C "$HOME/.local/share/gnome-shell" extensions/ 2>/dev/null
        print_success "Sauvegarde de sécurité créée: $SAFETY_BACKUP"
    fi
    
    # Restaurer les extensions
    print_info "Restauration des fichiers d'extensions..."
    mkdir -p "$HOME/.local/share/gnome-shell"
    tar -xzf "$backup_file" -C "$HOME/.local/share/gnome-shell" 2>/dev/null
    if [ $? -eq 0 ]; then
        print_success "Extensions restaurées"
    else
        print_error "Erreur lors de la restauration des extensions"
    fi
    
    # Restaurer les paramètres
    if [ -f "$SETTINGS_FILE" ] && [ -s "$SETTINGS_FILE" ]; then
        print_info "Restauration des paramètres..."
        dconf load /org/gnome/shell/extensions/ < "$SETTINGS_FILE"
        print_success "Paramètres restaurés"
    else
        print_warning "Fichier de paramètres non trouvé ou vide"
    fi
    
    # Restaurer la liste des extensions activées
    if [ -f "$EXTENSIONS_LIST" ] && [ -s "$EXTENSIONS_LIST" ]; then
        print_info "Restauration de la liste des extensions activées..."
        ENABLED_EXTENSIONS=$(cat "$EXTENSIONS_LIST")
        gsettings set org.gnome.shell enabled-extensions "$ENABLED_EXTENSIONS"
        print_success "Liste des extensions activées restaurée"
    else
        print_warning "Liste des extensions non trouvée"
    fi
    
    print_success "Restauration terminée!"
    print_warning "Vous devrez peut-être redémarrer GNOME Shell (Alt+F2, tapez 'r') ou vous déconnecter/reconnecter"
}

# Fonction pour lister les sauvegardes
list_backups() {
    print_info "Sauvegardes disponibles:"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_warning "Répertoire de sauvegarde non trouvé: $BACKUP_DIR"
        return
    fi
    
    for backup in "$BACKUP_DIR"/gnome-extensions-*.tar.gz; do
        if [ -f "$backup" ]; then
            filename=$(basename "$backup")
            date_part=$(echo "$filename" | sed 's/gnome-extensions-\(.*\)\.tar\.gz/\1/')
            readable_date=$(echo "$date_part" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\3\/\2\/\1 \4:\5:\6/')
            size=$(du -h "$backup" | cut -f1)
            echo "  - $filename (Taille: $size, Date: $readable_date)"
            
            # Vérifier les fichiers associés
            metadata_file="$BACKUP_DIR/backup-metadata-$date_part.txt"
            if [ -f "$metadata_file" ]; then
                echo "    └── Métadonnées disponibles"
            fi
        fi
    done
    
    if [ -z "$(ls -A "$BACKUP_DIR"/gnome-extensions-*.tar.gz 2>/dev/null)" ]; then
        print_warning "Aucune sauvegarde trouvée"
    fi
}

# Fonction pour nettoyer les anciennes sauvegardes
cleanup_backups() {
    print_info "Nettoyage des anciennes sauvegardes..."
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_warning "Répertoire de sauvegarde non trouvé"
        return
    fi
    
    read -p "Combien de sauvegardes souhaitez-vous conserver? (défaut: 5): " keep_count
    keep_count=${keep_count:-5}
    
    # Supprimer les anciennes sauvegardes (garder les plus récentes)
    ls -t "$BACKUP_DIR"/gnome-extensions-*.tar.gz 2>/dev/null | tail -n +$((keep_count + 1)) | while read -r old_backup; do
        if [ -f "$old_backup" ]; then
            date_part=$(basename "$old_backup" | sed 's/gnome-extensions-\(.*\)\.tar\.gz/\1/')
            print_info "Suppression de $(basename "$old_backup")"
            rm -f "$old_backup"
            rm -f "$BACKUP_DIR/gnome-settings-$date_part.dconf"
            rm -f "$BACKUP_DIR/extensions-list-$date_part.txt"
            rm -f "$BACKUP_DIR/backup-metadata-$date_part.txt"
        fi
    done
    
    print_success "Nettoyage terminé"
}

# Fonction d'aide
show_help() {
    echo "Script de sauvegarde et restauration des extensions GNOME"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  backup, -b     Sauvegarder les extensions"
    echo "  restore, -r    Restaurer les extensions"
    echo "  list, -l       Lister les sauvegardes disponibles"
    echo "  cleanup, -c    Nettoyer les anciennes sauvegardes"
    echo "  help, -h       Afficher cette aide"
    echo ""
    echo "Répertoire de sauvegarde: $BACKUP_DIR"
}

# Fonction pour afficher le menu principal
show_menu() {
    echo ""
    echo "=============================================="
    echo "  Script de gestion des extensions GNOME"
    echo "=============================================="
    echo ""
    echo "Choisissez une action:"
    echo "1) Sauvegarder les extensions"
    echo "2) Restaurer les extensions"
    echo "3) Lister les sauvegardes"
    echo "4) Nettoyer les anciennes sauvegardes"
    echo "5) Afficher l'aide"
    echo "6) Quitter"
    echo ""
}

# Fonction pour demander de continuer
ask_continue() {
    echo ""
    echo "=============================================="
    read -p "Appuyez sur Entrée pour revenir au menu principal..."
    echo ""
}

# Boucle principale interactive
interactive_menu() {
    while true; do
        show_menu
        read -p "Votre choix (1-6): " choice
        
        case $choice in
            1) 
                check_requirements && backup_extensions
                ask_continue
                ;;
            2) 
                check_requirements && restore_extensions
                ask_continue
                ;;
            3) 
                list_backups
                ask_continue
                ;;
            4) 
                cleanup_backups
                ask_continue
                ;;
            5) 
                show_help
                ask_continue
                ;;
            6) 
                print_info "Au revoir!"
                exit 0
                ;;
            *) 
                print_error "Choix invalide"
                sleep 1
                ;;
        esac
    done
}

# Programme principal
main() {
    case "${1:-}" in
        backup|-b)
            check_requirements
            backup_extensions
            ;;
        restore|-r)
            check_requirements
            restore_extensions
            ;;
        list|-l)
            list_backups
            ;;
        cleanup|-c)
            cleanup_backups
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            # Mode interactif par défaut
            interactive_menu
            ;;
    esac
}

main "$@"
