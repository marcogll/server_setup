# 🚀 Server Setup Assistant (Ubuntu 24.04)

Este script automatiza la configuración de servidores Ubuntu 24.04 (Standard o Minimized), transformando una instalación limpia en un entorno de producción y desarrollo potente con Zsh, Docker, Portainer y herramientas TUI.

## ✨ Características Principales

- **🖥️ Selección de Entorno:** Optimización para VPS o Servidor Físico (WOL).
- **🛠️ Core Stack:** Full Upgrade, Build-Essentials, Curl, Wget, Unzip.
- **🐳 Docker Ready:** Docker Engine + Compose + **Portainer** auto-desplegado.
- **🐚 Zsh Ultimate:** Oh My Zsh + Plugins + FZF + **Oh My Posh** (Tema Amro).
- **📦 Dev Tools:** Node.js LTS, Python3, Pipx, UV (Fast Python Manager).
- **⚡ TUI Power:** Neovim, Lazygit, Lazydocker y Btop.

## 📥 Instalación Rápida (One-Liner)

Copia y pega el siguiente comando en tu terminal. Este comando instala las dependencias necesarias (curl, whiptail, git) y ejecuta el asistente automáticamente:

```bash
sudo apt update && sudo apt install -y curl whiptail unzip git && \
curl -fsSL https://raw.githubusercontent.com/marcogll/server_setup/refs/heads/main/setup.sh -o setup.sh && \
chmod +x setup.sh && sudo ./setup.sh
