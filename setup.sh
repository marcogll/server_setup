#!/bin/bash

# =============================================================================
#  SERVER SETUP ASSISTANT - UBUNTU 24.04 (Optimized for Minimized & TUI)
# =============================================================================

# --- Catppuccin Frappe Colors ---
export FR_ROSEWATER="#f2d5cf"
export FR_FLAMINGO="#eebebe"
export FR_PINK="#f4b8e4"
export FR_MAUVE="#ca9ee6"
export FR_RED="#e78284"
export FR_MAROON="#ea999c"
export FR_PEACH="#ef9f76"
export FR_YELLOW="#e5c890"
export FR_GREEN="#a6d189"
export FR_TEAL="#81c8be"
export FR_SKY="#99d1db"
export FR_SAPPHIRE="#85c1dc"
export FR_BLUE="#8caaee"
export FR_LAVENDER="#babbf1"
export FR_TEXT="#c6d0f5"
export FR_SUBTEXT1="#b5bfe2"
export FR_SUBTEXT0="#a5adce"
export FR_OVERLAY2="#949cbb"
export FR_OVERLAY1="#838ba7"
export FR_OVERLAY0="#737994"
export FR_SURFACE2="#626880"
export FR_SURFACE1="#51576d"
export FR_SURFACE0="#414559"
export FR_BASE="#303446"
export FR_MANTLE="#292c3c"
export FR_CRUST="#232634"

# --- Gum Theme Config ---
export GUM_CHOOSE_CURSOR_FOREGROUND="$FR_MAUVE"
export GUM_CHOOSE_HEADER_FOREGROUND="$FR_BLUE"
export GUM_CHOOSE_SELECTED_FOREGROUND="$FR_MAUVE"
export GUM_CONFIRM_PROMPT_FOREGROUND="$FR_YELLOW"
export GUM_CONFIRM_SELECTED_BACKGROUND="$FR_MAUVE"
export GUM_CONFIRM_UNSELECTED_BACKGROUND="$FR_SURFACE0"
export GUM_INPUT_CURSOR_FOREGROUND="$FR_MAUVE"
export GUM_INPUT_PROMPT_FOREGROUND="$FR_SKY"
export GUM_SPIN_SPINNER_FOREGROUND="$FR_MAUVE"
export GUM_SPIN_TITLE_FOREGROUND="$FR_TEXT"

# --- Configuración Inicial ---
export LOG_FILE="/var/log/server_setup.log"
exec 3>&1 

# Comprobar e instalar dependencias críticas (Gum)
bootstrap_dependencies() {
    if ! command -v gum &> /dev/null; then
        echo "Instalando Gum (Charm.sh) para una mejor interfaz..."
        export DEBIAN_FRONTEND=noninteractive
        apt update && apt install -y curl gpg
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
        echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | tee /etc/apt/sources.list.d/charm.list
        apt update && apt install -y gum
    fi
}

# Comprobar root
if [ "$EUID" -ne 0 ]; then
  if command -v gum &> /dev/null; then
    gum style --foreground "$FR_RED" --border double --margin "1 2" --padding "1 2" \
    "Error de Privilegios: Este script requiere permisos de superusuario." "Ejecuta: sudo $0"
  else
    whiptail --title "Error de Privilegios" --msgbox "Este script requiere permisos de superusuario.\nEjecuta: sudo $0" 10 50
  fi
  exit 1
fi

bootstrap_dependencies

# Detectar usuario real (incluso tras sudo)
export REAL_USER=${SUDO_USER:-$USER}
if [ "$REAL_USER" == "root" ]; then
    export USER_HOME="/root"
else
    export USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
fi

# Función para esperar si APT está bloqueado
wait_for_apt() {
    while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
        sleep 2
    done
}

# --- Pregunta Tipo de Máquina ---
echo "Selecciona el tipo de entorno:"
MACHINE_TYPE=$(gum choose "VPS (Servidor Virtual / VM)" "FISICO (Servidor Físico)")

if [[ $MACHINE_TYPE == *"VPS"* ]]; then
    MACHINE_TYPE="VPS"
else
    MACHINE_TYPE="FISICO"
fi

# --- Menú de Selección ---
show_menu() {
    gum choose --no-limit --header "Selecciona los componentes a instalar (Espacio para marcar, Enter para confirmar):" \
    "INSTALL ALL: Instalar Todo" \
    "CORE: Full Upgrade + Build-Essential (Obligatorio)" \
    "UTILS: Utils (Nano, Btop, Git, Curl, Zip, Net-Tools)" \
    "HOSTNAME: Cambiar Hostname del Servidor" \
    "DOCKER: Docker Engine + Compose + Portainer" \
    "ZSH: Zsh + OMZ + Temas + Tu Configuración" \
    "LANGS: Node.js (LTS), Python3, Pipx & UV" \
    "LAZY: Lazygit & Lazydocker (TUI Tools)" \
    "NEOVIM: Neovim (Última Estable PPA)" \
    "OPENCODE: Instalar OpenCode CLI" \
    "BREW: Homebrew (Linuxbrew)" \
    "PNPM: Fast Package Manager" \
    "ZOXIDE: Smart cd command" \
    "ZEROTIER: ZeroTier One VPN" \
    "TAILSCALE: Tailscale VPN"
}

CHOICES_RAW=$(show_menu)
if [ -z "$CHOICES_RAW" ]; then exit 0; fi

# Si seleccionó INSTALL ALL, activar todo
if [[ "$CHOICES_RAW" == *"INSTALL ALL"* ]]; then
    CHOICES="CORE UTILS HOSTNAME DOCKER ZSH LANGS LAZY NEOVIM OPENCODE BREW PNPM ZOXIDE ZEROTIER TAILSCALE"
else
    # Convertir la salida de gum (líneas) a un formato compatible con el script
    CHOICES=""
    [[ "$CHOICES_RAW" == *"CORE"* ]] && CHOICES="$CHOICES CORE"
    [[ "$CHOICES_RAW" == *"UTILS"* ]] && CHOICES="$CHOICES UTILS"
    [[ "$CHOICES_RAW" == *"HOSTNAME"* ]] && CHOICES="$CHOICES HOSTNAME"
    [[ "$CHOICES_RAW" == *"DOCKER"* ]] && CHOICES="$CHOICES DOCKER"
    [[ "$CHOICES_RAW" == *"ZSH"* ]] && CHOICES="$CHOICES ZSH"
    [[ "$CHOICES_RAW" == *"LANGS"* ]] && CHOICES="$CHOICES LANGS"
    [[ "$CHOICES_RAW" == *"LAZY"* ]] && CHOICES="$CHOICES LAZY"
    [[ "$CHOICES_RAW" == *"NEOVIM"* ]] && CHOICES="$CHOICES NEOVIM"
    [[ "$CHOICES_RAW" == *"OPENCODE"* ]] && CHOICES="$CHOICES OPENCODE"
    [[ "$CHOICES_RAW" == *"BREW"* ]] && CHOICES="$CHOICES BREW"
    [[ "$CHOICES_RAW" == *"PNPM"* ]] && CHOICES="$CHOICES PNPM"
    [[ "$CHOICES_RAW" == *"ZOXIDE"* ]] && CHOICES="$CHOICES ZOXIDE"
    [[ "$CHOICES_RAW" == *"ZEROTIER"* ]] && CHOICES="$CHOICES ZEROTIER"
    [[ "$CHOICES_RAW" == *"TAILSCALE"* ]] && CHOICES="$CHOICES TAILSCALE"
fi

# --- Progress and Logging ---
TOTAL_STEPS=0
CURRENT_STEP=0

# Calculate total steps based on choices
calculate_total_steps() {
    TOTAL_STEPS=0
    [[ "$MACHINE_TYPE" == "FISICO" ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    [[ "$CHOICES" == *"CORE"* ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    [[ "$CHOICES" == *"UTILS"* ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    [[ "$CHOICES" == *"HOSTNAME"* ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    [[ "$CHOICES" == *"DOCKER"* ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    [[ "$CHOICES" == *"LANGS"* ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    [[ "$CHOICES" == *"LAZY"* ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    [[ "$CHOICES" == *"OPENCODE"* ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    [[ "$CHOICES" == *"NEOVIM"* ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    [[ "$CHOICES" == *"BREW"* ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    [[ "$CHOICES" == *"PNPM"* ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    [[ "$CHOICES" == *"ZOXIDE"* ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    [[ "$CHOICES" == *"ZEROTIER"* ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    [[ "$CHOICES" == *"TAILSCALE"* ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    [[ "$CHOICES" == *"ZSH"* ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
}

# Progress bar display
show_progress() {
    local current=$1
    local total=$2
    local text="$3"
    local percent=$((current * 100 / total))
    local filled=$((percent / 3))
    local empty=$((33 - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    
    echo ""
    gum style --foreground "$FR_BLUE" --bold "[$bar] $percent% ($current/$total)"
    gum style --foreground "$FR_TEXT" "$text"
    echo ""
}

# Show installation summary before starting
show_install_summary() {
    local items=()
    [[ "$MACHINE_TYPE" == "FISICO" ]] && items+=("Wake-on-LAN")
    [[ "$CHOICES" == *"CORE"* ]] && items+=("CORE: Full Upgrade + Build-Essential")
    [[ "$CHOICES" == *"UTILS"* ]] && items+=("UTILS: CLI Tools")
    [[ "$CHOICES" == *"HOSTNAME"* ]] && items+=("HOSTNAME: Custom Hostname")
    [[ "$CHOICES" == *"DOCKER"* ]] && items+=("DOCKER: Engine + Compose + Portainer")
    [[ "$CHOICES" == *"LANGS"* ]] && items+=("LANGS: Node.js + Python + UV")
    [[ "$CHOICES" == *"BREW"* ]] && items+=("BREW: Homebrew")
    [[ "$CHOICES" == *"LAZY"* ]] && items+=("LAZY: Lazygit + Lazydocker")
    [[ "$CHOICES" == *"OPENCODE"* ]] && items+=("OPENCODE: CLI")
    [[ "$CHOICES" == *"NEOVIM"* ]] && items+=("NEOVIM: Editor")
    [[ "$CHOICES" == *"PNPM"* ]] && items+=("PNPM: Package Manager")
    [[ "$CHOICES" == *"ZOXIDE"* ]] && items+=("ZOXIDE: Smart cd")
    [[ "$CHOICES" == *"ZEROTIER"* ]] && items+=("ZEROTIER: VPN")
    [[ "$CHOICES" == *"TAILSCALE"* ]] && items+=("TAILSCALE: VPN")
    [[ "$CHOICES" == *"ZSH"* ]] && items+=("ZSH: Shell + Dotfiles")
    
    local summary="Tipo: $MACHINE_TYPE | Pasos: $TOTAL_STEPS"
    gum style --foreground "$FR_BLUE" --bold --border rounded --margin "1" --padding "1 2" \
        "Resumen de Instalación" \
        "$summary" \
        "" \
        "${items[@]}"
    echo ""
}

# Function to run step with visible progress and error handling
run_step() {
    local TEXT="$1"
    local CMD="$2"
    CURRENT_STEP=$((CURRENT_STEP + 1))
    
    show_progress $CURRENT_STEP $TOTAL_STEPS "$TEXT"
    
    echo ">>> INICIANDO [$CURRENT_STEP/$TOTAL_STEPS]: $TEXT" >> $LOG_FILE
    echo "Comando: $CMD" >> $LOG_FILE
    wait_for_apt
    
    # Create temp files for output and error capture
    local tmp_output=$(mktemp)
    local tmp_error=$(mktemp)
    
    # Run command and capture both stdout and stderr
    if eval "$CMD" > "$tmp_output" 2>"$tmp_error"; then
        # Success - append to log
        cat "$tmp_output" >> $LOG_FILE
        cat "$tmp_error" >> $LOG_FILE
        echo "✅ Completado: $TEXT" >> $LOG_FILE
        gum style --foreground "$FR_GREEN" "  ✓ $TEXT"
        rm -f "$tmp_output" "$tmp_error"
        return 0
    else
        # Failure - capture error
        local exit_code=$?
        cat "$tmp_output" >> $LOG_FILE
        cat "$tmp_error" >> $LOG_FILE
        echo "❌ ERROR (código $exit_code): $TEXT" >> $LOG_FILE
        
        gum style --foreground "$FR_RED" "  ✗ $TEXT - ERROR"
        
        # Show error details to user
        if [ -s "$tmp_error" ]; then
            echo ""
            gum style --foreground "$FR_RED" --bold "  Error detallado:"
            head -10 "$tmp_error" | while read line; do
                gum style --foreground "$FR_RED" "    $line"
            done
        fi
        
        rm -f "$tmp_output" "$tmp_error"
        return 1
    fi
}

# Calculate total steps before starting
calculate_total_steps

# Show installation summary
show_install_summary

# Confirm before starting
if ! gum confirm "¿Iniciar instalación?"; then
    echo "Instalación cancelada."
    exit 0
fi

# Inicio de instalacion
{
    echo "Iniciando log en $LOG_FILE" > $LOG_FILE
    
    # --- Wake-on-Lan ---
    if [ "$MACHINE_TYPE" == "FISICO" ]; then
        run_step "Configurando Wake-on-Lan..." '
            apt install -y ethtool network-manager
            IFACE_WOL=$(ip route | grep default | awk "{print \$5}" | head -n1)
            if [ ! -z "$IFACE_WOL" ]; then
                ethtool -s $IFACE_WOL wol g
                nmcli c modify "$IFACE_WOL" 802-3-ethernet.wake-on-lan magic 2>/dev/null || true
            fi
        '
    fi

    # --- 1. CORE ---
    if [[ $CHOICES == *"CORE"* ]]; then
        run_step "Actualizando Sistema y Build-Essentials..." '
            export DEBIAN_FRONTEND=noninteractive
            apt update -y
            apt full-upgrade -y
            apt install -y build-essential software-properties-common \
            libssl-dev zlib1g-dev libncurses5-dev libncursesw5-dev \
            libreadline-dev libsqlite3-dev tk-dev libgdbm-dev \
            libc6-dev libbz2-dev libffi-dev lzma-dev liblzma-dev acl
        '
    fi

    # --- 2. UTILS ---
    if [[ $CHOICES == *"UTILS"* ]]; then
        run_step "Instalando Utilidades CLI..." '
            apt install -y nano btop curl wget git unzip p7zip-full jq tldr bat fd-find ripgrep net-tools
            ln -sf /usr/bin/batcat /usr/local/bin/bat
        '
    fi

    # --- 3. HOSTNAME ---
    if [[ $CHOICES == *"HOSTNAME"* ]]; then
        NEW_HN=$(gum input --placeholder "Nuevo Hostname" --value "Server-Ubuntu")
        if [ ! -z "$NEW_HN" ]; then
             run_step "Aplicando Hostname: $NEW_HN" "hostnamectl set-hostname '$NEW_HN' && sed -i \"s/127.0.1.1.*/127.0.1.1 $NEW_HN/\" /etc/hosts"
        fi
    fi

    # --- 4. DOCKER ---
    if [[ $CHOICES == *"DOCKER"* ]]; then
        run_step "Instalando Docker & Portainer..." '
            if ! command -v docker &> /dev/null; then
                curl -fsSL https://get.docker.com | sh
            fi
            usermod -aG docker '$REAL_USER'
            systemctl enable --now docker
            if ! docker ps -a --format "{{.Names}}" | grep -q "^portainer$"; then
                docker volume create portainer_data
                docker run -d -p 9443:9443 --name portainer --restart=always \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -v portainer_data:/data portainer/portainer-ce:latest
            fi
        '
    fi

    # --- 5. LANGS (Node, Python, UV) ---
    if [[ $CHOICES == *"LANGS"* ]]; then
        run_step "Instalando Stack Moderno (Node, Py, UV)..." '
            curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
            apt install -y nodejs python3 python3-pip python3-venv pipx
            sudo -u '$REAL_USER' bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh"
        '
    fi

    # --- 6. BREW ---
    if [[ $CHOICES == *"BREW"* ]]; then
        run_step "Instalando Homebrew (Linuxbrew)..." '
            if ! command -v brew &> /dev/null; then
                mkdir -p /home/linuxbrew/.linuxbrew
                chown '$REAL_USER':'$REAL_USER' /home/linuxbrew/.linuxbrew
                sudo -u '$REAL_USER' NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
        '
    fi

    # --- 7. LAZY TOOLS ---
    if [[ $CHOICES == *"LAZY"* ]]; then
        run_step "Instalando Lazygit y Lazydocker..." '
            if ! command -v brew &> /dev/null; then
                mkdir -p /home/linuxbrew/.linuxbrew
                chown '$REAL_USER':'$REAL_USER' /home/linuxbrew/.linuxbrew
                sudo -u '$REAL_USER' NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
            brew install lazygit lazydocker
        '
    fi

    # --- 8. OPENCODE ---
    if [[ $CHOICES == *"OPENCODE"* ]]; then
        run_step "Instalando OpenCode CLI..." '
            sudo -u '$REAL_USER' bash -c "curl -fsSL https://opencode.ai/install | bash"
        '
    fi

    # --- 9. NEOVIM ---
    if [[ $CHOICES == *"NEOVIM"* ]]; then
        run_step "Instalando Neovim (PPA)..." '
            add-apt-repository ppa:neovim-ppa/stable -y
            apt update
            apt install -y neovim
        '
    fi

    # --- 10. PNPM ---
    if [[ $CHOICES == *"PNPM"* ]]; then
        run_step "Instalando PNPM..." '
            sudo -u '$REAL_USER' bash -c "curl -fsSL https://get.pnpm.io/install.sh | sh -"
        '
    fi

    # --- 11. ZOXIDE ---
    if [[ $CHOICES == *"ZOXIDE"* ]]; then
        run_step "Instalando Zoxide..." '
            sudo -u '$REAL_USER' bash -c "curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh"
        '
    fi

    # --- 12. ZEROTIER ---
    if [[ $CHOICES == *"ZEROTIER"* ]]; then
        run_step "Instalando ZeroTier One..." '
            curl -s https://install.zerotier.com | sudo bash
        '
    fi

    # --- 13. TAILSCALE ---
    if [[ $CHOICES == *"TAILSCALE"* ]]; then
        run_step "Instalando Tailscale..." '
            curl -fsSL https://tailscale.com/install.sh | sh
        '
    fi

    # --- 14. ZSH & CONFIG PERSONALIZADA ---
    if [[ $CHOICES == *"ZSH"* ]]; then
        run_step "Configurando Zsh y dotfiles..." '
            # Instalar Zsh
            apt install -y zsh fontconfig unzip

            # 1. Instalar Oh My Zsh
            if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
                sudo -u "$REAL_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
            fi

            # 2. Plugins externos
            ZSH_CUSTOM="$USER_HOME/.oh-my-zsh/custom"
            if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
                sudo -u "$REAL_USER" git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
            fi
            if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
                sudo -u "$REAL_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
            fi

            # 3. FZF
            if [ ! -d "$USER_HOME/.fzf" ]; then
                sudo -u "$REAL_USER" git clone --depth 1 https://github.com/junegunn/fzf.git "$USER_HOME/.fzf"
                sudo -u "$REAL_USER" "$USER_HOME/.fzf/install" --all --no-bash --no-fish
            fi

            # 4. Oh My Posh
            curl -s https://ohmyposh.dev/install.sh | bash -s -- -d /usr/local/bin
            sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.poshthemes"
            sudo -u "$REAL_USER" wget -q https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip -O "$USER_HOME/.poshthemes/themes.zip"
            sudo -u "$REAL_USER" unzip -o "$USER_HOME/.poshthemes/themes.zip" -d "$USER_HOME/.poshthemes"
            sudo -u "$REAL_USER" chmod u+rw "$USER_HOME/.poshthemes"/*.json
            rm -f "$USER_HOME/.poshthemes/themes.zip"

            # 5. Descargar dotfiles desde el repo
            DOTFILES_BASE="https://raw.githubusercontent.com/marcogll/server_setup/main/dotfiles"
            sudo -u "$REAL_USER" curl -fsSL "$DOTFILES_BASE/.zshrc" -o "$USER_HOME/.zshrc"
            sudo -u "$REAL_USER" curl -fsSL "$DOTFILES_BASE/.zsh_aliases" -o "$USER_HOME/.zsh_aliases"
            sudo -u "$REAL_USER" curl -fsSL "$DOTFILES_BASE/.zsh_functions" -o "$USER_HOME/.zsh_functions"

            # Asegurar permisos
            chown "$REAL_USER:$REAL_USER" "$USER_HOME/.zshrc"
            chown "$REAL_USER:$REAL_USER" "$USER_HOME/.zsh_aliases"
            chown "$REAL_USER:$REAL_USER" "$USER_HOME/.zsh_functions"

            # Cambiar shell por defecto a zsh
            chsh -s $(which zsh) "$REAL_USER"
        '
    fi

    sleep 1 
}

# --- Reporte Final ---
IP_PUB=$(curl -s --connect-timeout 3 https://ifconfig.me || echo "No Detectada")
IFACE_FINAL=$(ip route | grep default | awk '{print $5}' | head -n1)
MAC_FINAL=$(cat /sys/class/net/$IFACE_FINAL/address 2>/dev/null || echo "Desconocida")

gum style --foreground "$FR_GREEN" --border rounded --margin "1 2" --padding "1 2" \
"¡Configuración Completada!" "IP Pública: $IP_PUB" "MAC Address: $MAC_FINAL" "Usuario: $REAL_USER" \
"Se RECOMIENDA REINICIAR para cargar el nuevo Kernel y permisos de grupo."

if gum confirm "¿Deseas REINICIAR el servidor ahora?"; then
    reboot
fi
