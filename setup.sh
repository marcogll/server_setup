#!/bin/bash

# =============================================================================
#  SERVER SETUP ASSISTANT - UBUNTU 24.04 (Optimized for Minimized & TUI)
# =============================================================================

# --- Configuración Inicial ---
LOG_FILE="/var/log/server_setup.log"
exec 3>&1 

# Comprobar root
if [ "$EUID" -ne 0 ]; then
  whiptail --title "Error de Privilegios" --msgbox "Este script requiere permisos de superusuario.\nEjecuta: sudo $0" 10 50
  exit 1
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
MACHINE_TYPE=$(whiptail --title "Tipo de Sistema" --menu "Selecciona el tipo de entorno:" 12 60 2 \
"VPS" "Servidor Virtual (Cloud / VM)" \
"FISICO" "Servidor Físico (Habilita WOL & Drivers HW)" 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then exit 0; fi 

# --- Menú de Selección ---
show_menu() {
    whiptail --title "Server Setup - Ubuntu 24.04 Noble" --checklist \
    "Usa ESPACIO para seleccionar y ENTER para confirmar:" 22 78 12 \
    "CORE" "Full Upgrade + Build-Essential (Obligatorio)" ON \
    "UTILS" "Utils (Nano, Btop, Git, Curl, Zip, Net-Tools)" ON \
    "HOSTNAME" "Cambiar Hostname del Servidor" ON \
    "DOCKER" "Docker Engine + Compose + Portainer" ON \
    "ZSH" "Zsh + OMZ + Temas + Tu Configuración" ON \
    "LANGS" "Node.js (LTS), Python3, Pipx & UV" ON \
    "LAZY" "Lazygit & Lazydocker (TUI Tools)" ON \
    "NEOVIM" "Neovim (Última Estable PPA)" ON \
    "OPENCODE" "Instalar OpenCode CLI" OFF 3>&1 1>&2 2>&3
}

CHOICES=$(show_menu)
if [ $? -ne 0 ]; then exit 0; fi

TOTAL_TASKS=$(echo $CHOICES | wc -w)
CURRENT_TASK=0

# Función auxiliar para logging y progreso
run_step() {
    local TEXT="$1"
    local CMD="$2"
    CURRENT_TASK=$((CURRENT_TASK + 1))
    PERCENT=$((CURRENT_TASK * 100 / TOTAL_TASKS))
    echo "XXX"
    echo $PERCENT
    echo "$TEXT"
    echo "XXX"
    echo ">>> INICIANDO: $TEXT" >> $LOG_FILE
    wait_for_apt
    eval "$CMD" >> $LOG_FILE 2>&1
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
        echo "XXX"
        echo $PERCENT
        echo "Esperando input de usuario..."
        echo "XXX"
        NEW_HN=$(whiptail --inputbox "Nuevo Hostname:" 8 40 "Server-Ubuntu" 3>&1 1>&2 2>&3)
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

    # --- 9. ZSH & CONFIG PERSONALIZADA ---
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
} | whiptail --title "Instalación Automatizada" --gauge "Preparando sistema..." 10 70 0

# --- Reporte Final ---
IP_PUB=$(curl -s --connect-timeout 3 https://ifconfig.me || echo "No Detectada")
IFACE_FINAL=$(ip route | grep default | awk '{print $5}' | head -n1)
MAC_FINAL=$(cat /sys/class/net/$IFACE_FINAL/address 2>/dev/null || echo "Desconocida")

whiptail --title "¡Configuración Completada!" --msgbox \
"Instalación finalizada.\n\n\
IP Pública: $IP_PUB\n\
MAC Address: $MAC_FINAL\n\
Usuario: $REAL_USER\n\
\n\
Se RECOMIENDA REINICIAR para cargar el nuevo Kernel y permisos de grupo." 14 70

if (whiptail --title "Reiniciar" --yesno "¿Deseas REINICIAR el servidor ahora?" 10 60); then
    reboot
fi
