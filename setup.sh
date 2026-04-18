#!/bin/bash

# =============================================================================
#  SERVER SETUP ASSISTANT - UBUNTU 24.04 (Optimized for Minimized & TUI)
# =============================================================================

# --- Configuración Inicial ---
LOG_FILE="/var/log/server_setup.log"
exec 3>&1 

# Comprobar root (Antes de cualquier instalación)
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Este script requiere permisos de superusuario."
  echo "Ejecuta: sudo $0"
  exit 1
fi

# Instalar Dependencias Críticas (incluyendo Gum)
if ! command -v gum &> /dev/null || ! command -v gpg &> /dev/null; then
    echo "Instalando dependencias base (gum, gnupg)..."
    apt update && apt install -y curl gnupg
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | tee /etc/apt/sources.list.d/charm.list
    apt update && apt install -y gum
fi

# Detectar usuario real (incluso tras sudo)
REAL_USER=${SUDO_USER:-$USER}
if [ "$REAL_USER" == "root" ]; then
    USER_HOME="/root"
else
    USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
fi

# Función para esperar si APT está bloqueado
wait_for_apt() {
    while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
        sleep 2
    done
}

# --- Pregunta Tipo de Máquina ---
gum style --foreground 212 --border double --margin "1 2" --padding "1 2" "TIPO DE SISTEMA"
MACHINE_TYPE=$(gum choose "VPS" "FISICO")

if [ -z "$MACHINE_TYPE" ]; then exit 0; fi

# --- Menú de Selección ---
show_menu() {
    gum style --foreground 212 --border double --margin "1 2" --padding "1 2" "SERVER SETUP - UBUNTU 24.04 NOBLE"
    gum choose --no-limit --selected "CORE,UTILS,HOSTNAME,DOCKER,ZSH,LANGS,LAZY,NEOVIM" \
    "CORE" "UTILS" "HOSTNAME" "DOCKER" "ZSH" "LANGS" "LAZY" "NEOVIM" "OPENCODE" "ZEROTIER"
}

CHOICES=$(show_menu)
if [ -z "$CHOICES" ]; then exit 0; fi

TOTAL_TASKS=$(echo $CHOICES | wc -w)
CURRENT_TASK=0

# Función auxiliar para logging y progreso
run_step() {
    local TEXT="$1"
    local CMD="$2"
    CURRENT_TASK=$((CURRENT_TASK + 1))

    echo ">>> INICIANDO: $TEXT" >> $LOG_FILE
    wait_for_apt
    gum spin --spinner dot --title "$TEXT" -- bash -c "$CMD >> $LOG_FILE 2>&1"
}

# Inicio de instalación
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

    # --- 6. LAZY TOOLS ---
    if [[ $CHOICES == *"LAZY"* ]]; then
        run_step "Instalando Lazygit y Lazydocker..." '
            LG_VER=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po "\"tag_name\": \"v\K[^\"]*")
            curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LG_VER}_Linux_x86_64.tar.gz"
            tar xf lazygit.tar.gz lazygit
            install lazygit /usr/local/bin
            rm lazygit.tar.gz lazygit
            curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
        '
    fi

    # --- 7. OPENCODE ---
    if [[ $CHOICES == *"OPENCODE"* ]]; then
        run_step "Instalando OpenCode CLI..." '
            sudo -u '$REAL_USER' bash -c "curl -sL https://raw.githubusercontent.com/opencode/install/main/install.sh | bash" || true
        '
    fi

    # --- 8. NEOVIM ---
    if [[ $CHOICES == *"NEOVIM"* ]]; then
        run_step "Instalando Neovim (PPA)..." '
            add-apt-repository ppa:neovim-ppa/stable -y
            apt update
            apt install -y neovim
        '
    fi

    # --- 9. ZEROTIER ---
    if [[ $CHOICES == *"ZEROTIER"* ]]; then
        run_step "Instalando ZeroTier One..." '
            curl -s https://install.zerotier.com | bash
        '
    fi

    # --- 10. ZSH & CONFIG PERSONALIZADA ---
    if [[ $CHOICES == *"ZSH"* ]]; then
        run_step "Configurando Zsh (Tu Stack Personalizado)..." '
            apt install -y zsh fontconfig unzip
            
            # 1. Instalar Oh My Zsh
            if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
                sudo -u '$REAL_USER' sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
            fi
            
            # 2. Plugins externos
            ZSH_CUSTOM="$USER_HOME/.oh-my-zsh/custom"
            if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
                sudo -u '$REAL_USER' git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
            fi
            if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
                sudo -u '$REAL_USER' git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
            fi

            # 3. FZF (Instalación manual desde GIT para tener los bindings .fzf.zsh)
            if [ ! -d "$USER_HOME/.fzf" ]; then
                sudo -u '$REAL_USER' git clone --depth 1 https://github.com/junegunn/fzf.git $USER_HOME/.fzf
                sudo -u '$REAL_USER' $USER_HOME/.fzf/install --all --no-bash --no-fish
            fi

            # 4. Oh My Posh & Temas (Descarga local para evitar error de red en login)
            curl -s https://ohmyposh.dev/install.sh | bash -s -- -d /usr/local/bin
            sudo -u '$REAL_USER' mkdir -p $USER_HOME/.poshthemes
            sudo -u '$REAL_USER' wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip -O $USER_HOME/.poshthemes/themes.zip
            sudo -u '$REAL_USER' unzip -o $USER_HOME/.poshthemes/themes.zip -d $USER_HOME/.poshthemes
            sudo -u '$REAL_USER' chmod u+rw $USER_HOME/.poshthemes/*.json
            rm $USER_HOME/.poshthemes/themes.zip
            
            # 5. TU .zshrc EXACTO (Escapamos las variables internas con backslash)
            cat <<EOF > $USER_HOME/.zshrc
# =============================================================================
#                ZSHRC PARA VPS & SERVERS (Ubuntu 24.04)
# =============================================================================

# --- PATH Y BINARIOS --------------------------------------------------------
typeset -U path
path=(
  \$HOME/.local/bin
  \$HOME/bin
  \$HOME/.cargo/bin
  \$HOME/.opencode/bin
  \$path
)
export PATH

# --- Oh My Zsh -------------------------------------------------------------
export ZSH="\$HOME/.oh-my-zsh"

plugins=(
  git
  docker
  docker-compose
  zsh-autosuggestions
  zsh-syntax-highlighting
  colorize
  fzf
)

source \$ZSH/oh-my-zsh.sh

# --- Oh My Posh Prompt ------------------------------------------------------
# Tema AMRO descargado localmente
eval "\$(oh-my-posh init zsh --config \$HOME/.poshthemes/amro.omp.json)"

# --- ALIASES DE SISTEMA (Acceso rápido) -------------------------------------
alias reboot="sudo reboot"
alias shutdown="sudo shutdown -h now"
alias cls="clear"

# --- DOCKER & PORTAINER -----------------------------------------------------
alias d="docker"
alias dc="docker-compose"
alias dps="docker ps -a"
alias dex="docker exec -it"
alias dlog="docker logs -f"
alias dlsx="docker ps --format \"table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.Networks}}\""

# --- HERRAMIENTAS TUI -------------------------------------------------------
alias ld="lazydocker"             
alias lg="lazygit"               
alias btop="btop"                 
alias nv="nvim"                   
alias v="nano"                    

# --- DESARROLLO Y NAVEGACIÓN ------------------------------------------------
alias ll="ls -alF"
alias la="ls -A"
alias l="ls -CF"
alias gs="git status"
alias gp="git push"
alias gl="git pull"

# --- FZF (Buscador Inteligente) ---------------------------------------------
export FZF_DEFAULT_COMMAND="find . -maxdepth 5 -not -path \"*/.*\" -not -path \"*node_modules*\" -not -path \"*target*\" -type f"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# --- HISTORIAL --------------------------------------------------------------
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_FIND_NO_DUPS

# --- FINAL --------------------------------------------------
echo "🚀 Servidor \$(hostname), listo para trabajar ✅"
export PATH=/home/$USER/.opencode/bin:\$PATH
EOF
            chown '$REAL_USER:$REAL_USER' $USER_HOME/.zshrc
            chsh -s $(which zsh) '$REAL_USER'
        '
    fi

    sleep 1 
}

# --- Reporte Final ---
IP_PUB=$(curl -s --connect-timeout 3 https://ifconfig.me || echo "No Detectada")
IFACE_FINAL=$(ip route | grep default | awk '{print $5}' | head -n1)
MAC_FINAL=$(cat /sys/class/net/$IFACE_FINAL/address 2>/dev/null || echo "Desconocida")
HOSTNAME_FINAL=$(hostname)

gum style \
	--foreground 212 --border-foreground 212 --border double \
	--align center --width 50 --margin "1 2" --padding "2 4" \
	"🚀 CONFIGURACIÓN COMPLETADA" "" \
	"Perfil del Servidor:" \
	"------------------------" \
	"Hostname:  $HOSTNAME_FINAL" \
	"IP Pública: $IP_PUB" \
	"MAC Addr:   $MAC_FINAL" \
	"Usuario:    $REAL_USER" \
	"" \
	"Se RECOMIENDA REINICIAR el sistema."

if gum confirm "¿Deseas REINICIAR el servidor ahora?"; then
    reboot
fi
