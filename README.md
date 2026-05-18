<p align="center">
  <img src="https://raw.githubusercontent.com/marcogll/mg_data_storage/refs/heads/main/soul23/logo/soul23_logo.svg" width="110" alt="Soul23">
</p>

<h1 align="center">Server Setup Assistant</h1>

<p align="center">
  Asistente automatizado para la configuración de servidores Ubuntu 24.04 🚀
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu_24.04-3a3a3a?style=flat-square&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04">
  <img src="https://img.shields.io/badge/Docker-3a3a3a?style=flat-square&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/Zsh-3a3a3a?style=flat-square&logo=zsh&logoColor=white" alt="Zsh">
  <img src="https://img.shields.io/badge/Homebrew-3a3a3a?style=flat-square&logo=homebrew&logoColor=white" alt="Homebrew">
  <img src="https://img.shields.io/badge/Catppuccin-3a3a3a?style=flat-square&logo=catppuccin&logoColor=white" alt="Catppuccin">
</p>

---

Este script automatiza la configuración de servidores Ubuntu 24.04 (Standard o Minimized), transformando una instalación limpia en un entorno de producción y desarrollo potente con herramientas modernas.

## ✨ Características Principales

- **🎨 Interfaz TUI Mejorada:** Impulsada por `gum` de Charm.sh con el tema **Catppuccin Frappe**.
- **📊 Progreso Visible:** Barra de progreso en tiempo real con porcentaje y contador de pasos.
- **📋 Resumen Pre-Instalación:** Muestra todos los componentes seleccionados antes de empezar.
- **⚡ INSTALL ALL:** Opción para seleccionar e instalar todo con un solo clic.
- **🛡️ Manejo de Errores:** Captura y muestra errores detallados para cada paso.
- **✅ Confirmación:** Pide confirmación antes de iniciar la instalación.
- **🖥️ Selección de Entorno:** Optimización para VPS o Servidor Físico (WOL).
- **🛠️ Core Stack:** Full Upgrade, Build-Essentials, Curl, Wget, GPG, Unzip.
- **🐳 Docker Ready:** Docker Engine + Compose + **Portainer** auto-desplegado.
- **🐚 Zsh Ultimate:** Oh My Zsh + Plugins + FZF + **Oh My Posh** (Tema Amro) + **Venv & Server Utils**.
- **📦 Dev Tools:** Homebrew (Linuxbrew), Node.js LTS, PNPM, Zoxide, Python3, Pipx, UV.
- **🌐 Network:** Soporte opcional para **ZeroTier One** y **Tailscale**.
- **⚡ TUI Power:** Neovim, Lazygit, Lazydocker y Btop.

## 📥 Instalación Rápida (One-Liner)

Copia y pega el siguiente comando en tu terminal. Este comando instala las dependencias necesarias y ejecuta el asistente automáticamente:

```bash
sudo apt update && sudo apt install -y curl gpg whiptail unzip git && \
curl -fsSL https://raw.githubusercontent.com/marcogll/server_setup/refs/heads/main/setup.sh -o setup.sh && \
chmod +x setup.sh && sudo ./setup.sh
```

## 🖥️ Flujo de Instalación

1. **Selecciona el tipo de entorno:** VPS o Servidor Físico
2. **Elige los componentes:** Usa Espacio para marcar/desmarcar, Enter para confirmar
   - Selecciona **INSTALL ALL** para instalar todo automáticamente
3. **Revisa el resumen:** Verifica qué se va a instalar
4. **Confirma:** Presiona `Y` para iniciar o `N` para cancelar
5. **Observa el progreso:** Barra de avance con porcentaje en tiempo real
