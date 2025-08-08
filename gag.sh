#!/usr/bin/env bash

# G A G (Gestionnaire d'Applications GNOME) - Version Pro 4.0
# Backup/Restauration modulaire avec système de sauvegardes multiples
# Auteur: Fontaine Johnny
# Date: 07/08/2025

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
EMOJI_DELETE="🗑️ "

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
)

# Modèles Ollama recommandés
declare -a OLLAMA_MODELS=(
    "llama3.1:8b"
    "codellama:7b"
    "mistral:7b"
)

# Applications tierces à vérifier
declare -A THIRD_PARTY_APPS=(
    ["Outlook"]="outlook-for-linux"
    ["Microsoft Teams"]="teams-for-linux"
    ["OpenFortiGUI"]="openfortigui"
    ["Ollama"]="ollama"
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
            local backup_date=$(basename "$dir")
            local backup_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo -e "${CYAN}${count}.${NC} ${backup_date} (${backup_size})"
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
# GESTION DES SAUVEGARDES
# =====================================

list_backups() {
    print_section "${EMOJI_LIST} Liste des sauvegardes disponibles"
    
    if [ ! -d "$BACKUP_BASE_DIR" ]; then
        print_error "Aucune sauvegarde disponible"
        return 1
    fi

    local count=1
    local total_size=0

    while IFS= read -r -d '' dir; do
        if [ -d "$dir" ] && [ "$(basename "$dir")" != "gnome-apps-backup" ]; then
            local backup_date=$(basename "$dir")
            local backup_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            local backup_size_bytes=$(du -sb "$dir" 2>/dev/null | cut -f1)
            local formatted_date=$(date -d "${backup_date:0:8} ${backup_date:9:2}:${backup_date:11:2}:${backup_date:13:2}" "+%d/%m/%Y %H:%M:%S" 2>/dev/null || echo "$backup_date")
            
            echo -e "${CYAN}${count}.${NC} ${formatted_date} - Taille: ${backup_size}"
            
            # Afficher le contenu de la sauvegarde
            local content=""
            [ -d "$dir/brave" ] && content="${content}Brave "
            [ -d "$dir/bottles" ] && content="${content}Bottles "
            [ -d "$dir/startup" ] && content="${content}Démarrage "
            [ -d "$dir/ollama" ] && content="${content}Ollama "
            [ -f "$dir/deb-packages.list" ] && content="${content}DEB "
            [ -f "$dir/flatpak-apps.list" ] && content="${content}Flatpak "
            
            if [ -n "$content" ]; then
                echo -e "   ${BLUE}Contenu:${NC} ${content}"
            fi
            
            total_size=$((total_size + backup_size_bytes))
            ((count++))
        fi
    done < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

    if [ $count -eq 1 ]; then
        print_warning "Aucune sauvegarde disponible"
    else
        local total_size_human=$(numfmt --to=iec --suffix=B $total_size)
        echo -e "\n${BOLD}Total: $((count-1)) sauvegardes - Espace utilisé: ${total_size_human}${NC}"
    fi
}

delete_backups() {
    while true; do
        clear
        print_header "${EMOJI_DELETE} Gestion des sauvegardes - Suppression"
        
        list_backups
        
        if [ ! -d "$BACKUP_BASE_DIR" ] || [ -z "$(ls -A "$BACKUP_BASE_DIR" 2>/dev/null)" ]; then
            echo -ne "\n${YELLOW}Appuyez sur une touche pour continuer...${NC}"
            read -n 1 -s -r
            return
        fi

        echo -e "\n${CYAN}Options de suppression:${NC}"
        echo -e "${CYAN} 1. ${EMOJI_DELETE} Supprimer une sauvegarde spécifique"
        echo -e "${CYAN} 2. ${EMOJI_DELETE} Supprimer les sauvegardes anciennes (> 30 jours)"
        echo -e "${CYAN} 3. ${EMOJI_DELETE} Supprimer toutes les sauvegardes"
        echo -e "${CYAN} 4. ${EMOJI_INFO} Retour au menu de gestion"
        echo -ne "${YELLOW}${BOLD}Choisissez une option [1-4]: ${NC}"
        read -r choice

        case $choice in
            1) delete_specific_backup ;;
            2) delete_old_backups ;;
            3) delete_all_backups ;;
            4) return ;;
            *) print_error "Option invalide" ;;
        esac

        echo -ne "\n${YELLOW}Appuyez sur une touche pour continuer...${NC}"
        read -n 1 -s -r
    done
}

delete_specific_backup() {
    local backups=()
    local count=1

    print_section "${EMOJI_DELETE} Suppression d'une sauvegarde spécifique"
    
    while IFS= read -r -d '' dir; do
        if [ -d "$dir" ] && [ "$(basename "$dir")" != "gnome-apps-backup" ]; then
            backups+=("$dir")
            local backup_date=$(basename "$dir")
            local backup_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            local formatted_date=$(date -d "${backup_date:0:8} ${backup_date:9:2}:${backup_date:11:2}:${backup_date:13:2}" "+%d/%m/%Y %H:%M:%S" 2>/dev/null || echo "$backup_date")
            echo -e "${CYAN}${count}.${NC} ${formatted_date} (${backup_size})"
            ((count++))
        fi
    done < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

    if [ ${#backups[@]} -eq 0 ]; then
        print_error "Aucune sauvegarde à supprimer"
        return
    fi

    echo -ne "${YELLOW}${BOLD}Sélectionnez la sauvegarde à supprimer [1-${#backups[@]}] (0 pour annuler): ${NC}"
    read -r choice

    if [ "$choice" = "0" ]; then
        print_info "Suppression annulée"
        return
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#backups[@]} ]; then
        local backup_to_delete="${backups[$((choice-1))]}"
        local backup_name=$(basename "$backup_to_delete")
        
        echo -ne "${RED}${BOLD}Êtes-vous sûr de vouloir supprimer la sauvegarde '${backup_name}' ? [y/N]: ${NC}"
        read -r confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -rf "$backup_to_delete" && \
            print_success "Sauvegarde '$backup_name' supprimée avec succès" || \
            print_error "Échec de la suppression de la sauvegarde '$backup_name'"
        else
            print_info "Suppression annulée"
        fi
    else
        print_error "Sélection invalide"
    fi
}

delete_old_backups() {
    print_section "${EMOJI_DELETE} Suppression des sauvegardes anciennes (> 30 jours)"
    
    local deleted_count=0
    local current_date=$(date +%s)
    local thirty_days_ago=$((current_date - 30 * 24 * 3600))

    while IFS= read -r -d '' dir; do
        if [ -d "$dir" ] && [ "$(basename "$dir")" != "gnome-apps-backup" ]; then
            local backup_date=$(basename "$dir")
            # Extraire la date du nom de fichier (format: YYYYMMDD_HHMMSS)
            local backup_date_formatted="${backup_date:0:4}-${backup_date:4:2}-${backup_date:6:2}"
            local backup_timestamp=$(date -d "$backup_date_formatted" +%s 2>/dev/null || echo 0)
            
            if [ "$backup_timestamp" -gt 0 ] && [ "$backup_timestamp" -lt "$thirty_days_ago" ]; then
                echo -e "${YELLOW}Suppression de la sauvegarde: $(basename "$dir")${NC}"
                rm -rf "$dir" && ((deleted_count++))
            fi
        fi
    done < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -print0 2>/dev/null)

    if [ $deleted_count -gt 0 ]; then
        print_success "$deleted_count sauvegarde(s) ancienne(s) supprimée(s)"
    else
        print_info "Aucune sauvegarde ancienne à supprimer"
    fi
}

delete_all_backups() {
    print_section "${EMOJI_DELETE} Suppression de toutes les sauvegardes"
    
    local backup_count=$(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d ! -path "$BACKUP_BASE_DIR" 2>/dev/null | wc -l)
    
    if [ "$backup_count" -eq 0 ]; then
        print_info "Aucune sauvegarde à supprimer"
        return
    fi
    
    echo -ne "${RED}${BOLD}Êtes-vous sûr de vouloir supprimer TOUTES les sauvegardes ($backup_count) ? [y/N]: ${NC}"
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -ne "${RED}${BOLD}ATTENTION: Cette action est irréversible! Tapez 'SUPPRIMER' pour confirmer: ${NC}"
        read -r final_confirm
        
        if [ "$final_confirm" = "SUPPRIMER" ]; then
            find "$BACKUP_BASE_DIR" -maxdepth 1 -type d ! -path "$BACKUP_BASE_DIR" -exec rm -rf {} \; && \
            print_success "Toutes les sauvegardes ont été supprimées" || \
            print_error "Échec de la suppression des sauvegardes"
        else
            print_info "Suppression annulée"
        fi
    else
        print_info "Suppression annulée"
    fi
}

# =====================================
# FONCTIONS DE VÉRIFICATION
# =====================================

check_requirements() {
    print_section "${EMOJI_CHECK} Vérification des prérequis système"
    
    local missing=()
    local to_install=()
    
    # Vérifier les outils de base
    declare -a required_tools=("curl" "wget" "git" "figlet")
    
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
        local deb_count=$(dpkg --get-selections | grep -c install)
        echo "Total: $deb_count packages installés"
        dpkg --get-selections | head -n 10
        echo "... (plus dans le rapport complet)"
    else
        print_warning "dpkg non disponible"
    fi
    
    print_info "\n${EMOJI_FLATPAK} Applications Flatpak:"
    if command_exists flatpak; then
        local flatpak_count=$(flatpak list --app 2>/dev/null | wc -l)
        echo "Total: $flatpak_count applications Flatpak installées"
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
    
    # Vérification spéciale pour Open WebUI
    print_info "\n${EMOJI_INFO} Open WebUI:"
    if command_exists docker && docker ps | grep -q "open-webui"; then
        echo -e "${GREEN}${EMOJI_OK} Open WebUI (conteneur actif)${NC}"
        local port=$(docker ps | grep "open-webui" | sed -n 's/.*:\([0-9]*\)->.*/\1/p' | head -n1)
        if [ -n "$port" ]; then
            echo -e "   ${BLUE}Accessible sur: http://localhost:$port${NC}"
        else
            echo -e "   ${BLUE}Accessible sur: http://localhost:8080${NC}"
        fi
    else
        echo -e "${RED}${EMOJI_ERROR} Open WebUI (conteneur non actif)${NC}"
    fi
    
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

backup_deb_packages() {
    print_section "${EMOJI_DEB} Sauvegarde des packages DEB"
    
    if command_exists dpkg; then
        dpkg --get-selections > "$CURRENT_BACKUP/deb-packages.list" && \
        print_success "Liste des packages DEB sauvegardée" || \
        print_warning "Impossible de sauvegarder la liste des packages DEB"
    else
        print_warning "dpkg non disponible"
    fi
}

backup_flatpak_apps() {
    print_section "${EMOJI_FLATPAK} Sauvegarde des applications Flatpak"
    
    if command_exists flatpak; then
        flatpak list --app --columns=application > "$CURRENT_BACKUP/flatpak-apps.list" && \
        print_success "Liste des applications Flatpak sauvegardée" || \
        print_warning "Impossible de sauvegarder la liste des applications Flatpak"
    else
        print_warning "Flatpak non installé"
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

restore_deb_packages() {
    print_section "${EMOJI_DEB} Restauration des packages DEB"
    
    if [ -f "$CURRENT_BACKUP/deb-packages.list" ] && command_exists dpkg && command_exists apt; then
        echo -ne "${YELLOW}Voulez-vous restaurer les packages DEB ? [y/N]: ${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_info "Installation des packages DEB manquants..."
            sudo apt update
            while read -r package status; do
                if [ "$status" = "install" ] && ! dpkg -l | grep -q "^ii  $package "; then
                    sudo apt install -y "$package" || print_warning "Impossible d'installer: $package"
                fi
            done < "$CURRENT_BACKUP/deb-packages.list"
            print_success "Packages DEB restaurés"
        fi
    else
        print_warning "Aucune liste de packages DEB à restaurer"
    fi
}

restore_flatpak_apps() {
    print_section "${EMOJI_FLATPAK} Restauration des applications Flatpak"
    
    if [ -f "$CURRENT_BACKUP/flatpak-apps.list" ] && command_exists flatpak; then
        echo -ne "${YELLOW}Voulez-vous restaurer les applications Flatpak ? [y/N]: ${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_info "Installation des applications Flatpak manquantes..."
            while read -r app; do
                if [ -n "$app" ] && ! flatpak list | grep -q "$app"; then
                    flatpak install -y flathub "$app" || print_warning "Impossible d'installer: $app"
                fi
            done < "$CURRENT_BACKUP/flatpak-apps.list"
            print_success "Applications Flatpak restaurées"
        fi
    else
        print_warning "Aucune liste d'applications Flatpak à restaurer"
    fi
}

# =====================================
# APPLICATIONS TIERCES
# =====================================

install_outlook() {
    print_info "Installation d'Outlook for Linux..."
    
    # Téléchargement et installation du package Outlook
    if command_exists apt; then
        mkdir -p ~/Downloads
        wget -O ~/Downloads/outlook-for-linux_1.3.13_amd64.deb "https://github.com/mahmoudbahaa/outlook-for-linux/releases/download/v1.3.13-outlook/outlook-for-linux_1.3.13_amd64.deb" || {
            print_error "Échec du téléchargement d'Outlook"
            return 1
        }
        sudo apt install -y ~/Downloads/outlook-for-linux_1.3.13_amd64.deb && {
            rm ~/Downloads/outlook-for-linux_1.3.13_amd64.deb
            print_success "Outlook for Linux installé avec succès"
        } || {
            print_error "Échec de l'installation d'Outlook"
        }
    else
        print_error "Installation d'Outlook non supportée sur ce système"
    fi
}

install_teams() {
    print_info "Installation de Teams for Linux..."
    
    # Installation de Teams for Linux
    if command_exists apt; then
        mkdir -p ~/Downloads
        wget -O ~/Downloads/teams-for-linux_2.1.3_amd64.deb "https://github.com/IsmaelMartinez/teams-for-linux/releases/download/v2.1.3/teams-for-linux_2.1.3_amd64.deb" || {
            print_error "Échec du téléchargement de Teams"
            return 1
        }
        sudo apt install -y ~/Downloads/teams-for-linux_2.1.3_amd64.deb && {
            rm ~/Downloads/teams-for-linux_2.1.3_amd64.deb
            print_success "Teams for Linux installé avec succès"
        } || {
            print_error "Échec de l'installation de Teams"
        }
    else
        print_error "Installation de Teams non supportée sur ce système"
    fi
}

install_openfortigui() {
    print_info "Installation d'OpenFortiGUI..."
    
    # Téléchargement et installation du package OpenFortiGUI
    if command_exists apt; then
        mkdir -p ~/Downloads
        wget -O ~/Downloads/openfortigui_0.9.10-1_amd64_noble.deb "https://apt.iteas.at/iteas/pool/main/o/openfortigui/openfortigui_0.9.10-1_amd64_noble.deb" || {
            print_error "Échec du téléchargement d'OpenFortiGUI"
            return 1
        }
        sudo apt install -y ~/Downloads/openfortigui_0.9.10-1_amd64_noble.deb && {
            rm ~/Downloads/openfortigui_0.9.10-1_amd64_noble.deb
            print_success "OpenFortiGUI installé avec succès"
        } || {
            print_error "Échec de l'installation d'OpenFortiGUI"
        }
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
        print_header "${EMOJI_APPS} Menu Applications Tierces"
        echo -e "${CYAN} 1. ${EMOJI_APPS} Installer Outlook for Linux"
        echo -e "${CYAN} 2. ${EMOJI_APPS} Installer Teams for Linux"
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
        print_header "${EMOJI_BACKUP} Menu de Sauvegarde"
        echo -e "${CYAN} 1. ${EMOJI_BACKUP} Nouvelle sauvegarde complète"
        echo -e "${CYAN} 2. ${EMOJI_BRAVE} Sauvegarder Brave Browser"
        echo -e "${CYAN} 3. ${EMOJI_BOTTLES} Sauvegarder Bottles"
        echo -e "${CYAN} 4. ${EMOJI_STARTUP} Sauvegarder les applications de démarrage"
        echo -e "${CYAN} 5. ${EMOJI_OLLAMA} Sauvegarder Ollama"
        echo -e "${CYAN} 6. ${EMOJI_DEB} Sauvegarder les packages DEB"
        echo -e "${CYAN} 7. ${EMOJI_FLATPAK} Sauvegarder les applications Flatpak"
        echo -e "${CYAN} 8. ${EMOJI_INFO} Retour au menu principal"
        echo -ne "${YELLOW}${BOLD}Choisissez une option [1-8]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                create_backup_dir
                backup_brave
                backup_bottles
                backup_startup_apps
                backup_ollama
                backup_deb_packages
                backup_flatpak_apps
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
            6) 
                create_backup_dir
                backup_deb_packages
                ;;
            7) 
                create_backup_dir
                backup_flatpak_apps
                ;;
            8) return ;;
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
        print_header "${EMOJI_RESTORE} Menu de Restauration"
        
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
            echo -e "${CYAN} 6. ${EMOJI_DEB} Restaurer les packages DEB"
            echo -e "${CYAN} 7. ${EMOJI_FLATPAK} Restaurer les applications Flatpak"
            echo -e "${CYAN} 8. ${EMOJI_INFO} Changer de sauvegarde"
            echo -e "${CYAN} 9. ${EMOJI_INFO} Retour au menu principal"
            echo -ne "${YELLOW}${BOLD}Choisissez une option [1-9]: ${NC}"
            read -r choice
            
            case $choice in
                1)
                    restore_brave
                    restore_bottles
                    restore_startup_apps
                    restore_ollama
                    restore_deb_packages
                    restore_flatpak_apps
                    print_success "Restauration complète terminée!"
                    ;;
                2) restore_brave ;;
                3) restore_bottles ;;
                4) restore_startup_apps ;;
                5) restore_ollama ;;
                6) restore_deb_packages ;;
                7) restore_flatpak_apps ;;
                8) break ;;
                9) return ;;
                *) print_error "Option invalide" ;;
            esac
            
            echo -ne "\n${YELLOW}Appuyez sur une touche pour continuer...${NC}"
            read -n 1 -s -r
        done
    done
}

# =====================================
# MENU DE GESTION DES SAUVEGARDES
# =====================================

manage_backups_menu() {
    while true; do
        clear
        print_header "${EMOJI_LIST} Menu de Gestion des Sauvegardes"
        echo -e "${CYAN} 1. ${EMOJI_LIST} Lister les sauvegardes"
        echo -e "${CYAN} 2. ${EMOJI_DELETE} Supprimer des sauvegardes"
        echo -e "${CYAN} 3. ${EMOJI_INFO} Informations sur l'espace disque"
        echo -e "${CYAN} 4. ${EMOJI_INFO} Retour au menu principal"
        echo -ne "${YELLOW}${BOLD}Choisissez une option [1-4]: ${NC}"
        read -r choice
        
        case $choice in
            1) 
                list_backups
                ;;
            2) 
                delete_backups
                ;;
            3)
                print_section "${EMOJI_INFO} Informations sur l'espace disque"
                if [ -d "$BACKUP_BASE_DIR" ]; then
                    echo -e "${BLUE}Répertoire de sauvegarde:${NC} $BACKUP_BASE_DIR"
                    local total_size=$(du -sh "$BACKUP_BASE_DIR" 2>/dev/null | cut -f1)
                    echo -e "${BLUE}Espace total utilisé:${NC} $total_size"
                    
                    local available_space=$(df -h "$HOME" | awk 'NR==2{print $4}')
                    echo -e "${BLUE}Espace disponible sur $HOME:${NC} $available_space"
                else
                    print_warning "Aucun répertoire de sauvegarde trouvé"
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
# MENU DE VÉRIFICATIONS
# =====================================

verify_flatpak_repo() {
    print_section "${EMOJI_FLATPAK} Vérification du dépôt Flatpak"
    
    if ! command_exists flatpak; then
        print_warning "Flatpak n'est pas installé"
        echo -ne "${YELLOW}Voulez-vous installer Flatpak ? [y/N]: ${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            if command_exists apt; then
                sudo apt update && sudo apt install -y flatpak
            elif command_exists dnf; then
                sudo dnf install -y flatpak
            elif command_exists pacman; then
                sudo pacman -S --noconfirm flatpak
            fi
        fi
    fi
    
    if command_exists flatpak; then
        if flatpak remotes | grep -q flathub; then
            print_success "Dépôt Flathub déjà configuré"
        else
            print_warning "Dépôt Flathub non configuré"
            flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
            print_success "Dépôt Flathub ajouté avec succès" || \
            print_error "Échec de l'ajout du dépôt Flathub"
        fi
    fi
}

verify_startup_apps() {
    print_section "${EMOJI_STARTUP} Vérification des applications de démarrage"
    
    if [ -d "$HOME/.config/autostart" ]; then
        local startup_count=$(ls -1 "$HOME/.config/autostart"/*.desktop 2>/dev/null | wc -l)
        if [ "$startup_count" -gt 0 ]; then
            print_success "$startup_count application(s) de démarrage configurée(s)"
            echo -e "${BLUE}Applications de démarrage:${NC}"
            for file in "$HOME/.config/autostart"/*.desktop; do
                if [ -f "$file" ]; then
                    local app_name=$(grep "^Name=" "$file" | cut -d= -f2)
                    echo "  - ${app_name:-$(basename "$file" .desktop)}"
                fi
            done
        else
            print_warning "Aucune application de démarrage configurée"
        fi
    else
        print_warning "Répertoire des applications de démarrage non trouvé"
    fi
}

verify_ollama_and_webui() {
    print_section "${EMOJI_OLLAMA} Vérification d'Ollama et Open WebUI"
    
    # Vérification d'Ollama
    if command_exists ollama; then
        print_success "Ollama installé"
        
        # Vérifier si le service fonctionne
        if systemctl is-active --quiet ollama 2>/dev/null || pgrep -x ollama >/dev/null; then
            print_success "Service Ollama actif"
            
            # Tester la connexion
            if ollama list >/dev/null 2>&1; then
                local model_count=$(ollama list 2>/dev/null | tail -n +2 | wc -l)
                print_success "$model_count modèle(s) disponible(s)"
            else
                print_warning "Ollama ne répond pas correctement"
            fi
        else
            print_warning "Service Ollama inactif"
        fi
    else
        print_error "Ollama non installé"
    fi
    
    # Vérification d'Open WebUI
    if command_exists docker; then
        if docker ps | grep -q "open-webui"; then
            print_success "Open WebUI (conteneur actif)"
            
            # Récupérer le port
            local port_mapping=$(docker ps | grep "open-webui" | grep -o '0.0.0.0:[0-9]*->8080' | cut -d: -f2 | cut -d- -f1)
            if [ -n "$port_mapping" ]; then
                print_info "Interface accessible sur: http://localhost:$port_mapping"
            else
                # Vérifier si c'est en mode host
                if docker ps | grep "open-webui" | grep -q "host"; then
                    print_info "Interface accessible sur: http://localhost:8080"
                else
                    print_warning "Port non déterminé, vérifiez la configuration"
                fi
            fi
        else
            print_warning "Open WebUI (conteneur inactif)"
            if docker ps -a | grep -q "open-webui"; then
                print_info "Conteneur Open WebUI existe mais n'est pas démarré"
            else
                print_warning "Conteneur Open WebUI non trouvé"
            fi
        fi
    else
        print_error "Docker non installé - nécessaire pour Open WebUI"
    fi
}

verification_menu() {
    while true; do
        clear
        print_header "${EMOJI_CONFIG} Menu de Vérifications"
        echo -e "${CYAN} 1. ${EMOJI_CONFIG} Vérifier les prérequis système"
        echo -e "${CYAN} 2. ${EMOJI_FLATPAK} Vérifier le dépôt Flatpak"
        echo -e "${CYAN} 3. ${EMOJI_STARTUP} Vérifier les applications de démarrage"
        echo -e "${CYAN} 4. ${EMOJI_OLLAMA} Vérifier Ollama et Open WebUI"
        echo -e "${CYAN} 5. ${EMOJI_INFO} Retour au menu principal"
        echo -ne "${YELLOW}${BOLD}Choisissez une option [1-5]: ${NC}"
        read -r choice
        
        case $choice in
            1) check_requirements ;;
            2) verify_flatpak_repo ;;
            3) verify_startup_apps ;;
            4) verify_ollama_and_webui ;;
            5) return ;;
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
        
        # Affichage du titre avec figlet si disponible
        if command_exists figlet; then
            echo -e "${BLUE}${BOLD}"
            figlet -f small "GAG Pro 4.0"
            echo -e "${NC}"
        else
            echo -e "${BLUE}${BOLD}"
            echo "   ____       _       ____  "
            echo "  / ___|     / \\     / ___| "
            echo " | |  _     / _ \\   | |  _  "
            echo " | |_| |   / ___ \\  | |_| | "
            echo "  \\____|  /_/   \\_\\  \\____| "
            echo -e "${NC}"
        fi
        
        echo -e "${BLUE}${BOLD} G A G (Gestionnaire d'Applications GNOME) - Version Pro 4.0 ${NC}"
        echo -e "${BLUE}${BOLD}=============================================================${NC}"
        echo -e "${CYAN} 1. ${EMOJI_BACKUP} Sauvegarde"
        echo -e "${CYAN} 2. ${EMOJI_RESTORE} Restauration"
        echo -e "${CYAN} 3. ${EMOJI_DELETE} Gérer les sauvegardes"
        echo -e "${CYAN} 4. ${EMOJI_APPS} Installer des applications tierces"
        echo -e "${CYAN} 5. ${EMOJI_CONFIG} Menu de vérifications"
        echo -e "${CYAN} 6. ${EMOJI_CHECK} Vérifier les applications installées"
        echo -e "${CYAN} 7. ${EMOJI_INFO} Quitter"
        echo -ne "${YELLOW}${BOLD}Choisissez une option [1-7]: ${NC}"
        read -r choice

        case $choice in
            1) backup_menu ;;
            2) restore_menu ;;
            3) manage_backups_menu ;;
            4) install_third_party ;;
            5) verification_menu ;;
            6) check_installed_apps ;;
            7)
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
