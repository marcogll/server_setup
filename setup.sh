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

TOTAL_TASKS=$(echo $CHOICES | wc -w)
CURRENT_TASK=0

# Función auxiliar para logging y progreso
run_step() {
    local TEXT="$1"
    local CMD="$2"
    CURRENT_TASK=$((CURRENT_TASK + 1))

    echo ">>> INICIANDO: $TEXT" >> $LOG_FILE
    wait_for_apt

    gum spin --title "$TEXT ($CURRENT_TASK/$TOTAL_TASKS)" -- bash -c "$CMD" >> $LOG_FILE 2>&1
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

    # --- 9. BREW ---
    if [[ $CHOICES == *"BREW"* ]]; then
        run_step "Instalando Homebrew (Linuxbrew)..." '
            if ! command -v brew &> /dev/null; then
                sudo -u '$REAL_USER' bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" "" --unattended
            fi
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
            curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
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
        # Crear un script temporal para la configuración de ZSH para evitar problemas de comillas anidadas
        ZSH_SCRIPT=$(mktemp)
        cat <<'EOF_ZSH' > "$ZSH_SCRIPT"
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
sudo -u "$REAL_USER" wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip -O "$USER_HOME/.poshthemes/themes.zip"
sudo -u "$REAL_USER" unzip -o "$USER_HOME/.poshthemes/themes.zip" -d "$USER_HOME/.poshthemes"
sudo -u "$REAL_USER" chmod u+rw "$USER_HOME/.poshthemes"/*.json
rm "$USER_HOME/.poshthemes/themes.zip"

# 5. Generar .zshrc
cat <<EOF_ZRC > "$USER_HOME/.zshrc"
# =============================================================================
#                ZSHRC PARA VPS & SERVERS (Ubuntu 24.04)
# =============================================================================

# --- PATH Y BINARIOS --------------------------------------------------------
export PNPM_HOME="\$HOME/.local/share/pnpm"
export PATH="\$PNPM_HOME:\$PATH"

typeset -U path
path=(
  \$HOME/.local/bin
  \$HOME/bin
  /home/linuxbrew/.linuxbrew/bin
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
  sudo
  copypath
  dirhistory
)

source \$ZSH/oh-my-zsh.sh

# --- Oh My Posh Prompt ------------------------------------------------------
eval "\$(oh-my-posh init zsh --config \$HOME/.poshthemes/amro.omp.json)"

# --- TERMINAL ---------------------------------------------------------------
export TERM=xterm-256color
export EDITOR=nvim
export VISUAL=nvim

# --- HISTORIAL --------------------------------------------------------------
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

# --- NAVEGACIÓN -------------------------------------------------------------
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS

# Zoxide
if command -v zoxide &>/dev/null; then
  eval "\$(zoxide init zsh)"
  alias cd="z"
fi

# --- ALIASES DE SISTEMA -----------------------------------------------------
alias reboot="sudo reboot"
alias shutdown="sudo shutdown -h now"
alias cls="clear"
alias reload="source ~/.zshrc && echo '✅ zshrc recargado'"

# --- LISTADO DE ARCHIVOS ----------------------------------------------------
if command -v eza &>/dev/null; then
  alias ll="eza -alF --icons --git --time-style=relative"
  alias la="eza -aF --icons"
  alias l="eza -F --icons"
  alias lt="eza --tree --level=2 --icons"
else
  alias ll="ls -alFh --color=auto"
  alias la="ls -A --color=auto"
  alias l="ls -CF --color=auto"
fi

# --- GIT --------------------------------------------------------------------
alias gs="git status"
alias gp="git push"
alias gl="git pull"
alias gd="git diff"
alias gc="git commit -m"
alias gca="git commit --amend --no-edit"
alias glo="git log --oneline --graph --decorate -20"

# --- DOCKER -----------------------------------------------------------------
alias d="docker"
alias dc="docker compose"
alias dco="docker-compose"
alias dps="docker ps -a"
alias dex="docker exec -it"
alias dlog="docker logs -f"
alias dlogn="docker logs --tail=100 -f"
alias drm="docker rm -f"
alias dstop="docker stop"
alias dpull="docker pull"
alias dimg="docker images"
alias dprune="docker system prune -af --volumes"
alias dnet="docker network ls"
alias dvol="docker volume ls"
alias dls='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'

dsh() {
  local name="\${1:?Uso: dsh <nombre_container>}"
  docker exec -it "\$(docker ps --filter \"name=\$name\" --format '{{.Names}}' | head -1)" \${2:-sh}
}

dlf() {
  local cname
  cname=\$(docker ps --format '{{.Names}}' | fzf --prompt="Container > ")
  [[ -n "\$cname" ]] && docker logs -f "\$cname"
}

# --- HERRAMIENTAS TUI -------------------------------------------------------
alias ld="lazydocker"
alias lg="lazygit"
alias nv="nvim"
alias v="nano"
command -v btop &>/dev/null && alias top="btop"

# --- FZF (Buscador Inteligente) ---------------------------------------------
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git --exclude node_modules --exclude target"
else
  export FZF_DEFAULT_COMMAND="find . -maxdepth 5 -not -path '*/.*' -not -path '*node_modules*' -not -path '*target*' -type f"
fi

export FZF_DEFAULT_OPTS="
  --height=40%
  --layout=reverse
  --border=rounded
  --info=inline
  --preview='cat {}'
  --preview-window=right:50%:wrap
"
export FZF_CTRL_T_COMMAND="\$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="find . -maxdepth 4 -type d -not -path '*/.*'"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# --- UTILIDADES DE RED ------------------------------------------------------
alias ports="ss -tulnp"
alias myip="curl -s ifconfig.me && echo"
alias localip="hostname -I | awk '{print \$1}'"
alias ping="ping -c 5"

portpid() {
  lsof -i ":\${1:?Uso: portpid <puerto>}"
}

# --- SERVIDORES RÁPIDOS -----------------------------------------------------
alias serve="npx serve"
alias pyserve="python3 -m http.server"

# --- MANEJO DE VENV (PYTHON) ------------------------------------------------
venv() {
  local cmd="\${1:?Uso: venv <create|on|off|delete>}"
  local name="\${2:-venv}"

  case "\$cmd" in
    create)
      python3 -m venv "\$name" && echo "✅ Venv '\$name' creado."
      ;;
    on)
      if [ -f "\$name/bin/activate" ]; then
        source "\$name/bin/activate" && echo "🚀 Venv '\$name' activado."
      else
        echo "❌ No se encontró '\$name/bin/activate'."
      fi
      ;;
    off)
      if command -v deactivate &>/dev/null; then
        deactivate && echo "💤 Venv desactivado."
      else
        echo "⚠️ No hay un venv activo."
      fi
      ;;
    delete)
      if [ -d "\$name" ]; then
        rm -rf "\$name" && echo "🗑️ Venv '\$name' eliminado."
      else
        echo "❌ El directorio '\$name' no existe."
      fi
      ;;
    *)
      echo "Uso: venv <create|on|off|delete> [nombre]"
      ;;
  esac
}

# --- UTILIDADES GENERALES ---------------------------------------------------
extract() {
  case "\$1" in
    *.tar.gz|*.tgz) tar xzf "\$1" ;;
    *.tar.bz2)      tar xjf "\$1" ;;
    *.tar.xz)       tar xJf "\$1" ;;
    *.zip)          unzip "\$1" ;;
    *.gz)           gunzip "\$1" ;;
    *.7z)           7z x "\$1" ;;
    *)              echo "No sé cómo extraer '\$1'" ;;
  esac
}

mkcd() { mkdir -p "\$1" && cd "\$1"; }

# --- BANNER DE BIENVENIDA ---------------------------------------------------
echo ""
echo "🚀 \$(hostname) · \$(date '+%a %d %b %Y  %H:%M') · \$(uptime -p)"
echo ""

# --- FINAL --------------------------------------------------
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
EOF_ZRC

chown "$REAL_USER:$REAL_USER" "$USER_HOME/.zshrc"
chsh -s $(which zsh) "$REAL_USER"
EOF_ZSH

        run_step "Configurando Zsh (Tu Stack Personalizado)..." "bash $ZSH_SCRIPT"
        rm "$ZSH_SCRIPT"
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
