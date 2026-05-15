# =============================================================================
#                ZSHRC PARA VPS & SERVERS (Ubuntu 24.04)
# =============================================================================

# --- PATH Y BINARIOS --------------------------------------------------------
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

typeset -U path
path=(
  $HOME/.local/bin
  $HOME/bin
  /home/linuxbrew/.linuxbrew/bin
  $HOME/.cargo/bin
  $HOME/.opencode/bin
  $path
)
export PATH

# --- Oh My Zsh -------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"

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

source $ZSH/oh-my-zsh.sh

# --- Oh My Posh Prompt ------------------------------------------------------
eval "$(oh-my-posh init zsh --config $HOME/.poshthemes/amro.omp.json)"

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
  eval "$(zoxide init zsh)"
  alias cd="z"
fi

# --- CARGAR ALIASES Y FUNCIONES ---------------------------------------------
[ -f ~/.zsh_aliases ] && source ~/.zsh_aliases
[ -f ~/.zsh_functions ] && source ~/.zsh_functions
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# --- BANNER DE BIENVENIDA ---------------------------------------------------
echo ""
echo "🚀 $(hostname) · $(date '+%a %d %b %Y  %H:%M') · $(uptime -p)"
echo ""
