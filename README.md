# Linux DevTools Installation Script

A comprehensive, automated installation script for setting up a complete development environment on Linux systems. Supports both **Debian-based** (Ubuntu, Debian, Linux Mint, Pop!_OS) and **Arch-based** (Arch Linux, Manjaro, EndeavourOS) distributions.

## 🚀 Features

- **Multi-Distribution Support**: Automatically detects and adapts to Debian or Arch-based systems
- **Comprehensive Tool Coverage**: Installs 50+ essential development tools
- **Smart Installation**: Checks for existing installations to avoid conflicts
- **Installation Summary**: Shows which tools are installed and which will be installed
- **Interactive or Automatic**: Choose between interactive mode with confirmation or automatic installation
- **Color-Coded Logging**: Clear, visual feedback during installation
- **Error Handling**: Robust error handling with proper exit codes
- **Modular Design**: Each tool category has its own installation function
- **Command-line Options**: Support for `-y` flag to skip confirmations

## 📦 What Gets Installed

### Core Utilities
- **File Tools**: curl, wget, unzip, zip, tar, compression utilities
- **Search Tools**: ripgrep, fd, fzf
- **System Monitors**: htop, btop, neofetch
- **File Browsers**: tree, lsd, bat, exa
- **Terminal**: zsh, tmux, screen
- **Build Tools**: gcc, make, cmake
- **Network Tools**: net-tools, dnsutils, traceroute
- **Utilities**: ncdu, tldr, jq, yq

### Version Control
- Git
- GitHub CLI (gh)

### Cloud Platforms
- Azure CLI
- AWS CLI
- Google Cloud CLI

### Infrastructure as Code
- Terraform
- Ansible
- Vagrant
- VirtualBox

### Containers & Orchestration
- Docker (CE with Compose & BuildX)
- Kubernetes (kubectl)
- Helm
- k9s
- **kubectl QoL Tools**:
  - kubectx (switch between clusters)
  - kubens (switch between namespaces)
  - kubecolor (colorize kubectl output)
  - krew (kubectl plugin manager)
  - kubectl-ai (AI-powered kubectl assistant)

### Programming Languages
- **Python 3**: pip, venv, pipenv, poetry
- **Node.js**: npm, yarn, pnpm
- **Go**: Latest stable version
- **Rust**: rustup, cargo

### Database Clients
- MySQL Client
- PostgreSQL Client
- Redis CLI
- MongoDB Client

### Development Tools
- Visual Studio Code
- Postman
- **Oh My Zsh** with:
  - Powerlevel10k theme
  - zsh-autosuggestions
  - zsh-syntax-highlighting
  - zsh-completions
  - Pre-configured plugins for docker, kubectl, terraform, aws, gcloud, etc.
  - Custom aliases for productivity

### Browsers
- Firefox
- Chromium

## 🛠️ Prerequisites

- A Debian-based or Arch-based Linux distribution
- `sudo` privileges
- Internet connection
- `curl` or `wget` (usually pre-installed)

## 📥 Installation

### Quick Install (One-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/mdiloreto/linux-ubuntu-install-devtools-script/main/install.sh | bash
```

**For automatic installation without prompts:**
```bash
curl -fsSL https://raw.githubusercontent.com/mdiloreto/linux-ubuntu-install-devtools-script/main/install.sh | bash -s -- -y
```

### Manual Install

1. **Clone the repository**:
   ```bash
   git clone https://github.com/mdiloreto/linux-ubuntu-install-devtools-script.git
   cd linux-ubuntu-install-devtools-script
   ```

2. **Make the script executable**:
   ```bash
   chmod +x install.sh
   ```

3. **Run the script**:
   ```bash
   ./install.sh
   ```
   
   Or for automatic installation:
   ```bash
   ./install.sh -y
   ```

## 🔧 Usage

### Full Installation
Simply run the script to install all tools:
```bash
./install.sh
```

The script will:
1. Check which tools are already installed
2. Show you a summary of what will be installed
3. Ask for confirmation (unless `-y` flag is used)
4. Install only the missing tools

### Automatic Installation (No Confirmation)
Skip the confirmation prompt for automated setups:
```bash
./install.sh -y
# or
./install.sh --yes
# or
./install.sh --no-confirm
```

### Check Installation Status
See what's installed without making changes:
```bash
# The script will detect all installed tools
./install.sh
# Then you can choose to proceed or cancel
```

### Help
View all available options:
```bash
./install.sh --help
```

### Selective Installation
You can comment out specific installation functions in the `main()` function to skip certain tools:

```bash
# Edit the script
vim install.sh

# Comment out unwanted installations
# install_rust  # Skip Rust installation
```

## 📋 Post-Installation Steps

After the script completes:

1. **Reload your shell configuration**:
   ```bash
   source ~/.bashrc  # or ~/.zshrc if using Zsh
   ```

2. **Log out and back in** for Docker group changes to take effect

3. **Configure your tools**:
   ```bash
   # Git configuration
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   
   # GitHub CLI authentication
   gh auth login
   
   # Azure CLI login
   az login
   
   # AWS CLI configuration
   aws configure
   ```

4. **Optional: Change default shell to Zsh**:
   ```bash
   chsh -s $(which zsh)
   ```

5. **Configure Powerlevel10k (if using Zsh)**:
   ```bash
   # On first launch of Zsh, Powerlevel10k configuration wizard will run
   # Or manually run:
   p10k configure
   ```

6. **Set up kubectl-ai (optional)**:
   ```bash
   # For Google Gemini
   export GEMINI_API_KEY=your_api_key_here
   
   # Or for OpenAI
   export OPENAI_API_KEY=your_api_key_here
   
   # Add to your shell config to persist
   echo 'export GEMINI_API_KEY=your_api_key_here' >> ~/.zshrc
   ```

## 💡 Productivity Tips

### Custom Aliases (Auto-configured in Zsh)

The script configures useful aliases in your `.zshrc`:

**Modern CLI replacements:**
```bash
ll          # lsd -lah (detailed list)
la          # lsd -a (show hidden files)
l           # lsd -lh (simple list)
lt          # lsd --tree (tree view)
cat         # bat (syntax highlighting)
grep        # rg (ripgrep - faster)
find        # fd (faster find)
du          # ncdu (interactive disk usage)
top         # htop (better top)
top2        # btop (modern system monitor)
```

**Git shortcuts:**
```bash
gs          # git status
ga          # git add
gc          # git commit
gp          # git push
gl          # git log --oneline --graph
gd          # git diff
```

**Docker shortcuts:**
```bash
d           # docker
dc          # docker-compose
dps         # docker ps
dpa         # docker ps -a
di          # docker images
drm         # docker rm
drmi        # docker rmi
```

**Kubernetes:**
```bash
k           # kubectl
kubectx     # Switch Kubernetes contexts
kubens      # Switch Kubernetes namespaces
```

## 🏗️ Supported Distributions

### Debian-based
- Ubuntu (20.04, 22.04, 24.04)
- Debian (11, 12)
- Linux Mint
- Pop!_OS
- Elementary OS

### Arch-based
- Arch Linux
- Manjaro
- EndeavourOS
- Garuda Linux

## 🔍 Script Features

### Automatic Distribution Detection
The script automatically detects your Linux distribution and uses the appropriate package manager:
- `apt` for Debian-based systems
- `pacman` for Arch-based systems

### Error Handling
- Exit on error with proper status codes
- Pipe failure detection
- Informative error messages

### Logging System
Color-coded output for better visibility:
- 🔵 **INFO**: General information
- 🟢 **SUCCESS**: Successful operations
- 🟡 **WARNING**: Non-critical issues
- 🔴 **ERROR**: Critical failures

### Smart Installation
- Checks if tools are already installed
- Skips redundant installations
- Adds necessary repositories and keys

## 🐛 Troubleshooting

### Permission Denied
Ensure you run the script with proper permissions:
```bash
chmod +x install.sh
```

### Script shows all tools as "will be installed" but they exist
Some tools may be installed in different locations or with different names. The script checks common command names. If you believe a tool is installed but not detected, you can:
1. Verify it's in your PATH: `echo $PATH`
2. Check the command manually: `which <command>`
3. Update the `check_tool` function in the script to check for alternative names

### Docker Group Changes Not Applied
Log out completely and log back in, or run:
```bash
newgrp docker
```

### Arch Linux AUR Packages
Some tools require an AUR helper (yay, paru). Install one first:
```bash
# Install yay
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

### Python Tools on Arch Linux
On Arch Linux, Python tools are installed using `pipx` to comply with PEP 668 (externally-managed-environment). This means each tool runs in its own isolated environment. Tools are available system-wide but don't interfere with system Python packages.

### kubectl QoL Tools Usage
After installation, you'll have these kubectl enhancements:

```bash
# Quick kubectl alias
k get pods              # Instead of kubectl get pods

# Switch contexts easily
kubectx                 # List all contexts
kubectx my-cluster      # Switch to my-cluster

# Switch namespaces
kubens                  # List all namespaces
kubens default          # Switch to default namespace

# Colorized output (automatically enabled)
kubectl get pods        # Will be colorized via kubecolor alias

# AI-powered assistance (requires API key)
kubectl ai "list all pods in default namespace"
kubectl ai "create a deployment with nginx"
```

### Snap Not Available (Debian)
If snap is not available on your system:
```bash
sudo apt install snapd
sudo systemctl enable --now snapd.socket
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. Some ideas:
- Add support for more distributions (Fedora, openSUSE)
- Add more development tools
- Improve error handling
- Add installation options/flags

## 📝 License

MIT License - feel free to use and modify as needed.

## ⚠️ Disclaimer

This script installs many packages and modifies system configurations. While it's designed to be safe:
- Review the script before running it
- Back up important data
- Test in a VM or non-production environment first
- The script requires sudo privileges

## 📞 Support

If you encounter issues:
1. Check the [Issues](https://github.com/mdiloreto/linux-ubuntu-install-devtools-script/issues) page
2. Review the troubleshooting section above
3. Open a new issue with:
   - Your distribution and version
   - Error messages
   - Steps to reproduce

## 🙏 Acknowledgments

Thanks to all the open-source projects and their maintainers that make these tools available.

---

**Made with ❤️ for the Linux developer community**