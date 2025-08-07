#!/usr/bin/env bash

# G A G (Gestionnaire d'Applications GNOME) - Version Pro 4.0
# Backup/Restauration modulaire avec système de sauvegardes multiples
# Auteur: Fontaine Johnny
# Date: 15/07/2024

set -e

# =====================================
# CONFIGURATION
# =====================================

# Couleurs et styles
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'
UNDERLINE='\033[4m'

# Emojis
EMOJI_OK="✅"
EMOJI_ERROR="❌"
EMOJI_WARN="⚠️ "
EMOJI_INFO="ℹ️ "
EMOJI_CONFIG="⚙️ "
EMOJI_BACKUP="📦"
EMOJI_RESTORE="🔄"
EMOJI_APPS="📱"
EMOJI_DEB="📦"
EMOJI_FLATPAK="📦"
EMOJI_OLLAMA="🤖"
EMOJI_PWSH="💻"
EMOJI_STARTUP="🚀"
EMOJI_BRAVE="🦁"
EMOJI_BOTTLES="🍾"
EMOJI_LIST="📋"
EMOJI_CHECK="🔍"

# Répertoires de sauvegarde
BACKUP_BASE_DIR="$HOME/Backups/gnome-apps-backup"
CURRENT_BACKUP=""

# Applications Flatpak à gérer
declare -A FLATPAK_APPS=(
    ["Arduino IDE 2"]="cc.arduino.IDE2"
    ["AnyDesk"]="com.anydesk.Anydesk"
    ["Bitwarden"]="com.bitwarden.desktop"
    ["Brave Browser"]="com.brave.Browser"
    ["Dropbox"]="com.dropbox.Client"
    ["Flatseal"]="com.github.tchx84.Flatseal"
    ["Bottles"]="com.usebottles.bottles"
    # ... (autres applications)
)

# Modèles Ollama recommandés
declare -a OLLAMA_MODELS=(
    "llama3.1:8b"
    "codellama:7b"
    "mistral:7b"
    # ... (autres modèles)
)

# Applications tierces à vérifier
declare -A THIRD_PARTY_APPS=(
    ["Outlook"]="outlook"
    ["Microsoft Teams"]="teams"
    ["OpenFortiGUI"]="openfortigui"
    ["Ollama"]="ollama"
    ["Open WebUI"]="open-webui"
    ["PowerShell"]="pwsh"
)

# =====================================
# FONCTIONS UTILITAIRES
# =====================================

print_header() {
    echo -e "${PURPLE}${BOLD}${UNDERLINE}$1${NC}"
}

print_section() {
    echo -e "\n${CYAN}${BOLD}$1${NC}"
}

print_info() {
    echo -e "${BLUE}${EMOJI_INFO} [INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}${EMOJI_OK} [SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}${EMOJI_WARN} [WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}${EMOJI_ERROR} [ERROR]${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

select_backup_dir() {
    local backups=()
    local count=1

    print_section "${EMOJI_LIST} Liste des sauvegardes disponibles"
    
    if [ ! -d "$BACKUP_BASE_DIR" ]; then
        print_error "Aucune sauvegarde disponible"
        return 1
    fi

    while IFS= read -r -d '' dir; do
        if [ -d "$dir" ] && [ "$(basename "$dir")" != "gnome-apps-backup" ]; then
            backups+=("$dir")
            echo -e "${CYAN}${count}.${NC} $(basename "$dir")"
            ((count++))
        fi
    done < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

    if [ ${#backups[@]} -eq 0 ]; then
        print_error "Aucune sauvegarde disponible"
        return 1
    fi

    echo -ne "${YELLOW}${BOLD}Sélectionnez une sauvegarde [1-${#backups[@]}]: ${NC}"
    read -r choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#backups[@]} ]; then
        CURRENT_BACKUP="${backups[$((choice-1))]}"
        print_success "Sauvegarde sélectionnée: $(basename "$CURRENT_BACKUP")"
        return 0
    else
        print_error "Sélection invalide"
        return 1
    fi
}

create_backup_dir() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    CURRENT_BACKUP="$BACKUP_BASE_DIR/$timestamp"
    mkdir -p "$CURRENT_BACKUP"
    print_success "Nouvelle sauvegarde créée: $timestamp"
}

# =====================================
# FONCTIONS DE VÉRIFICATION
# =====================================

check_requirements() {
    print_section "${EMOJI_CHECK} Vérification des prérequis système"
    
    local missing=()
    local to_install=()
    
    # Vérifier les outils de base
    declare -a required_tools=("curl" "wget" "git")
    
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing+=("$tool")
            to_install+=("$tool")
            print_warning "$tool n'est pas installé"
        fi
    done
    
    # Vérifier Flatpak
    if ! command_exists "flatpak"; then
        print_warning "Flatpak n'est pas installé - nécessaire pour de nombreuses applications"
        to_install+=("flatpak")
    fi
    
    # Vérifier Docker
    if ! command_exists "docker"; then
        print_warning "Docker n'est pas installé - nécessaire pour Open WebUI"
    fi
    
    # Vérifier Ollama
    if ! command_exists "ollama"; then
        print_warning "Ollama n'est pas installé - nécessaire pour les modèles IA"
    fi
    
    if [ ${#to_install[@]} -gt 0 ]; then
        print_warning "Outils manquants: ${missing[*]}"
        echo -ne "${YELLOW}Voulez-vous les installer automatiquement? [y/N]: ${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            if command_exists apt; then
                sudo apt update
                sudo apt install -y "${to_install[@]}"
                print_success "Outils installés avec succès"
            elif command_exists dnf; then
                sudo dnf install -y "${to_install[@]}"
                print_success "Outils installés avec succès"
            elif command_exists pacman; then
                sudo pacman -S --noconfirm "${to_install[@]}"
                print_success "Outils installés avec succès"
            else
                print_error "Gestionnaire de paquets non supporté. Veuillez installer manuellement: ${to_install[*]}"
            fi
        fi
    else
        print_success "Tous les prérequis système sont satisfaits"
    fi
}

check_installed_apps() {
    print_section "${EMOJI_CHECK} Vérification des applications installées"
    
    print_info "${EMOJI_DEB} Applications DEB:"
    if command_exists dpkg; then
        dpkg --get-selections | head -n 10
        echo "... (plus dans le rapport complet)"
    else
        print_warning "dpkg non disponible"
    fi
    
    print_info "\n${EMOJI_FLATPAK} Applications Flatpak:"
    if command_exists flatpak; then
        flatpak list --app --columns=application 2>/dev/null | head -n 10
        echo "... (plus dans le rapport complet)"
    else
        print_warning "Flatpak non installé"
    fi
    
    print_info "\n${EMOJI_INFO} Applications tierces:"
    for app in "${!THIRD_PARTY_APPS[@]}"; do
        if command_exists "${THIRD_PARTY_APPS[$app]}"; then
            echo -e "${GREEN}${EMOJI_OK} $app${NC}"
        else
            echo -e "${RED}${EMOJI_ERROR} $app (manquant)${NC}"
        fi
    done
    
    print_info "\n${EMOJI_WARN} Recommandations:"
    if ! command_exists "ollama"; then
        echo "- Installez Ollama pour les fonctionnalités IA"
    fi
    if ! command_exists "docker"; then
        echo "- Installez Docker pour exécuter Open WebUI"
    fi
    if command_exists flatpak && ! flatpak list 2>/dev/null | grep -q "com.brave.Browser"; then
        echo "- Brave Browser n'est pas installé (recommandé)"
    fi
}

# =====================================
# SAUVEGARDES SPÉCIFIQUES
# =====================================

backup_brave() {
    print_section "${EMOJI_BRAVE} Sauvegarde de Brave Browser (Flatpak)"
    
    local config_dir="$CURRENT_BACKUP/brave"
    mkdir -p "$config_dir"
    
    # Sauvegarde des données Brave Flatpak
    local brave_data_dir="$HOME/.var/app/com.brave.Browser"
    if [ -d "$brave_data_dir" ]; then
        cp -r "$brave_data_dir" "$config_dir" && \
        print_success "Données Brave sauvegardées"
    else
        print_warning "Aucune donnée Brave trouvée"
    fi
    
    # Sauvegarde des préférences
    if command_exists dconf; then
        dconf dump /com/brave/ > "$config_dir/brave-settings.dconf" 2>/dev/null && \
        print_success "Préférences Brave sauvegardées" || \
        print_warning "Aucune préférence Brave à sauvegarder"
    else
        print_warning "dconf non disponible pour sauvegarder les préférences"
    fi
}

backup_bottles() {
    print_section "${EMOJI_BOTTLES} Sauvegarde de Bottles"
    
    local config_dir="$CURRENT_BACKUP/bottles"
    mkdir -p "$config_dir"
    
    # Sauvegarde des bouteilles
    local bottles_dir="$HOME/.var/app/com.usebottles.bottles/data/bottles"
    if [ -d "$bottles_dir" ]; then
        cp -r "$bottles_dir" "$config_dir" && \
        print_success "Bouteilles Bottles sauvegardées"
    else
        print_warning "Aucune bouteille Bottles trouvée"
    fi
    
    # Sauvegarde de la configuration
    local bottles_config="$HOME/.var/app/com.usebottles.bottles/config"
    if [ -d "$bottles_config" ]; then
        cp -r "$bottles_config" "$config_dir" && \
        print_success "Configuration Bottles sauvegardée"
    fi
}

backup_startup_apps() {
    print_section "${EMOJI_STARTUP} Sauvegarde des applications de démarrage"
    
    local startup_dir="$CURRENT_BACKUP/startup"
    mkdir -p "$startup_dir"
    
    # Sauvegarde des applications de démarrage
    if [ -d "$HOME/.config/autostart" ]; then
        cp -r "$HOME/.config/autostart" "$startup_dir" && \
        print_success "Applications de démarrage sauvegardées"
    else
        print_warning "Aucune application de démarrage trouvée"
    fi
}

backup_ollama() {
    print_section "${EMOJI_OLLAMA} Sauvegarde d'Ollama"
    
    local config_dir="$CURRENT_BACKUP/ollama"
    mkdir -p "$config_dir"
    
    # Sauvegarde des modèles
    if command_exists ollama; then
        ollama list > "$config_dir/models.txt" 2>/dev/null && \
        print_success "Liste des modèles sauvegardée" || \
        print_warning "Impossible de sauvegarder la liste des modèles"
    else
        print_warning "Ollama n'est pas installé"
    fi
    
    # Sauvegarde de la configuration
    if [ -d "$HOME/.ollama" ]; then
        cp -r "$HOME/.ollama" "$config_dir" && \
        print_success "Configuration Ollama sauvegardée"
    else
        print_warning "Aucune configuration Ollama trouvée"
    fi
}

# =====================================
# RESTAURATIONS SPÉCIFIQUES
# =====================================

restore_brave() {
    print_section "${EMOJI_BRAVE} Restauration de Brave Browser"
    
    local config_dir="$CURRENT_BACKUP/brave"
    
    if [ -d "$config_dir/com.brave.Browser" ]; then
        # Restauration des données
        mkdir -p "$HOME/.var/app"
        cp -r "$config_dir/com.brave.Browser" "$HOME/.var/app/" && \
        print_success "Données Brave restaurées"
    else
        print_warning "Aucune donnée Brave à restaurer"
    fi
    
    if [ -f "$config_dir/brave-settings.dconf" ] && command_exists dconf; then
        # Restauration des préférences
        dconf load /com/brave/ < "$config_dir/brave-settings.dconf" && \
        print_success "Préférences Brave restaurées"
    else
        print_warning "Aucune préférence Brave à restaurer"
    fi
}

restore_bottles() {
    print_section "${EMOJI_BOTTLES} Restauration de Bottles"
    
    local config_dir="$CURRENT_BACKUP/bottles"
    
    if [ -d "$config_dir/bottles" ]; then
        # Restauration des bouteilles
        mkdir -p "$HOME/.var/app/com.usebottles.bottles/data"
        cp -r "$config_dir/bottles" "$HOME/.var/app/com.usebottles.bottles/data/" && \
        print_success "Bouteilles Bottles restaurées"
    else
        print_warning "Aucune bouteille à restaurer"
    fi
    
    if [ -d "$config_dir/config" ]; then
        # Restauration de la configuration
        mkdir -p "$HOME/.var/app/com.usebottles.bottles"
        cp -r "$config_dir/config" "$HOME/.var/app/com.usebottles.bottles/" && \
        print_success "Configuration Bottles restaurée"
    else
        print_warning "Aucune configuration à restaurer"
    fi
}

restore_startup_apps() {
    print_section "${EMOJI_STARTUP} Restauration des applications de démarrage"
    
    local config_dir="$CURRENT_BACKUP/startup"
    
    if [ -d "$config_dir/autostart" ]; then
        mkdir -p "$HOME/.config"
        cp -r "$config_dir/autostart" "$HOME/.config/" && \
        print_success "Applications de démarrage restaurées"
    else
        print_warning "Aucune application de démarrage à restaurer"
    fi
}

restore_ollama() {
    print_section "${EMOJI_OLLAMA} Restauration d'Ollama"
    
    local config_dir="$CURRENT_BACKUP/ollama"
    
    if [ -d "$config_dir" ]; then
        # Restauration de la configuration
        if [ -d "$config_dir/.ollama" ]; then
            mkdir -p "$HOME"
            cp -r "$config_dir/.ollama" "$HOME/" && \
            print_success "Configuration Ollama restaurée"
        fi
        
        # Restauration des modèles
        if [ -f "$config_dir/models.txt" ] && command_exists ollama; then
            print_info "Téléchargement des modèles Ollama..."
            while read -r model; do
                if [ -n "$model" ]; then
                    ollama pull "$model" || print_warning "Impossible de télécharger le modèle: $model"
                fi
            done < "$config_dir/models.txt"
            print_success "Modèles Ollama restaurés"
        fi
    else
        print_warning "Aucune sauvegarde Ollama à restaurer"
    fi
}

# =====================================
# APPLICATIONS TIERCES
# =====================================

install_outlook() {
    print_info "Installation d'Outlook..."
    
    # Téléchargement et installation du package Outlook
    if command_exists apt; then
        mkdir -p ~/Downloads
        wget -O ~/Downloads/outlook.deb "https://outlook.office.com/owa/download?ft=2" || {
            print_error "Échec du téléchargement d'Outlook"
            return 1
        }
        sudo apt install -y ~/Downloads/outlook.deb && {
            rm ~/Downloads/outlook.deb
            print_success "Outlook installé avec succès"
        } || {
            print_error "Échec de l'installation d'Outlook"
        }
    else
        print_error "Installation d'Outlook non supportée sur ce système"
    fi
}

install_teams() {
    print_info "Installation de Microsoft Teams..."
    
    # Installation de Teams via Flatpak
    if command_exists flatpak; then
        flatpak install -y flathub com.microsoft.Teams && \
        print_success "Microsoft Teams installé avec succès" || \
        print_error "Échec de l'installation de Teams"
    else
        print_error "Flatpak n'est pas installé. Impossible d'installer Teams."
    fi
}

install_openfortigui() {
    print_info "Installation d'OpenFortiGUI..."
    
    # Ajout du PPA et installation
    if command_exists apt; then
        sudo add-apt-repository -y ppa:openfortivpn/openfortivpn && \
        sudo apt update && \
        sudo apt install -y openfortigui && \
        print_success "OpenFortiGUI installé avec succès" || \
        print_error "Échec de l'installation d'OpenFortiGUI"
    else
        print_error "Installation d'OpenFortiGUI non supportée sur ce système"
    fi
}

install_ollama_stack() {
    print_info "Installation d'Ollama..."
    
    # Installation d'Ollama
    curl -fsSL https://ollama.com/install.sh | sh && \
    print_success "Ollama installé avec succès" || {
        print_error "Échec de l'installation d'Ollama"
        return 1
    }
    
    # Démarrer le service Ollama
    if command_exists systemctl; then
        sudo systemctl enable ollama || print_warning "Impossible d'activer le service Ollama"
        sudo systemctl start ollama || print_warning "Impossible de démarrer le service Ollama"
    fi
    
    print_info "Installation d'Open WebUI..."
    
    # Installation d'Open WebUI avec Docker
    if command_exists docker; then
        docker run -d \
            --network=host \
            -v open-webui:/app/backend/data \
            -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
            --name open-webui \
            --restart always \
            ghcr.io/open-webui/open-webui:main && {
            print_success "Open WebUI installé avec succès"
            print_info "Accédez à l'interface sur: http://localhost:8080"
        } || {
            print_error "Échec de l'installation d'Open WebUI"
        }
    else
        print_error "Docker n'est pas installé. Impossible d'installer Open WebUI."
    fi
}

install_powershell() {
    print_info "Installation de PowerShell..."
    
    # Installation de PowerShell
    if command_exists apt; then
        # Importation de la clé GPG de Microsoft
        wget -O- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg && \
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/microsoft-debian-$(lsb_release -cs)-prod $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/microsoft.list && \
        sudo apt update && \
        sudo apt install -y powershell && \
        print_success "PowerShell installé avec succès" || \
        print_error "Échec de l'installation de PowerShell"
    elif command_exists dnf; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
        curl -sSL https://packages.microsoft.com/config/rhel/$(rpm -E %rhel)/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo && \
        sudo dnf install -y powershell && \
        print_success "PowerShell installé avec succès" || \
        print_error "Échec de l'installation de PowerShell"
    else
        print_error "Installation de PowerShell non supportée sur ce système"
    fi
}

# =====================================
# MENU APPLICATIONS TIERCES
# =====================================

install_third_party() {
    while true; do
        clear
        echo -e "${PURPLE}${BOLD}Menu Applications Tierces${NC}"
        echo -e "${CYAN} 1. ${EMOJI_APPS} Installer Outlook"
        echo -e "${CYAN} 2. ${EMOJI_APPS} Installer Microsoft Teams"
        echo -e "${CYAN} 3. ${EMOJI_APPS} Installer OpenFortiGUI"
        echo -e "${CYAN} 4. ${EMOJI_OLLAMA} Installer Ollama + Open WebUI"
        echo -e "${CYAN} 5. ${EMOJI_PWSH} Installer PowerShell"
        echo -e "${CYAN} 6. ${EMOJI_INFO} Retour au menu principal"
        echo -ne "${YELLOW}${BOLD}Choisissez une option [1-6]: ${NC}"
        read -r choice
        
        case $choice in
            1) install_outlook ;;
            2) install_teams ;;
            3) install_openfortigui ;;
            4) install_ollama_stack ;;
            5) install_powershell ;;
            6) return ;;
            *) print_error "Option invalide" ;;
        esac
        
        echo -ne "\n${YELLOW}Appuyez sur une touche pour continuer...${NC}"
        read -n 1 -s -r
    done
}

# =====================================
# MENU DE SAUVEGARDE
# =====================================

backup_menu() {
    while true; do
        clear
        echo -e "${PURPLE}${BOLD}Menu de Sauvegarde${NC}"
        echo -e "${CYAN} 1. ${EMOJI_BACKUP} Nouvelle sauvegarde complète"
        echo -e "${CYAN} 2. ${EMOJI_BRAVE} Sauvegarder Brave Browser"
        echo -e "${CYAN} 3. ${EMOJI_BOTTLES} Sauvegarder Bottles"
        echo -e "${CYAN} 4. ${EMOJI_STARTUP} Sauvegarder les applications de démarrage"
        echo -e "${CYAN} 5. ${EMOJI_OLLAMA} Sauvegarder Ollama"
        echo -e "${CYAN} 6. ${EMOJI_INFO} Retour au menu principal"
        echo -ne "${YELLOW}${BOLD}Choisissez une option [1-6]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                create_backup_dir
                backup_brave
                backup_bottles
                backup_startup_apps
                backup_ollama
                print_success "Sauvegarde complète terminée!"
                ;;
            2) 
                create_backup_dir
                backup_brave
                ;;
            3) 
                create_backup_dir
                backup_bottles
                ;;
            4) 
                create_backup_dir
                backup_startup_apps
                ;;
            5) 
                create_backup_dir
                backup_ollama
                ;;
            6) return ;;
            *) print_error "Option invalide" ;;
        esac
        
        echo -ne "\n${YELLOW}Appuyez sur une touche pour continuer...${NC}"
        read -n 1 -s -r
    done
}

# =====================================
# MENU DE RESTAURATION
# =====================================

restore_menu() {
    while true; do
        clear
        echo -e "${PURPLE}${BOLD}Menu de Restauration${NC}"
        
        if ! select_backup_dir; then
            echo -ne "\n${YELLOW}Appuyez sur une touche pour continuer...${NC}"
            read -n 1 -s -r
            return
        fi
        
        while true; do
            clear
            echo -e "${PURPLE}${BOLD}Restauration: $(basename "$CURRENT_BACKUP")${NC}"
            echo -e "${CYAN} 1. ${EMOJI_RESTORE} Restaurer tout"
            echo -e "${CYAN} 2. ${EMOJI_BRAVE} Restaurer Brave Browser"
            echo -e "${CYAN} 3. ${EMOJI_BOTTLES} Restaurer Bottles"
            echo -e "${CYAN} 4. ${EMOJI_STARTUP} Restaurer les applications de démarrage"
            echo -e "${CYAN} 5. ${EMOJI_OLLAMA} Restaurer Ollama"
            echo -e "${CYAN} 6. ${EMOJI_INFO} Changer de sauvegarde"
            echo -e "${CYAN} 7. ${EMOJI_INFO} Retour au menu principal"
            echo -ne "${YELLOW}${BOLD}Choisissez une option [1-7]: ${NC}"
            read -r choice
            
            case $choice in
                1)
                    restore_brave
                    restore_bottles
                    restore_startup_apps
                    restore_ollama
                    print_success "Restauration complète terminée!"
                    ;;
                2) restore_brave ;;
                3) restore_bottles ;;
                4) restore_startup_apps ;;
                5) restore_ollama ;;
                6) break ;;
                7) return ;;
                *) print_error "Option invalide" ;;
            esac
            
            echo -ne "\n${YELLOW}Appuyez sur une touche pour continuer...${NC}"
            read -n 1 -s -r
        done
    done
}

# =====================================
# MENU DE CONFIGURATION
# =====================================

config_menu() {
    while true; do
        clear
        echo -e "${PURPLE}${BOLD}Menu de Configuration${NC}"
        echo -e "${CYAN} 1. ${EMOJI_CONFIG} Vérifier les prérequis système"
        echo -e "${CYAN} 2. ${EMOJI_CONFIG} Configurer le dépôt Flatpak"
        echo -e "${CYAN} 3. ${EMOJI_CONFIG} Configurer les applications de démarrage"
        echo -e "${CYAN} 4. ${EMOJI_INFO} Retour au menu principal"
        echo -ne "${YELLOW}${BOLD}Choisissez une option [1-4]: ${NC}"
        read -r choice
        
        case $choice in
            1) check_requirements ;;
            2) 
                if command_exists flatpak; then
                    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
                    print_success "Dépôt Flatpak configuré" || \
                    print_error "Échec de la configuration du dépôt Flatpak"
                else
                    print_error "Flatpak n'est pas installé"
                fi
                ;;
            3)
                if command_exists gnome-session-properties; then
                    gnome-session-properties &
                    print_info "Utilisez l'interface graphique pour configurer les applications de démarrage"
                else
                    print_error "gnome-session-properties non disponible"
                fi
                ;;
            4) return ;;
            *) print_error "Option invalide" ;;
        esac
        
        echo -ne "\n${YELLOW}Appuyez sur une touche pour continuer...${NC}"
        read -n 1 -s -r
    done
}

# =====================================
# MENU PRINCIPAL
# =====================================

main_menu() {
    while true; do
        clear
        echo -e "${PURPLE}${BOLD}"
        echo "   ____       _       ____  "
        echo "  / ___|     / \\     / ___| "
        echo " | |  _     / _ \\   | |  _  "
        echo " | |_| |   / ___ \\  | |_| | "
        echo "  \\____|  /_/   \\_\\  \\____| "
        echo -e "${NC}"
        echo -e "${BLUE}${BOLD} G A G (Gestionnaire d'Applications GNOME) - Version Pro 4.0 ${NC}"
        echo -e "${BLUE}${BOLD}=============================================================${NC}"
        echo -e "${CYAN} 1. ${EMOJI_BACKUP} Sauvegarde"
        echo -e "${CYAN} 2. ${EMOJI_RESTORE} Restauration"
        echo -e "${CYAN} 3. ${EMOJI_APPS} Installer des applications tierces"
        echo -e "${CYAN} 4. ${EMOJI_CONFIG} Configuration"
        echo -e "${CYAN} 5. ${EMOJI_CHECK} Vérifier les applications installées"
        echo -e "${CYAN} 6. ${EMOJI_INFO} Quitter"
        echo -ne "${YELLOW}${BOLD}Choisissez une option [1-6]: ${NC}"
        read -r choice

        case $choice in
            1) backup_menu ;;
            2) restore_menu ;;
            3) install_third_party ;;
            4) config_menu ;;
            5) check_installed_apps ;;
            6)
                echo -e "${GREEN}${EMOJI_OK} Merci d'avoir utilisé GAG. À bientôt!${NC}"
                exit 0
                ;;
            *) print_error "Option invalide" ;;
        esac

        echo -ne "\n${YELLOW}Appuyez sur une touche pour continuer...${NC}"
        read -n 1 -s -r
    done
}

# =====================================
# POINT D'ENTRÉE PRINCIPAL
# =====================================

clear
print_header "Démarrage de GAG Pro 4.0"
check_requirements
main_menu
