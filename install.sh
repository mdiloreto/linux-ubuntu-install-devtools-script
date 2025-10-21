#!/bin/bash
set -o pipefail  # Pipe failures cause script to fail
# Note: We don't use 'set -e' to allow continuing after failures

# Global variables
SKIP_CONFIRMATION=false
TOOLS_TO_INSTALL=()
TOOLS_ALREADY_INSTALLED=()
FAILED_INSTALLATIONS=()
NEWLY_INSTALLED=()
UPGRADED_TOOLS=()
SKIPPED_TOOLS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_installed() {
    echo -e "${GREEN}✓${NC} $1"
}

log_not_installed() {
    echo -e "${RED}✗${NC} $1"
}

# Safe execution wrapper - continues on error
safe_execute() {
    local step_name="$1"
    shift
    
    if "$@"; then
        return 0
    else
        log_error "Failed: $step_name"
        FAILED_INSTALLATIONS+=("$step_name")
        return 1
    fi
}

# Check if package is installed (distribution-agnostic)
is_package_installed() {
    local package="$1"
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        dpkg -l "$package" 2>/dev/null | grep -q "^ii"
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        pacman -Q "$package" &>/dev/null
    fi
}

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif [ -f /etc/arch-release ]; then
        OS="arch"
    else
        log_error "Unable to detect Linux distribution"
        exit 1
    fi
    
    case $OS in
        ubuntu|debian|linuxmint|pop|elementary)
            DISTRO_TYPE="debian"
            PKG_MANAGER="apt"
            log_info "Detected Debian-based distribution: $OS"
            ;;
        arch|manjaro|endeavouros|garuda)
            DISTRO_TYPE="arch"
            PKG_MANAGER="pacman"
            log_info "Detected Arch-based distribution: $OS"
            ;;
        *)
            log_error "Unsupported distribution: $OS"
            exit 1
            ;;
    esac
}

# Check if a command exists
# Check if a command exists in PATH
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if a directory exists
dir_exists() {
    [ -d "$1" ]
}

# Enhanced tool installation check
# Checks using multiple methods: command, which, and type
is_tool_installed() {
    local tool="$1"
    
    # Method 1: Use command -v (POSIX compliant, most reliable)
    if command -v "$tool" &> /dev/null; then
        return 0
    fi
    
    # Method 2: Use which (if available)
    if command -v which &> /dev/null; then
        if which "$tool" &> /dev/null; then
            return 0
        fi
    fi
    
    # Method 3: Use type (bash built-in)
    if type "$tool" &> /dev/null; then
        return 0
    fi
    
    # Method 4: Check common installation paths directly
    local common_paths=(
        "/usr/bin/$tool"
        "/usr/local/bin/$tool"
        "/bin/$tool"
        "/opt/$tool"
        "$HOME/.local/bin/$tool"
        "$HOME/bin/$tool"
    )
    
    for path in "${common_paths[@]}"; do
        if [ -x "$path" ]; then
            return 0
        fi
    done
    
    return 1
}

# Get the installation path of a tool (for debugging/info)
get_tool_path() {
    local tool="$1"
    
    # Try command -v first
    if command -v "$tool" &> /dev/null; then
        command -v "$tool"
        return 0
    fi
    
    # Try which
    if command -v which &> /dev/null; then
        if which "$tool" &> /dev/null; then
            which "$tool"
            return 0
        fi
    fi
    
    # Check common paths
    local common_paths=(
        "/usr/bin/$tool"
        "/usr/local/bin/$tool"
        "/bin/$tool"
        "/opt/$tool"
        "$HOME/.local/bin/$tool"
        "$HOME/bin/$tool"
    )
    
    for path in "${common_paths[@]}"; do
        if [ -x "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    echo "not found"
    return 1
}

# Safe execution wrapper - continues even if command fails
safe_execute() {
    local description="$1"
    shift
    
    if "$@"; then
        return 0
    else
        log_error "Failed: $description"
        FAILED_INSTALLATIONS+=("$description")
        return 1
    fi
}

# Skip if already installed
skip_if_installed() {
    local cmd="$1"
    local name="$2"
    
    if is_tool_installed "$cmd"; then
        log_warning "$name already installed, skipping"
        SKIPPED_TOOLS+=("$name")
        return 0  # Return 0 means "skip"
    fi
    return 1  # Return 1 means "continue with installation"
}

# Install a package and track the result
install_package() {
    local package_name="$1"
    local display_name="${2:-$package_name}"
    local check_command="${3:-$package_name}"
    
    # Check if already installed
    if is_tool_installed "$check_command"; then
        log_warning "$display_name is already installed"
        SKIPPED_TOOLS+=("$display_name")
        return 0
    fi
    
    log_info "Installing $display_name..."
    
    local install_success=false
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        if sudo apt install -y "$package_name" &>/dev/null; then
            install_success=true
        fi
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        if sudo pacman -S --noconfirm "$package_name" &>/dev/null; then
            install_success=true
        fi
    fi
    
    # Verify installation
    if $install_success && is_tool_installed "$check_command"; then
        log_success "$display_name installed successfully"
        NEWLY_INSTALLED+=("$display_name")
        return 0
    else
        log_error "Failed to install $display_name"
        FAILED_INSTALLATIONS+=("$display_name")
        return 1
    fi
}

# Install multiple packages at once and track results
install_packages() {
    local package_list="$1"
    local description="$2"
    
    log_info "Installing $description..."
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        if sudo apt install -y $package_list; then
            log_success "$description installed"
            return 0
        else
            log_error "Some packages in $description failed to install"
            return 1
        fi
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        if sudo pacman -S --noconfirm $package_list; then
            log_success "$description installed"
            return 0
        else
            log_error "Some packages in $description failed to install"
            return 1
        fi
    fi
}

# Check if package exists in repository
package_exists() {
    local package="$1"
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        apt-cache show "$package" &>/dev/null
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        pacman -Si "$package" &>/dev/null
    fi
}

# Check installation status of all tools
check_installation_status() {
    log_info "🔍 Checking installation status of tools..."
    echo ""
    
    echo -e "${CYAN}=== Development Tools Status ===${NC}"
    echo ""
    
    # Core utilities
    echo -e "${MAGENTA}Core Utilities:${NC}"
    check_tool "git" "Git"
    check_tool "curl" "curl"
    check_tool "wget" "wget"
    check_tool "vim" "Vim"
    check_tool "htop" "htop"
    check_tool "btop" "btop"
    check_tool "fzf" "fzf"
    check_tool "tree" "tree"
    check_tool "lsd" "lsd"
    check_tool "bat" "bat"
    check_tool "zsh" "Zsh"
    check_tool "tmux" "tmux"
    echo ""
    
    # Version control
    echo -e "${MAGENTA}Version Control:${NC}"
    check_tool "gh" "GitHub CLI"
    echo ""
    
    # Cloud platforms
    echo -e "${MAGENTA}Cloud Platforms:${NC}"
    check_tool "az" "Azure CLI"
    check_tool "aws" "AWS CLI"
    check_tool "gcloud" "Google Cloud CLI"
    echo ""
    
    # Infrastructure as Code
    echo -e "${MAGENTA}Infrastructure as Code:${NC}"
    check_tool "terraform" "Terraform"
    check_tool "ansible" "Ansible"s
    check_tool "vagrant" "Vagrant"
    echo ""
    
    # Containers & Orchestration
    echo -e "${MAGENTA}Containers & Orchestration:${NC}"
    check_tool "docker" "Docker"
    check_tool "kubectl" "kubectl"
    check_tool "helm" "Helm"
    check_tool "k9s" "k9s"
    check_tool "kubectx" "kubectx"
    check_tool "kubens" "kubens"
    check_tool "kubecolor" "kubecolor"
    check_tool "kubectl-krew" "krew"
    echo ""
    
    # Programming Languages
    echo -e "${MAGENTA}Programming Languages:${NC}"
    check_tool "python3" "Python 3"
    check_tool "node" "Node.js"
    check_tool "go" "Go"
    check_tool "rustc" "Rust"
    echo ""
    
    # Database clients
    echo -e "${MAGENTA}Database Clients:${NC}"
    check_tool "mysql" "MySQL Client"
    check_tool "psql" "PostgreSQL Client"
    check_tool "redis-cli" "Redis CLI"
    check_tool "mongosh" "MongoDB Client"
    echo ""
    
    # Development tools
    echo -e "${MAGENTA}Development Tools:${NC}"
    check_tool "code" "VS Code"
    check_tool "postman" "Postman"
    echo ""
    
    # Browsers
    echo -e "${MAGENTA}Browsers:${NC}"
    check_tool "firefox" "Firefox"
    check_tool "chromium" "Chromium" || check_tool "chromium-browser" "Chromium"
    echo ""
    
    # Shell enhancements
    echo -e "${MAGENTA}Shell Enhancements:${NC}"
    check_dir "$HOME/.oh-my-zsh" "Oh My Zsh"
    echo ""
    
    echo -e "${CYAN}=================================${NC}"
    echo ""
    echo -e "Tools to install: ${YELLOW}${#TOOLS_TO_INSTALL[@]}${NC}"
    echo -e "Already installed: ${GREEN}${#TOOLS_ALREADY_INSTALLED[@]}${NC}"
    echo ""
}

# Check if a tool is installed
check_tool() {
    local cmd=$1
    local name=$2
    
    if is_tool_installed "$cmd"; then
        log_installed "$name"
        TOOLS_ALREADY_INSTALLED+=("$name")
    else
        log_not_installed "$name (will be installed)"
        TOOLS_TO_INSTALL+=("$name")
    fi
}

# Check if a directory exists (for Oh My Zsh, etc.)
check_dir() {
    local dir=$1
    local name=$2
    
    if dir_exists "$dir"; then
        log_installed "$name"
        TOOLS_ALREADY_INSTALLED+=("$name")
    else
        log_not_installed "$name (will be installed)"
        TOOLS_TO_INSTALL+=("$name")
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes|--no-confirm)
                SKIP_CONFIRMATION=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help message
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Enhanced Linux Development Tools Installation Script
Supports Debian-based and Arch-based distributions

OPTIONS:
    -y, --yes, --no-confirm    Skip confirmation prompts (auto-confirm all)
    -h, --help                 Show this help message

EXAMPLES:
    $0                         Interactive installation with confirmation
    $0 -y                      Automatic installation without confirmation
    $0 --no-confirm            Same as -y

EOF
}

# Ask for confirmation
ask_confirmation() {
    if [ "$SKIP_CONFIRMATION" = true ]; then
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}Do you want to proceed with the installation? (y/n)${NC}"
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled by user"
        exit 0
    fi
}

# Update system packages
update_system() {
    log_info "🔧 Updating and upgrading system packages..."
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        sudo apt update && sudo apt upgrade -y
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        sudo pacman -Syu --noconfirm
    fi
    
    log_success "System updated successfully"
}

# Install core utilities
install_core_utilities() {
    log_info "📦 Installing core utilities..."
    
    # Check if core tools are already installed
    local tools_needed=false
    local tools_to_check=("curl" "wget" "git" "vim" "htop" "fzf" "tree" "lsd" "bat" "zsh" "tmux")
    
    for tool in "${tools_to_check[@]}"; do
        if ! is_tool_installed "$tool"; then
            tools_needed=true
        else
            SKIPPED_TOOLS+=("$tool")
        fi
    done
    
    if [ "$tools_needed" = false ]; then
        log_warning "All core utilities already installed, skipping..."
        return
    fi
    
    log_info "Installing missing core utilities..."
    
    local install_success=false
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        if sudo apt install -y \
            curl wget unzip zip tar gzip bzip2 xz-utils \
            jq yq ripgrep fd-find \
            software-properties-common apt-transport-https ca-certificates gnupg \
            vim nano git htop btop neofetch \
            fzf tree lsd bat exa \
            zsh tmux screen \
            build-essential make cmake \
            net-tools dnsutils traceroute \
            ncdu tldr 2>/dev/null; then
            install_success=true
        fi
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        if sudo pacman -S --noconfirm \
            curl wget unzip zip tar gzip bzip2 xz \
            jq yq ripgrep fd \
            ca-certificates gnupg \
            vim nano git htop btop  \
            fzf tree lsd bat exa \
            zsh tmux screen \
            base-devel make cmake \
            net-tools bind traceroute \
            ncdu tldr 2>/dev/null; then
            install_success=true
        fi
    fi
    
    if $install_success; then
        # Track newly installed tools
        for tool in "${tools_to_check[@]}"; do
            if is_tool_installed "$tool"; then
                # Check if it wasn't in skipped (meaning it was just installed)
                local was_skipped=false
                for skipped in "${SKIPPED_TOOLS[@]}"; do
                    if [ "$skipped" = "$tool" ]; then
                        was_skipped=true
                        break
                    fi
                done
                if [ "$was_skipped" = false ]; then
                    NEWLY_INSTALLED+=("$tool")
                fi
            fi
        done
        log_success "Core utilities installed"
    else
        FAILED_INSTALLATIONS+=("Core utilities (some packages)")
        log_error "Some core utilities failed to install"
    fi
}

# Install GitHub CLI
install_github_cli() {
    log_info "🐙 Installing GitHub CLI..."
    
    if skip_if_installed "gh" "GitHub CLI"; then
        return
    fi
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null && \
           sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
           echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
           sudo apt update 2>/dev/null && sudo apt install -y gh 2>/dev/null; then
            NEWLY_INSTALLED+=("GitHub CLI")
            log_success "GitHub CLI installed"
        else
            FAILED_INSTALLATIONS+=("GitHub CLI")
            log_error "Failed to install GitHub CLI"
        fi
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        if sudo pacman -S --noconfirm github-cli 2>/dev/null; then
            NEWLY_INSTALLED+=("GitHub CLI")
            log_success "GitHub CLI installed"
        else
            FAILED_INSTALLATIONS+=("GitHub CLI")
            log_error "Failed to install GitHub CLI"
        fi
    fi
}

# Install Docker
install_docker() {
    log_info "🐳 Installing Docker..."
    
    if skip_if_installed "docker" "Docker"; then
        # Still add user to docker group if not already
        if ! groups | grep -q docker 2>/dev/null; then
            sudo usermod -aG docker $USER 2>/dev/null
            log_info "Added user to docker group"
        fi
        return
    fi
    
    local install_success=false
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        # Install Docker using official repository
        if sudo apt install -y ca-certificates curl gnupg 2>/dev/null && \
           sudo install -m 0755 -d /etc/apt/keyrings 2>/dev/null; then
            
            if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
                curl -fsSL https://download.docker.com/linux/$OS/gpg 2>/dev/null | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
                sudo chmod a+r /etc/apt/keyrings/docker.gpg 2>/dev/null
            fi
            
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
              $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
              sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            if sudo apt update 2>/dev/null && \
               sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null; then
                install_success=true
            fi
        fi
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        if sudo pacman -S --noconfirm docker docker-compose docker-buildx 2>/dev/null; then
            sudo systemctl enable docker 2>/dev/null
            sudo systemctl start docker 2>/dev/null
            install_success=true
        fi
    fi
    
    if $install_success; then
        # Add user to docker group
        sudo usermod -aG docker $USER 2>/dev/null
        NEWLY_INSTALLED+=("Docker")
        log_success "Docker installed (you may need to log out and back in for group changes)"
    else
        FAILED_INSTALLATIONS+=("Docker")
        log_error "Failed to install Docker"
    fi
}

# Install Node.js and npm
install_nodejs() {
    log_info "📗 Installing Node.js and npm..."
    
    if skip_if_installed "node" "Node.js"; then
        return
    fi
    
    local install_success=false
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        # Install using NodeSource repository (LTS version)
        if curl -fsSL https://deb.nodesource.com/setup_lts.x 2>/dev/null | sudo -E bash - 2>/dev/null && \
           sudo apt install -y nodejs 2>/dev/null; then
            install_success=true
        fi
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        if sudo pacman -S --noconfirm nodejs npm 2>/dev/null; then
            install_success=true
        fi
    fi
    
    if $install_success && is_tool_installed "node"; then
        NEWLY_INSTALLED+=("Node.js")
        log_success "Node.js and npm installed"
    else
        FAILED_INSTALLATIONS+=("Node.js")
        log_error "Failed to install Node.js"
    fi
}
    fi
    
    # Install useful global packages
    if command_exists "npm"; then
        sudo npm install -g yarn pnpm 2>/dev/null || npm install -g yarn pnpm
    fi
    
    log_success "Node.js and npm installed"
}

# Install Azure CLI
install_azure_cli() {
    log_info "☁️ Installing Azure CLI..."
    
    if command_exists "az"; then
        log_warning "Azure CLI already installed, skipping..."
        return
    fi
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        # Use AUR helper or install from AUR manually
        if command -v yay &> /dev/null; then
            yay -S --noconfirm azure-cli
        elif command -v paru &> /dev/null; then
            paru -S --noconfirm azure-cli
        else
            log_warning "Please install azure-cli from AUR manually or install yay/paru first"
            return
        fi
    fi
    
    log_success "Azure CLI installed"
}

# Install AWS CLI
install_aws_cli() {
    log_info "☁️ Installing AWS CLI..."
    
    if ! command -v aws &> /dev/null; then
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
        unzip -q /tmp/awscliv2.zip -d /tmp
        sudo /tmp/aws/install
        rm -rf /tmp/awscliv2.zip /tmp/aws
    else
        log_warning "AWS CLI already installed"
    fi
    
    log_success "AWS CLI installed"
}

# Install Google Cloud CLI
install_gcloud_cli() {
    log_info "☁️ Installing Google Cloud CLI..."


    if ! command -v aws &> /dev/null; thens
        if [ "$DISTRO_TYPE" = "debian" ]; then
            if ! command -v gcloud &> /dev/null; then
                echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
                curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
                sudo apt update && sudo apt install -y google-cloud-cli
            else
                log_warning "Google Cloud CLI already installed"
            fi
        elif [ "$DISTRO_TYPE" = "arch" ]; then
            if command -v yay &> /dev/null; then
                yay -S --noconfirm google-cloud-cli
            else
                log_warning "Please install google-cloud-cli from AUR manually"
            fi
        fi
    fi
    
    log_success "Google Cloud CLI installed"
}

# Install Terraform
install_terraform() {
    log_info "🌍 Installing Terraform..."
    
    if command_exists "terraform"; then
        log_warning "Terraform already installed, skipping..."
        return
    fi
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update && sudo apt install -y terraform
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        sudo pacman -S --noconfirm terraform
    fi
    
    log_success "Terraform installed"
}

# Install Ansible
install_ansible() {
    log_info "🤖 Installing Ansible..."
    
    if command_exists "ansible"; then
        log_warning "Ansible already installed, skipping..."
        return
    fi
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        sudo apt install -y ansible
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        sudo pacman -S --noconfirm ansible
    fi
    
    log_success "Ansible installed"
}

# Install Python
install_python() {
    log_info "🐍 Installing Python and related tools..."
    
    if command_exists "python3" && command_exists "pip3"; then
        log_warning "Python already installed, checking dev tools..."
        
        # Check if pipx is available and install tools if needed
        if [ "$DISTRO_TYPE" = "arch" ]; then
            if ! command_exists "pipx"; then
                sudo pacman -S --noconfirm python-pipx
            fi
            # Install tools via pipx if not already installed
            for tool in pipenv poetry black flake8 pylint pytest ipython; do
                if ! command_exists "$tool"; then
                    pipx install "$tool" 2>/dev/null || pipx upgrade "$tool" 2>/dev/null || true
                fi
            done
        fi
        return
    fi
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        sudo apt install -y python3 python3-pip python3-venv python3-dev
        sudo apt install -y python-is-python3  # Make 'python' point to python3
        
        # Upgrade pip and install useful tools (Debian allows this)
        pip3 install --user --upgrade pip setuptools wheel
        pip3 install --user pipenv poetry black flake8 pylint pytest ipython
        
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        sudo pacman -S --noconfirm python python-pip python-virtualenv python-pipx
        
        # On Arch, use pipx for applications to avoid externally-managed-environment error
        log_info "Installing Python development tools with pipx..."
        
        # Ensure pipx path is in environment
        python3 -m pipx ensurepath 2>/dev/null || true
        
        # Install tools via pipx (each in its own isolated environment)
        # Check if command exists before installing to avoid reinstalls
        command_exists "pipenv" || pipx install pipenv 2>/dev/null || true
        command_exists "poetry" || pipx install poetry 2>/dev/null || true
        command_exists "black" || pipx install black 2>/dev/null || true
        command_exists "flake8" || pipx install flake8 2>/dev/null || true
        command_exists "pylint" || pipx install pylint 2>/dev/null || true
        command_exists "pytest" || pipx install pytest 2>/dev/null || true
        command_exists "ipython" || pipx install ipython 2>/dev/null || true
        
        log_info "Python tools installed via pipx (isolated environments)"
    fi
    
    log_success "Python installed"
}

# Install Go
install_go() {
    log_info "🐹 Installing Go..."
    
    if command_exists "go"; then
        log_warning "Go already installed, skipping..."
        return
    fi
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        # Remove old Go installation
        sudo rm -rf /usr/local/go
        
        # Download and install latest Go
        GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -n 1)
        curl -L "https://golang.org/dl/${GO_VERSION}.linux-amd64.tar.gz" -o "/tmp/go.tar.gz"
        sudo tar -C /usr/local -xzf /tmp/go.tar.gz
        rm /tmp/go.tar.gz
        
        # Add to PATH in bashrc and zshrc
        if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
            echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
        fi
        if [ -f ~/.zshrc ] && ! grep -q "/usr/local/go/bin" ~/.zshrc; then
            echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.zshrc
        fi
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        sudo pacman -S --noconfirm go
    fi
    
    log_success "Go installed"
}

# Install Rust
install_rust() {
    log_info "🦀 Installing Rust..."
    
    if ! command -v rustc &> /dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    else
        log_warning "Rust already installed"
    fi
    
    log_success "Rust installed"
}

# Install Kubernetes tools
install_kubernetes_tools() {
    log_info "☸️ Installing Kubernetes tools (kubectl, helm, k9s)..."
    
    # Install kubectl
    if ! command -v kubectl &> /dev/null; then
        sudo curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo chmod +x /usr/local/bin/kubectl
    fi
    
    # Install Helm
    if ! command -v helm &> /dev/null; then
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    
    # Install k9s
    if [ "$DISTRO_TYPE" = "debian" ]; then
        if ! command -v k9s &> /dev/null; then
            curl -sS https://webinstall.dev/k9s | bash
        fi
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        sudo pacman -S --noconfirm k9s
    fi
    
    log_success "Kubernetes tools installed"
}

# Install database clients
install_database_clients() {
    log_info "🗄️ Installing database clients..."
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        sudo apt install -y mysql-client postgresql-client redis-tools mongodb-clients
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        sudo pacman -S --noconfirm mysql-clients postgresql-libs redis mongodb-tools
    fi
    
    log_success "Database clients installed"
}

# Install Visual Studio Code
install_vscode() {
    log_info "🎨 Installing Visual Studio Code..."
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        if ! command -v code &> /dev/null; then
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
            echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
            sudo apt update && sudo apt install -y code
        else
            log_warning "VS Code already installed"
        fi
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        if command -v yay &> /dev/null; then
            yay -S --noconfirm visual-studio-code-bin
        else
            log_warning "Please install visual-studio-code-bin from AUR manually"
        fi
    fi
    
    log_success "VS Code installed"
}

# Install browsers
install_browsers() {
    log_info "🌐 Installing browsers..."
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        sudo apt install -y firefox chromium-browser
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        sudo pacman -S --noconfirm firefox chromium
    fi
    
    log_success "Browsers installed"
}

# Install Postman
install_postman() {
    log_info "📮 Installing Postman..."
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        if command -v snap &> /dev/null; then
            sudo snap install postman
        else
            log_warning "Snap not available, skipping Postman"
        fi
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        if command -v yay &> /dev/null; then
            yay -S --noconfirm postman-bin
        else
            log_warning "Please install postman-bin from AUR manually"
        fi
    fi
    
    log_success "Postman installed"
}

# Install virtualization tools
install_virtualization() {
    log_info "💻 Installing virtualization tools (Vagrant, VirtualBox)..."
    
    # Check if Vagrant is already installed
    if skip_if_installed "vagrant" "Vagrant"; then
        log_info "Vagrant already installed, skipping"
    else
        if [ "$DISTRO_TYPE" = "debian" ]; then
            # Add HashiCorp repository for Vagrant
            log_info "Adding HashiCorp repository..."
            if wget -O- https://apt.releases.hashicorp.com/gpg 2>/dev/null | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg 2>/dev/null; then
                echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
                sudo apt update >/dev/null 2>&1
                
                if sudo apt install -y vagrant; then
                    NEWLY_INSTALLED+=("Vagrant")
                    log_success "Vagrant installed"
                else
                    FAILED_INSTALLATIONS+=("Vagrant")
                    log_error "Failed to install Vagrant"
                fi
            else
                FAILED_INSTALLATIONS+=("Vagrant")
                log_error "Failed to add HashiCorp repository"
            fi
        elif [ "$DISTRO_TYPE" = "arch" ]; then
            if package_exists "vagrant"; then
                if sudo pacman -S --noconfirm vagrant; then
                    NEWLY_INSTALLED+=("Vagrant")
                    log_success "Vagrant installed"
                else
                    FAILED_INSTALLATIONS+=("Vagrant")
                    log_error "Failed to install Vagrant"
                fi
            else
                log_warning "Vagrant not available in official Arch repositories, trying AUR..."
                SKIPPED_TOOLS+=("Vagrant (not in official repos)")
            fi
        fi
    fi
    
    # VirtualBox (if not on WSL)
    if ! grep -qi microsoft /proc/version 2>/dev/null; then
        if skip_if_installed "virtualbox" "VirtualBox"; then
            log_info "VirtualBox already installed"
        else
            if [ "$DISTRO_TYPE" = "debian" ]; then
                if sudo apt install -y virtualbox virtualbox-ext-pack 2>/dev/null; then
                    NEWLY_INSTALLED+=("VirtualBox")
                    log_success "VirtualBox installed"
                else
                    FAILED_INSTALLATIONS+=("VirtualBox")
                    log_error "Failed to install VirtualBox"
                fi
            elif [ "$DISTRO_TYPE" = "arch" ]; then
                if package_exists "virtualbox" && package_exists "virtualbox-host-modules-arch"; then
                    if sudo pacman -S --noconfirm virtualbox virtualbox-host-modules-arch; then
                        NEWLY_INSTALLED+=("VirtualBox")
                        log_success "VirtualBox installed"
                    else
                        FAILED_INSTALLATIONS+=("VirtualBox")
                        log_error "Failed to install VirtualBox"
                    fi
                else
                    log_warning "VirtualBox packages not available"
                    SKIPPED_TOOLS+=("VirtualBox (packages not found)")
                fi
            fi
        fi
    else
        log_info "WSL detected, skipping VirtualBox installation"
        SKIPPED_TOOLS+=("VirtualBox (WSL environment)")
    fi
    
    log_success "Virtualization tools setup completed"
}

# Install Oh My Zsh and configure Zsh
install_oh_my_zsh() {
    log_info "🎨 Installing and configuring Oh My Zsh..."
    
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        # Install Oh My Zsh
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        
        # Install popular plugins
        log_info "Installing Zsh plugins..."
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 2>/dev/null || true
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null || true
        git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions 2>/dev/null || true
            
        log_success "Oh My Zsh installed with plugins and Powerlevel10k theme"
    else
        log_warning "Oh My Zsh already installed, updating plugins..."
        
        # Update existing plugins
        [ -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ] || \
            git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 2>/dev/null || true
        
        [ -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ] || \
            git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null || true
        
        [ -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions" ] || \
            git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions 2>/dev/null || true
        
    fi
    
    # Configure .zshrc with recommended plugins
    if [ -f "$HOME/.zshrc" ]; then
        log_info "Configuring .zshrc..."
        
        # Backup original .zshrc
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Update theme to powerlevel10k
        if ! grep -q "ZSH_THEME=\"powerlevel10k/powerlevel10k\"" "$HOME/.zshrc"; then
            sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"
        fi
        
        # Update plugins
        if ! grep -q "zsh-autosuggestions" "$HOME/.zshrc"; then
            sed -i 's/^plugins=.*/plugins=(git docker docker-compose kubectl terraform ansible aws gcloud github npm python pip golang rust zsh-autosuggestions zsh-syntax-highlighting zsh-completions)/' "$HOME/.zshrc"
        fi
        
        # Add useful aliases
        if ! grep -q "# Custom aliases" "$HOME/.zshrc"; then
            cat >> "$HOME/.zshrc" << 'EOF'

# Custom aliases
alias ll='lsd -lah'
alias la='lsd -a'
alias l='lsd -lh'
alias lt='lsd --tree'
alias cat='bat'
alias grep='rg'
alias find='fd'
alias du='ncdu'
alias top='htop'
alias top2='btop'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'
alias gd='git diff'

# Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'

EOF
        fi
        
        log_success "Zsh configuration updated"
    fi
}

# Install kubectl QoL tools
install_kubectl_qol_tools() {
    log_info "☸️  Installing kubectl Quality of Life tools..."
    
    if ! command -v kubectl &> /dev/null; then
        log_warning "kubectl not installed, skipping QoL tools"
        return
    fi
    
    # Detect shell config
    if [ -n "${ZSH_VERSION-}" ] || [ "${SHELL-}" = "$(which zsh)" ]; then
        SHELL_RC="${HOME}/.zshrc"
    else
        SHELL_RC="${HOME}/.bashrc"
    fi
    
    # Function to add line once
    add_line_once() {
        local line="$1"
        local file="$2"
        grep -Fq "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
    }
    
    log_info "Using shell config: $SHELL_RC"
    
    # Add kubectl alias
    mkdir -p "$(dirname "$SHELL_RC")"
    add_line_once "# kubectl QoL" "$SHELL_RC"
    add_line_once "alias k=kubectl" "$SHELL_RC"
    
    # Install kubectx, kubens, and kubecolor
    if [ "$DISTRO_TYPE" = "debian" ]; then
        log_info "Installing kubectx with apt..."
        sudo apt update
        sudo apt install -y kubectx
        
        # Install kubens using webi.sh
        if ! command -v kubens &> /dev/null; then
            log_info "Installing kubens..."
            curl -sS https://webi.sh/kubens | sh
            if [ -f "${HOME}/.config/envman/PATH.env" ]; then
                add_line_once "source ~/.config/envman/PATH.env" "$SHELL_RC"
            fi
        fi
        
        # Install kubecolor
        if ! command -v kubecolor &> /dev/null; then
            log_info "Installing kubecolor..."
            sudo apt-get install -y wget dpkg
            ver="$(wget -qO- https://kubecolor.github.io/packages/deb/version)"
            arch="$(dpkg --print-architecture)"
            wget -O /tmp/kubecolor.deb "https://kubecolor.github.io/packages/deb/pool/main/k/kubecolor/kubecolor_${ver}_${arch}.deb"
            sudo dpkg -i /tmp/kubecolor.deb || sudo apt-get -f install -y
            rm -f /tmp/kubecolor.deb
        fi
        
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        log_info "Installing kubectx with pacman..."
        sudo pacman -S --noconfirm kubectx
        log_info "kubectx package includes kubens"
        
        # Install kubecolor with AUR helper if available
        if command -v yay &> /dev/null; then
            yay -S --noconfirm kubecolor
        elif command -v paru &> /dev/null; then
            paru -S --noconfirm kubecolor
        else
            log_warning "Install kubecolor manually with: yay -S kubecolor"
        fi
    fi
    
    # Configure kubecolor
    if command -v kubecolor &> /dev/null; then
        add_line_once 'alias kubectl=kubecolor' "$SHELL_RC"
        
        if [[ "$SHELL_RC" == *".zshrc" ]]; then
            add_line_once 'compdef kubecolor=kubectl' "$SHELL_RC"
            add_line_once 'autoload -Uz compinit && compinit' "$SHELL_RC"
            add_line_once 'if command -v kubectl >/dev/null; then KUBE_COMP="${XDG_CACHE_HOME:-$HOME/.cache}/kubectl_completion.zsh"; mkdir -p "${KUBE_COMP:h}"; if [[ ! -f $KUBE_COMP || $(command -v kubectl) -nt $KUBE_COMP ]]; then kubectl completion zsh >| "$KUBE_COMP"; fi; source "$KUBE_COMP"; fi' "$SHELL_RC"
        else
            add_line_once 'source <(kubectl completion bash) 2>/dev/null || true' "$SHELL_RC"
        fi
    fi
    
    # Install krew (kubectl plugin manager)
    if ! command -v kubectl-krew &> /dev/null && ! kubectl krew version &> /dev/null; then
        log_info "Installing krew (kubectl plugin manager)..."
        (
            set +e
            cd "$(mktemp -d)" &&
            OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
            ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
            KREW="krew-${OS}_${ARCH}" &&
            curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
            tar zxvf "${KREW}.tar.gz" &&
            ./"${KREW}" install krew
        )
        add_line_once 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' "$SHELL_RC"
        
        # Source to make krew available immediately
        export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
    else
        log_info "Krew already installed"
    fi
    
    # Install kubectl-ai plugin (if krew is available)
    if command -v kubectl-krew &> /dev/null || kubectl krew version &> /dev/null; then
        log_info "Installing kubectl-ai plugin..."
        kubectl krew install ai 2>/dev/null || true
    fi
    
    log_success "kubectl QoL tools installed"
    log_info "Reload your shell with: source $SHELL_RC"
    log_info "For kubectl-ai, set your API key: export GEMINI_API_KEY=... (or OPENAI_API_KEY, etc.)"
}

# Cleanup
cleanup() {
    log_info "🔄 Cleaning up..."
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        sudo apt autoremove -y
        sudo apt clean
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        sudo pacman -Sc --noconfirm
    fi
    
    log_success "Cleanup completed"
}

# Main installation flow
main() {
    # Parse command line arguments
    parse_args "$@"
    
    echo "=================================="
    echo "  Linux DevTools Installation"
    echo "=================================="
    echo ""
    
    detect_distro
    
    echo ""
    
    # Check current installation status
    check_installation_status
    
    # If everything is already installed, exit
    if [ ${#TOOLS_TO_INSTALL[@]} -eq 0 ]; then
        log_success "✅ All tools are already installed!"
        echo ""
        log_info "Run with --help to see available options"
        exit 0
    fi
    
    # Ask for confirmation if not skipped
    ask_confirmation
    
    log_info "Starting installation process..."
    echo ""
    
    update_system
    install_core_utilities
    install_github_cli
    install_docker
    install_nodejs
    install_azure_cli
    install_aws_cli
    install_gcloud_cli
    install_terraform
    install_ansible
    install_python
    install_go
    install_rust
    install_kubernetes_tools
    install_kubectl_qol_tools
    install_database_clients
    install_vscode
    install_browsers
    install_postman
    install_virtualization
    install_oh_my_zsh
    cleanup
    
    echo ""
    echo "=========================================="
    echo "     INSTALLATION SUMMARY REPORT"
    echo "=========================================="
    echo ""
    
    # Calculate totals
    local total_attempted=$((${#NEWLY_INSTALLED[@]} + ${#FAILED_INSTALLATIONS[@]}))
    local total_skipped=${#SKIPPED_TOOLS[@]}
    local total_upgraded=${#UPGRADED_TOOLS[@]}
    
    # Show statistics
    echo -e "${CYAN}📊 Statistics:${NC}"
    echo -e "  ${GREEN}✓${NC} Newly installed: ${GREEN}${#NEWLY_INSTALLED[@]}${NC}"
    echo -e "  ${YELLOW}⟳${NC} Already installed (skipped): ${YELLOW}${total_skipped}${NC}"
    echo -e "  ${BLUE}⬆${NC}  Upgraded: ${BLUE}${total_upgraded}${NC}"
    echo -e "  ${RED}✗${NC} Failed: ${RED}${#FAILED_INSTALLATIONS[@]}${NC}"
    echo ""
    
    # Show newly installed tools
    if [ ${#NEWLY_INSTALLED[@]} -gt 0 ]; then
        echo -e "${GREEN}✅ Newly Installed Tools (${#NEWLY_INSTALLED[@]}):${NC}"
        for tool in "${NEWLY_INSTALLED[@]}"; do
            echo -e "  ${GREEN}✓${NC} $tool"
        done
        echo ""
    fi
    
    # Show skipped tools
    if [ ${#SKIPPED_TOOLS[@]} -gt 0 ]; then
        echo -e "${YELLOW}⏭️  Already Installed / Skipped (${#SKIPPED_TOOLS[@]}):${NC}"
        for tool in "${SKIPPED_TOOLS[@]}"; do
            echo -e "  ${YELLOW}⊙${NC} $tool"
        done
        echo ""
    fi
    
    # Show upgraded tools
    if [ ${#UPGRADED_TOOLS[@]} -gt 0 ]; then
        echo -e "${BLUE}⬆️  Upgraded Tools (${#UPGRADED_TOOLS[@]}):${NC}"
        for tool in "${UPGRADED_TOOLS[@]}"; do
            echo -e "  ${BLUE}↑${NC} $tool"
        done
        echo ""
    fi
    
    # Show failed installations
    if [ ${#FAILED_INSTALLATIONS[@]} -gt 0 ]; then
        echo -e "${RED}❌ Failed Installations (${#FAILED_INSTALLATIONS[@]}):${NC}"
        for failure in "${FAILED_INSTALLATIONS[@]}"; do
            echo -e "  ${RED}✗${NC} $failure"
        done
        echo ""
        log_warning "💡 Tip: Check the error messages above for troubleshooting"
        log_info "    You can re-run the script to retry failed installations"
        echo ""
    fi
    
    # Overall status
    echo "=========================================="
    if [ ${#FAILED_INSTALLATIONS[@]} -eq 0 ]; then
        log_success "🎉 Installation completed successfully!"
        echo -e "  ${GREEN}All tools were installed or already present${NC}"
    else
        log_warning "⚠️  Installation completed with some failures"
        echo -e "  ${GREEN}Success rate: $(( (total_attempted - ${#FAILED_INSTALLATIONS[@]}) * 100 / total_attempted ))%${NC}"
    fi
    echo "=========================================="
    echo ""
    
    log_info "📋 Next steps:"
    echo "  1. Restart your terminal or run: source ~/.bashrc (or ~/.zshrc)"
    echo "  2. Log out and back in for Docker group changes to take effect"
    echo "  3. Configure your tools (git config, gh auth login, etc.)"
    if [ ${#FAILED_INSTALLATIONS[@]} -gt 0 ]; then
        echo "  4. Review failed installations and re-run if needed"
    fi
    echo ""
}

# Run main function
main "$@"
