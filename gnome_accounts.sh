#!/bin/bash

# Script de sauvegarde et restauration des comptes et partages réseau GNOME
# Auteur: Assistant Claude
# Version: 1.0

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Répertoires et fichiers
BACKUP_DIR="$HOME/Backups/gnome-accounts-network-backup"
GOA_CONFIG_DIR="$HOME/.config/goa-1.0"
EVOLUTION_CONFIG_DIR="$HOME/.config/evolution"
KEYRING_DIR="$HOME/.local/share/keyrings"
NETWORK_CONFIG_DIR="/etc/NetworkManager/system-connections"
USER_NETWORK_CONFIG_DIR="$HOME/.config/NetworkManager"

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

# Fonction pour installer les prérequis manquants
install_requirements() {
    print_info "Installation automatique des prérequis manquants..."
    
    local packages_to_install=()
    
    # Vérifier dconf
    if ! command -v dconf &> /dev/null; then
        print_info "dconf manquant - ajout à la liste d'installation"
        packages_to_install+=("dconf-cli")
    fi
    
    # Vérifier secret-tool
    if ! command -v secret-tool &> /dev/null; then
        print_info "secret-tool manquant - ajout à la liste d'installation"
        packages_to_install+=("libsecret-tools")
    fi
    
    # Vérifier seahorse (gestionnaire de trousseau graphique)
    if ! command -v seahorse &> /dev/null; then
        print_info "seahorse manquant - ajout à la liste d'installation"
        packages_to_install+=("seahorse")
    fi
    
    # Installer les paquets manquants
    if [ ${#packages_to_install[@]} -gt 0 ]; then
        print_info "Installation des paquets: ${packages_to_install[*]}"
        
        # Détecter le gestionnaire de paquets
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y "${packages_to_install[@]}"
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y "${packages_to_install[@]}"
        elif command -v yum &> /dev/null; then
            sudo yum install -y "${packages_to_install[@]}"
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm "${packages_to_install[@]}"
        elif command -v zypper &> /dev/null; then
            sudo zypper install -y "${packages_to_install[@]}"
        else
            print_error "Gestionnaire de paquets non supporté. Installez manuellement: ${packages_to_install[*]}"
            exit 1
        fi
        
        if [ $? -eq 0 ]; then
            print_success "Prérequis installés avec succès"
        else
            print_error "Erreur lors de l'installation des prérequis"
            exit 1
        fi
    else
        print_success "Tous les prérequis sont déjà installés"
    fi
}

# Fonction pour vérifier les prérequis
check_requirements() {
    print_info "Vérification des prérequis..."
    
    # Vérifier si GNOME est en cours d'exécution
    if ! pgrep -x "gnome-shell" > /dev/null; then
        print_warning "GNOME Shell ne semble pas être en cours d'exécution"
    fi
    
    # Installer automatiquement les prérequis manquants
    install_requirements
    
    print_success "Prérequis vérifiés et installés"
}

# Fonction de sauvegarde
backup_accounts_network() {
    print_info "Début de la sauvegarde des comptes et partages réseau GNOME..."
    
    # Créer le répertoire de sauvegarde
    mkdir -p "$BACKUP_DIR"
    
    # Date de la sauvegarde
    BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
    BACKUP_BASE="$BACKUP_DIR/gnome-accounts-network-$BACKUP_DATE"
    
    # Créer un répertoire pour cette sauvegarde
    mkdir -p "$BACKUP_BASE"
    
    # Sauvegarder GNOME Online Accounts (GOA)
    print_info "Sauvegarde des comptes en ligne (GNOME Online Accounts)..."
    if [ -d "$GOA_CONFIG_DIR" ]; then
        cp -r "$GOA_CONFIG_DIR" "$BACKUP_BASE/goa-1.0" 2>/dev/null
        if [ $? -eq 0 ]; then
            print_success "Comptes en ligne sauvegardés"
        else
            print_warning "Erreur lors de la sauvegarde des comptes en ligne"
        fi
    else
        print_warning "Répertoire GOA non trouvé: $GOA_CONFIG_DIR"
    fi
    
    # Sauvegarder Evolution (comptes mail)
    print_info "Sauvegarde des comptes Evolution (mail)..."
    if [ -d "$EVOLUTION_CONFIG_DIR" ]; then
        # Sauvegarder seulement les sources de données et la configuration
        mkdir -p "$BACKUP_BASE/evolution"
        if [ -d "$EVOLUTION_CONFIG_DIR/sources" ]; then
            cp -r "$EVOLUTION_CONFIG_DIR/sources" "$BACKUP_BASE/evolution/" 2>/dev/null
        fi
        if [ -f "$EVOLUTION_CONFIG_DIR/evolution.conf" ]; then
            cp "$EVOLUTION_CONFIG_DIR/evolution.conf" "$BACKUP_BASE/evolution/" 2>/dev/null
        fi
        # Copier les fichiers de configuration des comptes
        find "$EVOLUTION_CONFIG_DIR" -name "*.source" -o -name "*.conf" | while read -r file; do
            rel_path=$(realpath --relative-to="$EVOLUTION_CONFIG_DIR" "$file" 2>/dev/null || echo "$file")
            mkdir -p "$BACKUP_BASE/evolution/$(dirname "$rel_path")"
            cp "$file" "$BACKUP_BASE/evolution/$rel_path" 2>/dev/null
        done
        print_success "Configuration Evolution sauvegardée"
    else
        print_warning "Répertoire Evolution non trouvé: $EVOLUTION_CONFIG_DIR"
    fi
    
    # Sauvegarder les paramètres dconf liés aux comptes
    print_info "Sauvegarde des paramètres des comptes (dconf)..."
    DCONF_ACCOUNTS="$BACKUP_BASE/accounts-settings.dconf"
    {
        dconf dump /org/gnome/online-accounts/
        dconf dump /org/gnome/evolution-data-server/
        dconf dump /org/gnome/evolution/
        dconf dump /org/gnome/settings-daemon/plugins/sharing/
    } > "$DCONF_ACCOUNTS" 2>/dev/null
    
    if [ -s "$DCONF_ACCOUNTS" ]; then
        print_success "Paramètres des comptes sauvegardés"
    else
        print_warning "Aucun paramètre de compte à sauvegarder"
    fi
    
    # Sauvegarder les connexions réseau (avec sudo si nécessaire)
    print_info "Sauvegarde des connexions réseau..."
    NETWORK_BACKUP="$BACKUP_BASE/network-connections"
    mkdir -p "$NETWORK_BACKUP"
    
    # Connexions système (nécessite sudo)
    if [ -d "$NETWORK_CONFIG_DIR" ] && sudo -n true 2>/dev/null; then
        print_info "Sauvegarde des connexions système (avec sudo)..."
        sudo cp -r "$NETWORK_CONFIG_DIR"/* "$NETWORK_BACKUP/" 2>/dev/null
        if [ $? -eq 0 ]; then
            sudo chown -R "$USER:$USER" "$NETWORK_BACKUP"
            print_success "Connexions système sauvegardées"
        fi
    else
        print_warning "Impossible de sauvegarder les connexions système (sudo requis ou non disponible)"
    fi
    
    # Connexions utilisateur
    if [ -d "$USER_NETWORK_CONFIG_DIR" ]; then
        cp -r "$USER_NETWORK_CONFIG_DIR" "$BACKUP_BASE/user-network-config" 2>/dev/null
        print_success "Configuration réseau utilisateur sauvegardée"
    fi
    
    # Sauvegarder les partages réseau (dconf)
    print_info "Sauvegarde des paramètres de partage réseau..."
    DCONF_SHARING="$BACKUP_BASE/sharing-settings.dconf"
    {
        dconf dump /org/gnome/settings-daemon/plugins/sharing/
        dconf dump /org/gnome/desktop/file-sharing/
        dconf dump /org/gtk/settings/file-chooser/
    } > "$DCONF_SHARING" 2>/dev/null
    
    if [ -s "$DCONF_SHARING" ]; then
        print_success "Paramètres de partage sauvegardés"
    else
        print_warning "Aucun paramètre de partage à sauvegarder"
    fi
    
    # Sauvegarder la liste des signets de fichiers (lieux réseau)
    print_info "Sauvegarde des signets de fichiers..."
    BOOKMARKS_FILE="$HOME/.config/gtk-3.0/bookmarks"
    if [ -f "$BOOKMARKS_FILE" ]; then
        cp "$BOOKMARKS_FILE" "$BACKUP_BASE/gtk-bookmarks" 2>/dev/null
        print_success "Signets de fichiers sauvegardés"
    else
        print_warning "Fichier de signets non trouvé"
    fi
    
    # Sauvegarder le trousseau de clés COMPLET (ATTENTION: SENSIBLE!)
    print_warning "ATTENTION: Sauvegarde des mots de passe du trousseau de clés..."
    print_warning "Cette opération sauvegarde les mots de passe en texte quasi-lisible!"
    print_warning "Protégez absolument ces fichiers de sauvegarde!"
    
    KEYRING_BACKUP="$BACKUP_BASE/keyring-passwords"
    mkdir -p "$KEYRING_BACKUP"
    
    # Sauvegarder les trousseaux de clés physiques
    if [ -d "$KEYRING_DIR" ]; then
        print_info "Sauvegarde des fichiers de trousseau de clés..."
        cp -r "$KEYRING_DIR" "$BACKUP_BASE/keyring-files" 2>/dev/null
        if [ $? -eq 0 ]; then
            print_success "Fichiers de trousseau copiés"
        else
            print_warning "Erreur lors de la copie des fichiers de trousseau"
        fi
    fi
    
    # Exporter les secrets avec secret-tool (si disponible)
    if command -v secret-tool &> /dev/null; then
        print_info "Export des mots de passe avec secret-tool..."
        
        # Créer un script d'export des secrets
        SECRETS_EXPORT="$KEYRING_BACKUP/secrets-export.txt"
        SECRETS_RESTORE="$KEYRING_BACKUP/restore-secrets.sh"
        
        {
            echo "=== SECRETS EXPORTÉS (ATTENTION: SENSIBLE!) ==="
            echo "Date: $(date)"
            echo "Utilisateur: $USER"
            echo ""
        } > "$SECRETS_EXPORT"
        
        {
            echo "#!/bin/bash"
            echo "# Script de restauration des secrets"
            echo "# ATTENTION: Ce fichier contient des mots de passe!"
            echo ""
        } > "$SECRETS_RESTORE"
        chmod +x "$SECRETS_RESTORE"
        
        # Sauvegarder tous les WiFi avec leurs mots de passe
        print_info "Sauvegarde des mots de passe WiFi..."
        WIFI_PASSWORDS="$KEYRING_BACKUP/wifi-passwords.txt"
        {
            echo "=== MOTS DE PASSE WIFI ==="
            echo "Date: $(date)"
            echo ""
        } > "$WIFI_PASSWORDS"
        
        # Lister toutes les connexions WiFi et extraire les mots de passe
        if command -v nmcli &> /dev/null; then
            nmcli -g NAME,TYPE connection show | grep ":802-11-wireless" | cut -d: -f1 | while read -r wifi_name; do
                if [ -n "$wifi_name" ]; then
                    password=$(nmcli -g 802-11-wireless-security.psk connection show "$wifi_name" 2>/dev/null)
                    if [ -n "$password" ] && [ "$password" != "--" ]; then
                        echo "WiFi: $wifi_name" >> "$WIFI_PASSWORDS"
                        echo "Mot de passe: $password" >> "$WIFI_PASSWORDS"
                        echo "" >> "$WIFI_PASSWORDS"
                        
                        # Ajouter au script de restauration
                        echo "# Restauration WiFi: $wifi_name" >> "$SECRETS_RESTORE"
                        echo "nmcli connection modify \"$wifi_name\" 802-11-wireless-security.psk \"$password\" 2>/dev/null || true" >> "$SECRETS_RESTORE"
                    fi
                fi
            done
        fi
        
        # Exporter les comptes en ligne avec tentative de récupération des tokens
        print_info "Tentative d'export des tokens des comptes en ligne..."
        GOA_SECRETS="$KEYRING_BACKUP/goa-secrets.txt"
        {
            echo "=== SECRETS DES COMPTES EN LIGNE ==="
            echo "Date: $(date)"
            echo ""
        } > "$GOA_SECRETS"
        
        if [ -d "$GOA_CONFIG_DIR" ]; then
            find "$GOA_CONFIG_DIR" -name "*.conf" | while read -r account_file; do
                if [ -f "$account_file" ]; then
                    provider=$(grep "Provider=" "$account_file" 2>/dev/null | cut -d'=' -f2)
                    identity=$(grep "Identity=" "$account_file" 2>/dev/null | cut -d'=' -f2)
                    account_id=$(basename "$account_file" .conf)
                    
                    if [ -n "$provider" ] && [ -n "$identity" ]; then
                        echo "Compte: $provider - $identity" >> "$GOA_SECRETS"
                        echo "ID: $account_id" >> "$GOA_SECRETS"
                        
                        # Chercher les secrets associés
                        secret-tool search goa-identity "$identity" 2>/dev/null | while read -r line; do
                            if [[ "$line" == "secret = "* ]]; then
                                secret_value=$(echo "$line" | sed 's/^secret = //')
                                echo "Secret: $secret_value" >> "$GOA_SECRETS"
                            fi
                        done || true
                        echo "" >> "$GOA_SECRETS"
                    fi
                fi
            done
        fi
        
        if [ -s "$SECRETS_EXPORT" ] || [ -s "$WIFI_PASSWORDS" ] || [ -s "$GOA_SECRETS" ]; then
            print_success "Mots de passe sauvegardés"
            print_warning "FICHIERS SENSIBLES créés dans $KEYRING_BACKUP"
        else
            print_warning "Aucun mot de passe récupéré automatiquement"
        fi
    fi
    
    # Créer une archive compressée
    print_info "Création de l'archive compressée..."
    ARCHIVE_FILE="$BACKUP_DIR/gnome-accounts-network-$BACKUP_DATE.tar.gz"
    tar -czf "$ARCHIVE_FILE" -C "$BACKUP_DIR" "gnome-accounts-network-$BACKUP_DATE" 2>/dev/null
    if [ $? -eq 0 ]; then
        rm -rf "$BACKUP_BASE"  # Supprimer le répertoire temporaire
        print_success "Archive créée: $ARCHIVE_FILE"
    else
        print_error "Erreur lors de la création de l'archive"
    fi
    
    # Créer un fichier de métadonnées
    METADATA_FILE="$BACKUP_DIR/backup-metadata-$BACKUP_DATE.txt"
    {
        echo "=== SAUVEGARDE COMPTES ET RÉSEAU GNOME ==="
        echo "Date: $(date)"
        echo "Utilisateur: $USER"
        echo "Version GNOME: $(gnome-shell --version 2>/dev/null || echo 'Non disponible')"
        echo "Système: $(lsb_release -d 2>/dev/null | cut -f2 || uname -a)"
        echo "NetworkManager: $(nmcli --version 2>/dev/null | head -n1 || echo 'Non disponible')"
        echo ""
        echo "Éléments sauvegardés:"
        echo "- Comptes en ligne GNOME (GOA)"
        echo "- Configuration Evolution (mail)"
        echo "- Paramètres des comptes"
        echo "- Connexions réseau"
        echo "- Paramètres de partage"
        echo "- Signets de fichiers"
        echo "- MOTS DE PASSE (trousseau de clés)"
        echo "- Mots de passe WiFi"
        echo ""
        echo "⚠️  ATTENTION: Fichiers de mots de passe inclus!"
        echo "⚠️  Protégez absolument cette sauvegarde!"
        echo "Archive: $(basename "$ARCHIVE_FILE")"
    } > "$METADATA_FILE"
    
    print_success "Sauvegarde terminée! Fichiers dans: $BACKUP_DIR"
    print_info "Métadonnées sauvegardées dans: $METADATA_FILE"
}

# Fonction de restauration
restore_accounts_network() {
    print_info "Restauration des comptes et partages réseau GNOME..."
    
    # Lister les sauvegardes disponibles
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR"/*.tar.gz 2>/dev/null)" ]; then
        print_error "Aucune sauvegarde trouvée dans $BACKUP_DIR"
        return
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
    BACKUP_DATE=$(basename "$backup_file" | sed 's/gnome-accounts-network-\(.*\)\.tar\.gz/\1/')
    
    print_info "Restauration depuis: $(basename "$backup_file")"
    
    # Demander confirmation
    echo ""
    print_warning "ATTENTION: Cette opération va :"
    print_warning "- Remplacer vos comptes et paramètres actuels"
    print_warning "- Restaurer les mots de passe sauvegardés"
    print_warning "- Il est recommandé de fermer Evolution et autres applications"
    echo ""
    read -p "Voulez-vous continuer avec la restauration? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Restauration annulée"
        return
    fi
    
    # Créer un répertoire temporaire pour l'extraction
    TEMP_DIR=$(mktemp -d)
    print_info "Extraction de l'archive..."
    tar -xzf "$backup_file" -C "$TEMP_DIR" 2>/dev/null
    if [ $? -ne 0 ]; then
        print_error "Erreur lors de l'extraction de l'archive"
        rm -rf "$TEMP_DIR"
        return
    fi
    
    RESTORE_DIR="$TEMP_DIR/gnome-accounts-network-$BACKUP_DATE"
    
    # Créer une sauvegarde de sécurité
    print_info "Création d'une sauvegarde de sécurité..."
    SAFETY_DATE=$(date +"%Y%m%d_%H%M%S")
    SAFETY_BACKUP="$BACKUP_DIR/safety-backup-$SAFETY_DATE"
    mkdir -p "$SAFETY_BACKUP"
    
    [ -d "$GOA_CONFIG_DIR" ] && cp -r "$GOA_CONFIG_DIR" "$SAFETY_BACKUP/goa-1.0-backup" 2>/dev/null
    [ -d "$EVOLUTION_CONFIG_DIR" ] && cp -r "$EVOLUTION_CONFIG_DIR" "$SAFETY_BACKUP/evolution-backup" 2>/dev/null
    print_success "Sauvegarde de sécurité créée: $SAFETY_BACKUP"
    
    # Restaurer GNOME Online Accounts
    if [ -d "$RESTORE_DIR/goa-1.0" ]; then
        print_info "Restauration des comptes en ligne..."
        mkdir -p "$HOME/.config"
        rm -rf "$GOA_CONFIG_DIR" 2>/dev/null
        cp -r "$RESTORE_DIR/goa-1.0" "$GOA_CONFIG_DIR" 2>/dev/null
        print_success "Comptes en ligne restaurés"
    fi
    
    # Restaurer Evolution
    if [ -d "$RESTORE_DIR/evolution" ]; then
        print_info "Restauration de la configuration Evolution..."
        mkdir -p "$EVOLUTION_CONFIG_DIR"
        cp -r "$RESTORE_DIR/evolution"/* "$EVOLUTION_CONFIG_DIR/" 2>/dev/null
        print_success "Configuration Evolution restaurée"
    fi
    
    # Restaurer les paramètres des comptes
    if [ -f "$RESTORE_DIR/accounts-settings.dconf" ] && [ -s "$RESTORE_DIR/accounts-settings.dconf" ]; then
        print_info "Restauration des paramètres des comptes..."
        dconf load / < "$RESTORE_DIR/accounts-settings.dconf" 2>/dev/null
        print_success "Paramètres des comptes restaurés"
    fi
    
    # Restaurer les connexions réseau
    if [ -d "$RESTORE_DIR/network-connections" ]; then
        print_info "Restauration des connexions réseau..."
        if sudo -n true 2>/dev/null; then
            sudo cp -r "$RESTORE_DIR/network-connections"/* "$NETWORK_CONFIG_DIR/" 2>/dev/null
            sudo systemctl reload NetworkManager 2>/dev/null
            print_success "Connexions réseau restaurées"
        else
            print_warning "Sudo requis pour restaurer les connexions système - ignoré"
        fi
    fi
    
    # Restaurer la configuration réseau utilisateur
    if [ -d "$RESTORE_DIR/user-network-config" ]; then
        print_info "Restauration de la configuration réseau utilisateur..."
        mkdir -p "$HOME/.config"
        cp -r "$RESTORE_DIR/user-network-config" "$USER_NETWORK_CONFIG_DIR" 2>/dev/null
        print_success "Configuration réseau utilisateur restaurée"
    fi
    
    # Restaurer les paramètres de partage
    if [ -f "$RESTORE_DIR/sharing-settings.dconf" ] && [ -s "$RESTORE_DIR/sharing-settings.dconf" ]; then
        print_info "Restauration des paramètres de partage..."
        dconf load / < "$RESTORE_DIR/sharing-settings.dconf" 2>/dev/null
        print_success "Paramètres de partage restaurés"
    fi
    
    # Restaurer les trousseaux de clés et mots de passe
    if [ -d "$RESTORE_DIR/keyring-files" ]; then
        print_warning "ATTENTION: Restauration des trousseaux de clés avec mots de passe!"
        read -p "Restaurer les mots de passe sauvegardés? (y/N): " restore_passwords
        if [[ "$restore_passwords" =~ ^[Yy]$ ]]; then
            print_info "Restauration des fichiers de trousseau..."
            
            # Sauvegarder les trousseaux actuels
            [ -d "$KEYRING_DIR" ] && cp -r "$KEYRING_DIR" "$SAFETY_BACKUP/keyring-backup" 2>/dev/null
            
            # Restaurer les trousseaux
            mkdir -p "$HOME/.local/share"
            rm -rf "$KEYRING_DIR" 2>/dev/null
            cp -r "$RESTORE_DIR/keyring-files/keyrings" "$KEYRING_DIR" 2>/dev/null
            
            print_success "Trousseaux de clés restaurés"
            
            # Restaurer les mots de passe WiFi
            if [ -f "$RESTORE_DIR/keyring-passwords/restore-secrets.sh" ]; then
                print_info "Exécution du script de restauration des secrets..."
                bash "$RESTORE_DIR/keyring-passwords/restore-secrets.sh" 2>/dev/null
                print_success "Script de restauration exécuté"
            fi
            
            # Redémarrer le démon gnome-keyring si possible
            if pgrep -x "gnome-keyring-daemon" > /dev/null; then
                print_info "Redémarrage du démon gnome-keyring..."
                pkill -f gnome-keyring-daemon 2>/dev/null
                sleep 2
                gnome-keyring-daemon --start --components=secrets,ssh,gpg 2>/dev/null &
                print_success "Démon gnome-keyring redémarré"
            fi
        else
            print_info "Restauration des mots de passe ignorée"
        fi
    fi

    # Restaurer les signets
    if [ -f "$RESTORE_DIR/gtk-bookmarks" ]; then
        print_info "Restauration des signets de fichiers..."
        mkdir -p "$HOME/.config/gtk-3.0"
        cp "$RESTORE_DIR/gtk-bookmarks" "$HOME/.config/gtk-3.0/bookmarks" 2>/dev/null
        print_success "Signets de fichiers restaurés"
    fi
    
    # Nettoyer
    rm -rf "$TEMP_DIR"
    
    print_success "Restauration terminée!"
    print_warning "Actions recommandées :"
    print_warning "1. Redémarrez votre session complètement (déconnexion/reconnexion)"
    print_warning "2. Vérifiez vos comptes dans Paramètres > Comptes en ligne"
    print_warning "3. Testez vos connexions WiFi"
    print_warning "4. Relancez Evolution si vous l'utilisez"
    print_warning "5. Si les mots de passe ne fonctionnent pas, vérifiez les fichiers dans keyring-passwords/"
}

# Fonction pour lister les sauvegardes
list_backups() {
    print_info "Sauvegardes disponibles:"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_warning "Répertoire de sauvegarde non trouvé: $BACKUP_DIR"
        return
    fi
    
    for backup in "$BACKUP_DIR"/gnome-accounts-network-*.tar.gz; do
        if [ -f "$backup" ]; then
            filename=$(basename "$backup")
            date_part=$(echo "$filename" | sed 's/gnome-accounts-network-\(.*\)\.tar\.gz/\1/')
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
    
    if [ -z "$(ls -A "$BACKUP_DIR"/gnome-accounts-network-*.tar.gz 2>/dev/null)" ]; then
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
    
    read -p "Combien de sauvegardes souhaitez-vous conserver? (défaut: 3): " keep_count
    keep_count=${keep_count:-3}
    
    # Supprimer les anciennes sauvegardes (garder les plus récentes)
    ls -t "$BACKUP_DIR"/gnome-accounts-network-*.tar.gz 2>/dev/null | tail -n +$((keep_count + 1)) | while read -r old_backup; do
        if [ -f "$old_backup" ]; then
            date_part=$(basename "$old_backup" | sed 's/gnome-accounts-network-\(.*\)\.tar\.gz/\1/')
            print_info "Suppression de $(basename "$old_backup")"
            rm -f "$old_backup"
            rm -f "$BACKUP_DIR/backup-metadata-$date_part.txt"
            rm -rf "$BACKUP_DIR/safety-backup-"* 2>/dev/null
        fi
    done
    
    print_success "Nettoyage terminé"
}

# Fonction pour afficher les informations sur les comptes actuels
show_accounts_info() {
    print_info "Informations sur les comptes et connexions actuels:"
    echo ""
    
    # Comptes en ligne GNOME
    if [ -d "$GOA_CONFIG_DIR" ]; then
        echo "📧 Comptes en ligne GNOME:"
        find "$GOA_CONFIG_DIR" -name "*.conf" | while read -r account_file; do
            if [ -f "$account_file" ]; then
                provider=$(grep "Provider=" "$account_file" 2>/dev/null | cut -d'=' -f2)
                identity=$(grep "Identity=" "$account_file" 2>/dev/null | cut -d'=' -f2)
                [ -n "$provider" ] && echo "  - $provider: $identity"
            fi
        done
        echo ""
    fi
    
    # Connexions réseau
    if command -v nmcli &> /dev/null; then
        echo "🌐 Connexions réseau configurées:"
        nmcli connection show 2>/dev/null | tail -n +2 | while read -r line; do
            name=$(echo "$line" | awk '{print $1}')
            type=$(echo "$line" | awk '{print $3}')
            [ -n "$name" ] && echo "  - $name ($type)"
        done
        echo ""
    fi
    
    # Signets de fichiers
    if [ -f "$HOME/.config/gtk-3.0/bookmarks" ]; then
        echo "📁 Signets de fichiers/réseau:"
        grep -E "(smb://|ftp://|sftp://)" "$HOME/.config/gtk-3.0/bookmarks" 2>/dev/null | while read -r bookmark; do
            url=$(echo "$bookmark" | awk '{print $1}')
            name=$(echo "$bookmark" | cut -d' ' -f2-)
            [ -n "$url" ] && echo "  - $name ($url)"
        done
        echo ""
    fi
}

# Fonction d'aide
show_help() {
    echo "Script de sauvegarde et restauration des comptes et partages réseau GNOME"
    echo ""
    echo "Ce script sauvegarde et restaure :"
    echo "  • Comptes en ligne GNOME (Google, Microsoft, Nextcloud, etc.)"
    echo "  • Configuration Evolution (comptes mail)"
    echo "  • Connexions réseau WiFi/Ethernet"
    echo "  • Paramètres de partage réseau"
    echo "  • Signets de fichiers réseau"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  backup, -b     Sauvegarder les comptes et réseau"
    echo "  restore, -r    Restaurer les comptes et réseau"
    echo "  list, -l       Lister les sauvegardes disponibles"
    echo "  cleanup, -c    Nettoyer les anciennes sauvegardes"
    echo "  info, -i       Afficher les comptes/connexions actuels"
    echo "  help, -h       Afficher cette aide"
    echo ""
    echo "IMPORTANT:"
    echo "  ⚠️  Les mots de passe SONT sauvegardés (non sécurisé)"
    echo "  ⚠️  Protégez absolument vos fichiers de sauvegarde"
    echo "  ⚠️  Ne partagez jamais ces sauvegardes"
    echo "  • Sudo peut être requis pour les connexions système"
    echo ""
    echo "Répertoire de sauvegarde: $BACKUP_DIR"
}

# Fonction pour afficher le menu principal
show_menu() {
    echo ""
    echo "=================================================="
    echo "  Script de gestion des comptes et réseau GNOME"
    echo "=================================================="
    echo ""
    echo "Choisissez une action:"
    echo "1) Sauvegarder les comptes et réseau"
    echo "2) Restaurer les comptes et réseau"
    echo "3) Lister les sauvegardes"
    echo "4) Nettoyer les anciennes sauvegardes"
    echo "5) Afficher les comptes/connexions actuels"
    echo "6) Afficher l'aide"
    echo "7) Quitter"
    echo ""
}

# Fonction pour demander de continuer
ask_continue() {
    echo ""
    echo "=================================================="
    read -p "Appuyez sur Entrée pour revenir au menu principal..."
    echo ""
}

# Boucle principale interactive
interactive_menu() {
    while true; do
        show_menu
        read -p "Votre choix (1-7): " choice
        
        case $choice in
            1) 
                check_requirements && backup_accounts_network
                ask_continue
                ;;
            2) 
                check_requirements && restore_accounts_network
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
                show_accounts_info
                ask_continue
                ;;
            6) 
                show_help
                ask_continue
                ;;
            7) 
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
            backup_accounts_network
            ;;
        restore|-r)
            check_requirements
            restore_accounts_network
            ;;
        list|-l)
            list_backups
            ;;
        cleanup|-c)
            cleanup_backups
            ;;
        info|-i)
            show_accounts_info
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
