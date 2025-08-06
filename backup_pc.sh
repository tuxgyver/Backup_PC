#!/bin/bash

# Script complet de sauvegarde/restauration pour AnduinOS 1.3.3
# Version: 3.1

set -euo pipefail

# Configuration
DEFAULT_BACKUP_BASE_DIR="$HOME/Backups/System"
BACKUP_DIR="$DEFAULT_BACKUP_BASE_DIR/backup_$(date +%Y%m%d_%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonctions d'affichage
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

# Applications Flatpak
declare -A FLATPAK_APPS=(
    ["Arduino IDE 2"]="cc.arduino.IDE2"
    ["AnyDesk"]="com.anydesk.Anydesk"
    ["Bitwarden"]="com.bitwarden.desktop"
    ["Brave Browser"]="com.brave.Browser"
    ["Dropbox"]="com.dropbox.Client"
    ["Flatseal"]="com.github.tchx84.Flatseal"
    ["Android Studio"]="com.google.AndroidStudio"
    ["FinalShell"]="com.hostbuf.FinalShell"
    ["Alpaca"]="com.jeffser.Alpaca"
    ["PyCharm Community"]="com.jetbrains.PyCharm-Community"
    ["Extension Manager"]="com.mattjakeman.ExtensionManager"
    ["OBS Studio"]="com.obsproject.Studio"
    ["Proton VPN"]="com.protonvpn.www"
    ["ZapZap"]="com.rtosta.zapzap"
    ["Bottles"]="com.usebottles.bottles"
    ["ZetaOffice"]="de.allotropia.ZetaOffice"
    ["Shortwave"]="de.haeckerfelix.Shortwave"
    ["GPU Viewer"]="io.github.arunsivaramanneo.GPUViewer"
    ["Cohesion"]="io.github.brunofin.Cohesion"
    ["Flatsweep"]="io.github.giantpinkrobots.flatsweep"
    ["Follamac"]="io.github.pejuko.follamac"
    ["Newelle"]="io.gitlab.adhami3310.Impression"
    ["Proton Mail"]="me.proton.Mail"
    ["Proton Pass"]="me.proton.Pass"
    ["Remote Desktop Manager"]="net.devolutions.RDM"
    ["OpenTodoList"]="net.rpdev.OpenTodoList"
    ["Angry IP Scanner"]="org.angryip.ipscan"
    ["Fritzing"]="org.fritzing.Fritzing"
    ["Boxes"]="org.gnome.Boxes"
    ["Firmware"]="org.gnome.Firmware"
    ["Thunderbird"]="org.mozilla.Thunderbird"
    ["OnlyOffice"]="org.onlyoffice.desktopeditors"
    ["Zoom"]="us.zoom.Zoom"
)

### FONCTIONS DE BASE ###
check_dependencies() {
    local missing=0
    local required=("flatpak" "rsync" "du" "dconf" "gnome-extensions")

    for cmd in "${required[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            print_error "Dépendance manquante: $cmd"
            ((missing++))
        fi
    done

    if [ $missing -gt 0 ]; then
        print_warning "Installez les dépendances manquantes avec:"
        print_info "sudo apt install flatpak rsync dconf-cli gnome-shell-utils"
        return 1
    fi
    return 0
}

### FONCTIONS DE SAUVEGARDE ###
backup_deb_packages() {
    print_info "Sauvegarde des paquets DEB..."
    mkdir -p "$BACKUP_DIR/deb"

    dpkg --get-selections > "$BACKUP_DIR/deb/packages_list.txt"
    dpkg -l > "$BACKUP_DIR/deb/packages_detailed.txt"
    sudo cp -r /etc/apt/sources.list* "$BACKUP_DIR/deb/" 2>/dev/null || true
    sudo cp -r /etc/apt/trusted.gpg* "$BACKUP_DIR/deb/" 2>/dev/null || true
    apt-key exportall > "$BACKUP_DIR/deb/apt_keys.gpg" 2>/dev/null || true

    print_success "Paquets DEB sauvegardés"
}

backup_flatpak() {
    print_info "Sauvegarde des applications Flatpak..."
    mkdir -p "$BACKUP_DIR/flatpak"

    flatpak list --app --columns=application,version,branch,origin > "$BACKUP_DIR/flatpak/apps_list.txt"
    flatpak remotes --columns=name,url,subset > "$BACKUP_DIR/flatpak/remotes.txt"

    print_success "Applications Flatpak sauvegardées"
}

backup_gnome_extensions() {
    print_info "Sauvegarde des extensions GNOME..."

    # Vérifier si l'utilisateur est dans un environnement GNOME
    if ! pgrep -x "gnome-shell" > /dev/null; then
        print_warning "GNOME Shell n'est pas en cours d'exécution. Les extensions GNOME ne seront pas sauvegardées."
        return 1
    fi

    mkdir -p "$BACKUP_DIR/gnome"

    # Essayer de sauvegarder les extensions GNOME
    if ! gnome-extensions list > "$BACKUP_DIR/gnome/extensions_list.txt" 2>/dev/null; then
        print_error "Erreur lors de la connexion à Shell de GNOME"
        return 1
    fi

    # Sauvegarder la configuration dconf
    if ! dconf dump /org/gnome/shell/extensions/ > "$BACKUP_DIR/gnome/extensions_config.dconf" 2>/dev/null; then
        print_error "Erreur lors de la sauvegarde de la configuration des extensions GNOME"
    fi

    if ! dconf dump /org/gnome/ > "$BACKUP_DIR/gnome/gnome_settings.dconf" 2>/dev/null; then
        print_error "Erreur lors de la sauvegarde des paramètres GNOME"
    fi

    # Sauvegarder les fichiers des extensions
    if [ -d "$HOME/.local/share/gnome-shell/extensions" ]; then
        if ! cp -r "$HOME/.local/share/gnome-shell/extensions" "$BACKUP_DIR/gnome/"; then
            print_error "Erreur lors de la copie des fichiers des extensions GNOME"
        fi
    else
        print_warning "Le répertoire des extensions GNOME n'existe pas : $HOME/.local/share/gnome-shell/extensions"
    fi

    print_success "Extensions GNOME sauvegardées"
}

backup_accounts() {
    print_info "Sauvegarde des comptes..."
    mkdir -p "$BACKUP_DIR/accounts"

    [ -d "$HOME/.config/goa-1.0" ] && cp -r "$HOME/.config/goa-1.0" "$BACKUP_DIR/accounts/"
    [ -d "$HOME/.thunderbird" ] && cp -r "$HOME/.thunderbird" "$BACKUP_DIR/accounts/"

    print_success "Comptes sauvegardés"
}

backup_brave() {
    print_info "Sauvegarde de Brave..."
    mkdir -p "$BACKUP_DIR/brave"

    local brave_dir="$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser"
    if [ -d "$brave_dir" ]; then
        rsync -a --exclude={"Cache","Code Cache"} "$brave_dir/" "$BACKUP_DIR/brave/flatpak/"
        echo "flatpak" > "$BACKUP_DIR/brave/install_type.txt"
        print_success "Brave (Flatpak) sauvegardé"
    else
        print_warning "Brave Flatpak non trouvé"
    fi
}

backup_bottles() {
    print_info "Sauvegarde de Bottles..."
    mkdir -p "$BACKUP_DIR/bottles"

    local bottles_data="$HOME/.var/app/com.usebottles.bottles/data/bottles"
    local bottles_config="$HOME/.var/app/com.usebottles.bottles/config"

    if [ -d "$bottles_data" ]; then
        rsync -a "$bottles_data/" "$BACKUP_DIR/bottles/flatpak_data/"
        rsync -a "$bottles_config/" "$BACKUP_DIR/bottles/flatpak_config/"
        echo "flatpak" > "$BACKUP_DIR/bottles/install_type.txt"
        print_success "Bottles (Flatpak) sauvegardé"
    else
        print_warning "Bottles Flatpak non trouvé"
    fi
}

full_backup() {
    mkdir -p "$BACKUP_DIR"

    print_info "Début de la sauvegarde complète..."

    backup_deb_packages
    backup_flatpak
    backup_gnome_extensions
    backup_accounts
    backup_brave
    backup_bottles

    cat > "$BACKUP_DIR/backup_info.txt" <<EOF
Sauvegarde créée le: $(date)
Système: $(lsb_release -d | cut -f2)
Utilisateur: $USER
EOF

    print_success "Sauvegarde complète terminée dans: $BACKUP_DIR"
}

### FONCTIONS DE RESTAURATION ###
restore_deb_packages() {
    local backup_path="$1/deb"
    [ -d "$backup_path" ] || { print_error "Sauvegarde DEB introuvable"; return 1; }

    print_info "Restauration des paquets DEB..."

    sudo cp "$backup_path/sources.list" /etc/apt/ 2>/dev/null || true
    sudo cp -r "$backup_path/sources.list.d" /etc/apt/ 2>/dev/null || true

    [ -f "$backup_path/apt_keys.gpg" ] && sudo apt-key add "$backup_path/apt_keys.gpg" 2>/dev/null || true

    if [ -f "$backup_path/packages_list.txt" ]; then
        sudo apt update
        sudo apt install -y $(awk '/install/ {print $1}' "$backup_path/packages_list.txt")
    fi

    print_success "Paquets DEB restaurés"
}

restore_flatpak() {
    local backup_path="$1/flatpak"
    [ -d "$backup_path" ] || { print_error "Sauvegarde Flatpak introuvable"; return 1; }

    print_info "Restauration des Flatpaks..."

    while IFS=$'\t' read -r name url subset; do
        [ "$name" != "Name" ] && flatpak remote-add --if-not-exists "$name" "$url"
    done < "$backup_path/remotes.txt"

    while IFS=$'\t' read -r app version branch origin; do
        [ "$app" != "Application ID" ] && flatpak install -y "$origin" "$app"
    done < "$backup_path/apps_list.txt"

    print_success "Flatpaks restaurés"
}

restore_gnome_extensions() {
    local backup_path="$1/gnome"
    [ -d "$backup_path" ] || { print_error "Sauvegarde GNOME introuvable"; return 1; }

    print_info "Restauration des extensions GNOME..."

    if [ -d "$backup_path/extensions" ]; then
        mkdir -p "$HOME/.local/share/gnome-shell/"
        cp -r "$backup_path/extensions" "$HOME/.local/share/gnome-shell/"
    fi

    if [ -f "$backup_path/extensions_config.dconf" ]; then
        dconf load /org/gnome/shell/extensions/ < "$backup_path/extensions_config.dconf"
    fi

    if [ -f "$backup_path/gnome_settings.dconf" ]; then
        dconf load /org/gnome/ < "$backup_path/gnome_settings.dconf"
    fi

    if [ -f "$backup_path/extensions_list.txt" ]; then
        while read -r ext_id; do
            gnome-extensions enable "$ext_id" || true
        done < "$backup_path/extensions_list.txt"
    fi

    print_success "Extensions GNOME restaurées - Redémarrez GNOME pour terminer"
}

restore_accounts() {
    local backup_path="$1/accounts"
    [ -d "$backup_path" ] || { print_error "Sauvegarde comptes introuvable"; return 1; }

    print_info "Restauration des comptes..."

    [ -d "$backup_path/goa-1.0" ] && cp -r "$backup_path/goa-1.0" "$HOME/.config/"
    [ -d "$backup_path/.thunderbird" ] && cp -r "$backup_path/.thunderbird" "$HOME/"

    print_success "Comptes restaurés"
}

restore_brave() {
    local backup_path="$1/brave"
    [ -d "$backup_path" ] || { print_error "Sauvegarde Brave introuvable"; return 1; }

    print_info "Restauration de Brave..."

    if ! flatpak list | grep -q com.brave.Browser; then
        flatpak install -y flathub com.brave.Browser
    fi

    local brave_dir="$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser"
    if [ -d "$backup_path/flatpak" ]; then
        mkdir -p "$brave_dir"
        cp -r "$backup_path/flatpak/"* "$brave_dir/"
        print_success "Brave (Flatpak) restauré"
    else
        print_warning "Aucune donnée Brave Flatpak trouvée"
    fi
}

restore_bottles() {
    local backup_path="$1/bottles"
    [ -d "$backup_path" ] || { print_error "Sauvegarde Bottles introuvable"; return 1; }

    print_info "Restauration de Bottles..."

    if ! flatpak list | grep -q com.usebottles.bottles; then
        flatpak install -y flathub com.usebottles.bottles
    fi

    local bottles_data="$HOME/.var/app/com.usebottles.bottles/data/bottles"
    local bottles_config="$HOME/.var/app/com.usebottles.bottles/config"

    if [ -d "$backup_path/flatpak_data" ]; then
        mkdir -p "$bottles_data"
        cp -r "$backup_path/flatpak_data/"* "$bottles_data/"
    fi

    if [ -d "$backup_path/flatpak_config" ]; then
        mkdir -p "$bottles_config"
        cp -r "$backup_path/flatpak_config/"* "$bottles_config/"
    fi

    print_success "Bottles (Flatpak) restauré"
}

### FONCTIONS UTILITAIRES ###
check_and_install_flatpak_apps() {
    local missing_apps=()
    local installed_apps=$(flatpak list --app --columns=application)

    for app_name in "${!FLATPAK_APPS[@]}"; do
        local app_id="${FLATPAK_APPS[$app_name]}"
        if ! echo "$installed_apps" | grep -q "^$app_id$"; then
            missing_apps+=("$app_name")
        fi
    done

    if [ ${#missing_apps[@]} -gt 0 ]; then
        print_warning "Applications Flatpak manquantes:"
        printf " - %s\n" "${missing_apps[@]}"

        read -p "Voulez-vous les installer ? (o/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[OoYy]$ ]]; then
            for app_name in "${missing_apps[@]}"; do
                local app_id="${FLATPAK_APPS[$app_name]}"
                flatpak install -y flathub "$app_id"
            done
        fi
    else
        print_success "Toutes les applications Flatpak recommandées sont installées"
    fi
}

list_backups() {
    print_info "Liste des sauvegardes disponibles dans $DEFAULT_BACKUP_BASE_DIR:"
    ls -l "$DEFAULT_BACKUP_BASE_DIR"
}

### MENUS ###
backup_management_menu() {
    while true; do
        echo
        echo "=== MENU DE GESTION DES SAUVEGARDES ==="
        echo "1. Lister les sauvegardes disponibles"
        echo "2. Supprimer une sauvegarde"
        echo "3. Retour au menu principal"
        echo

        read -p "Choix (1-3): " choice
        case $choice in
            1)
                print_info "Liste des sauvegardes disponibles dans $DEFAULT_BACKUP_BASE_DIR:"
                ls -l "$DEFAULT_BACKUP_BASE_DIR"
                ;;
            2)
                read -p "Nom du dossier de sauvegarde à supprimer: " backup_name
                local backup_path="$DEFAULT_BACKUP_BASE_DIR/$backup_name"
                if [ -d "$backup_path" ]; then
                    sudo rm -rf "$backup_path" && print_success "Sauvegarde supprimée: $backup_name" || print_error "Échec de la suppression de la sauvegarde: $backup_name"
                else
                    print_error "Dossier de sauvegarde introuvable: $backup_name"
                fi
                ;;
            3)
                return
                ;;
            *)
                print_error "Choix invalide"
                ;;
        esac
    done
}

main_menu() {
    while true; do
        echo
        echo "=== MENU PRINCIPAL ==="
        echo "1. Effectuer une sauvegarde complète"
        echo "2. Restaurer à partir d'une sauvegarde"
        echo "3. Vérifier les applications Flatpak"
        echo "4. Gérer les sauvegardes"
        echo "5. Installer Ollama et Open WebUI"
        echo "6. Télécharger les modèles"
        echo "7. Quitter"
        echo

        read -p "Choix (1-7): " choice
        case $choice in
            1) full_backup ;;
            2) restore_menu ;;
            3) check_and_install_flatpak_apps ;;
            4) backup_management_menu ;;
            5) install_ollama_and_openwebui ;;
            6) download_models ;;
            7)
                print_info "${BLUE}Au revoir !${NC}"
                exit 0
                ;;
            *) print_error "Choix invalide" ;;
        esac
    done
}

# Fonction pour télécharger les modèles
download_models() {
    print_info "Téléchargement des modèles..."

    # Téléchargement des modèles
    ollama pull mistral
    ollama pull llama3:3b
    ollama pull llama3:8b
    ollama pull deepseek-r1:8b
    print_success "Modèles téléchargés avec succès."
}

install_ollama_and_openwebui() {
    print_info "Installation et configuration d'Ollama et Open WebUI..."

    # Installation d'Ollama
    print_info "Installation d'Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh

    # Configuration d'Ollama en tant que service
    print_info "Configuration d'Ollama en tant que service..."
    sudo tee /etc/systemd/system/ollama.service > /dev/null <<EOL
[Unit]
Description=Ollama Service
After=network.target

[Service]
ExecStart=/usr/bin/ollama serve
User=$USER
Group=$USER
Restart=always

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable ollama.service
    sudo systemctl start ollama.service

    # Installation de Docker
    print_info "Installation de Docker..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce
    sudo systemctl enable docker
    sudo systemctl start docker

    # Installation de Docker Compose
    print_info "Installation de Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # Configuration d'Open WebUI
    print_info "Configuration d'Open WebUI..."
    mkdir -p ~/open-webui
    cd ~/open-webui

    cat > docker-compose.yml <<EOF
version: '3.8'

services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    ports:
      - "3000:8080"
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped
EOF

    docker-compose pull
    docker-compose up -d

    print_success "Ollama et Open WebUI ont été installés et configurés avec succès."
}

restore_menu() {
    read -p "Chemin du dossier de sauvegarde (appuyez sur Entrée pour utiliser le chemin par défaut: $DEFAULT_BACKUP_BASE_DIR): " backup_dir

    if [ -z "$backup_dir" ]; then
        backup_dir="$DEFAULT_BACKUP_BASE_DIR"
    fi

    [ -d "$backup_dir" ] || {
        print_error "Dossier introuvable: $backup_dir"
        return
    }

    echo
    echo "=== MENU DE RESTAURATION ==="
    echo "1. Tout restaurer"
    echo "2. Paquets DEB seulement"
    echo "3. Flatpaks seulement"
    echo "4. Extensions GNOME seulement"
    echo "5. Comptes seulement"
    echo "6. Brave seulement"
    echo "7. Bottles seulement"
    echo "8. Retour"
    echo

    read -p "Choix (1-8): " choice
    case $choice in
        1)
            restore_deb_packages "$backup_dir"
            restore_flatpak "$backup_dir"
            restore_gnome_extensions "$backup_dir"
            restore_accounts "$backup_dir"
            restore_brave "$backup_dir"
            restore_bottles "$backup_dir"
            ;;
        2) restore_deb_packages "$backup_dir" ;;
        3) restore_flatpak "$backup_dir" ;;
        4) restore_gnome_extensions "$backup_dir" ;;
        5) restore_accounts "$backup_dir" ;;
        6) restore_brave "$backup_dir" ;;
        7) restore_bottles "$backup_dir" ;;
        8) return ;;
        *) print_error "Choix invalide" ;;
    esac
}

### POINT D'ENTREE ###
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_dependencies || {
        print_warning "Certaines dépendances sont manquantes - certaines fonctionnalités peuvent ne pas être disponibles"
        sleep 2
    }
    main_menu
fi
