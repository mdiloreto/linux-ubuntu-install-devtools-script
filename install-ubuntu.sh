#!/usr/bin/env bash
set -u -o pipefail

ASSUME_YES=false
DRY_RUN=false
SKIP_SHELL_CONFIG=false
FAILED=()
SKIPPED=()

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install a practical Linux development toolchain on Ubuntu/Debian systems.

OPTIONS:
    -y, --yes, --no-confirm    Skip confirmation prompts
    --dry-run                  Print planned commands without running them
    --skip-shell-config        Do not modify shell startup files
    -h, --help                 Show this help message

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes|--no-confirm) ASSUME_YES=true ;;
            --dry-run) DRY_RUN=true ;;
            --skip-shell-config) SKIP_SHELL_CONFIG=true ;;
            -h|--help) usage; exit 0 ;;
            *) log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
        shift
    done
}

run() {
    if $DRY_RUN; then
        printf '[dry-run]'
        printf ' %q' "$@"
        printf '\n'
        return 0
    fi
    "$@"
}

run_shell() {
    if $DRY_RUN; then
        printf '[dry-run] %s\n' "$*"
        return 0
    fi
    bash -c "$*"
}

append_line_once() {
    local line="$1"
    local file="$2"
    if $DRY_RUN; then
        printf '[dry-run] append %q to %q\n' "$line" "$file"
        return 0
    fi
    mkdir -p "$(dirname "$file")"
    touch "$file"
    grep -Fqx "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

apt_install() {
    local packages=("$@")
    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi
    if ! run sudo apt-get install -y "${packages[@]}"; then
        FAILED+=("APT: ${packages[*]}")
        return 1
    fi
}

apt_install_if_available() {
    local package
    for package in "$@"; do
        if apt-cache show "$package" >/dev/null 2>&1; then
            apt_install "$package" || FAILED+=("$package")
        else
            log_warning "APT package not available, skipping: $package"
            SKIPPED+=("$package")
        fi
    done
}

confirm() {
    $ASSUME_YES && return 0
    if [[ ! -t 0 ]]; then
        log_error "Interactive confirmation is unavailable. Re-run with -y to install."
        exit 1
    fi
    read -r -p "Install Ubuntu/Debian dev tools? [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]] || exit 0
}

prepare_system() {
    log_info "Updating APT metadata"
    run sudo apt-get update
    apt_install ca-certificates curl wget gnupg lsb-release software-properties-common apt-transport-https
}

install_core_tools() {
    log_info "Installing core CLI tools"
    apt_install \
        build-essential make cmake pkg-config \
        git curl wget unzip zip tar gzip bzip2 xz-utils \
        openssh-client openssl ca-certificates gnupg \
        jq yq ripgrep fd-find fzf tree lsd bat \
        vim neovim nano zsh tmux screen \
        htop btop ncdu tldr net-tools dnsutils traceroute direnv \
        shellcheck shfmt

    if command_exists fdfind && ! command_exists fd; then
        run mkdir -p "$HOME/.local/bin"
        run ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"
    fi

    if command_exists batcat && ! command_exists bat; then
        run mkdir -p "$HOME/.local/bin"
        run ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
    fi
}

install_github_cli() {
    command_exists gh && { SKIPPED+=("GitHub CLI"); return; }
    log_info "Installing GitHub CLI"
    run sudo mkdir -p /etc/apt/keyrings
    run_shell "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null"
    run sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    run_shell "echo 'deb [arch='\"$(dpkg --print-architecture)\"' signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null"
    run sudo apt-get update
    apt_install gh
}

install_docker() {
    command_exists docker && { SKIPPED+=("Docker"); run sudo usermod -aG docker "$USER" || true; return; }
    log_info "Installing Docker CE"
    . /etc/os-release
    local docker_distro="ubuntu"
    [[ "${ID}" == "debian" ]] && docker_distro="debian"
    local codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    [[ -n "$codename" ]] || { log_error "Cannot determine distro codename for Docker repo"; FAILED+=("Docker"); return; }

    run sudo install -m 0755 -d /etc/apt/keyrings
    run_shell "curl -fsSL https://download.docker.com/linux/${docker_distro}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
    run sudo chmod a+r /etc/apt/keyrings/docker.gpg
    run_shell "echo 'deb [arch='\"$(dpkg --print-architecture)\"' signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${docker_distro} ${codename} stable' | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null"
    run sudo apt-get update
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    run sudo usermod -aG docker "$USER" || true
}

install_languages() {
    log_info "Installing language toolchains"
    apt_install python3 python3-pip python3-venv python3-dev pipx python-is-python3 nodejs npm golang-go

    command_exists npm && run_shell "sudo npm install -g yarn pnpm || npm install -g yarn pnpm" || true

    if ! command_exists rustc; then
        if $SKIP_SHELL_CONFIG; then
            run_shell "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path"
        else
            run_shell "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
        fi
    fi

    if command_exists pipx; then
        $SKIP_SHELL_CONFIG || run python3 -m pipx ensurepath || true
        for tool in pipenv poetry black ruff pytest ipython; do
            command_exists "$tool" || run pipx install "$tool" || true
        done
    fi

    if ! command_exists mise; then
        run_shell "curl https://mise.run | sh"
        if ! $SKIP_SHELL_CONFIG; then
            append_line_once 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"
            [[ -f "$HOME/.zshrc" ]] && append_line_once 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc"
        fi
    fi
}

install_cloud_iac() {
    log_info "Installing cloud and IaC CLIs"

    if ! command_exists az; then
        run_shell "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    fi

    if ! command_exists aws; then
        run_shell "tmpdir=\$(mktemp -d) && curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o \"\$tmpdir/awscliv2.zip\" && unzip -q \"\$tmpdir/awscliv2.zip\" -d \"\$tmpdir\" && sudo \"\$tmpdir/aws/install\" && rm -rf \"\$tmpdir\""
    fi

    if ! command_exists gcloud; then
        run_shell "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg"
        run_shell "echo 'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main' | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null"
        run sudo apt-get update
        apt_install google-cloud-cli
    fi

    if ! command_exists terraform; then
        run_shell "wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg"
        run_shell "echo 'deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com '\"$(lsb_release -cs)\"' main' | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null"
        run sudo apt-get update
        apt_install terraform
    fi

    apt_install ansible
    install_terragrunt
}

install_terragrunt() {
    command_exists terragrunt && { SKIPPED+=("Terragrunt"); return; }
    log_info "Installing Terragrunt"
    run_shell "arch=\$(uname -m); case \"\$arch\" in x86_64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; *) echo unsupported architecture: \"\$arch\" >&2; exit 1 ;; esac; version=\$(curl -fsSL https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest | jq -r .tag_name); curl -fsSL -o /tmp/terragrunt https://github.com/gruntwork-io/terragrunt/releases/download/\${version}/terragrunt_linux_\${arch}; sudo install -m 0755 /tmp/terragrunt /usr/local/bin/terragrunt; rm -f /tmp/terragrunt" || FAILED+=("Terragrunt")
}

install_kubernetes_tools() {
    log_info "Installing Kubernetes tools"

    if ! command_exists kubectl; then
        run_shell "curl -fsSLo /tmp/kubectl https://dl.k8s.io/release/\$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl && rm -f /tmp/kubectl"
    fi

    command_exists helm || run_shell "curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"

    apt_install_if_available kubectx

    if ! command_exists kubecolor; then
        run_shell "ver=\$(curl -fsSL https://kubecolor.github.io/packages/deb/version) && arch=\$(dpkg --print-architecture) && curl -fsSL -o /tmp/kubecolor.deb https://kubecolor.github.io/packages/deb/pool/main/k/kubecolor/kubecolor_\${ver}_\${arch}.deb && sudo dpkg -i /tmp/kubecolor.deb || sudo apt-get -f install -y; rm -f /tmp/kubecolor.deb"
    fi

    install_krew
}

install_krew() {
    if command_exists kubectl-krew || kubectl krew version >/dev/null 2>&1; then
        SKIPPED+=("krew")
        return
    fi
    run_shell "tmpdir=\$(mktemp -d) && cd \"\$tmpdir\" && os=\$(uname | tr '[:upper:]' '[:lower:]') && arch=\$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/') && krew=krew-\${os}_\${arch} && curl -fsSLO https://github.com/kubernetes-sigs/krew/releases/latest/download/\${krew}.tar.gz && tar zxvf \${krew}.tar.gz >/dev/null && ./\${krew} install krew && rm -rf \"\$tmpdir\""
    if ! $SKIP_SHELL_CONFIG; then
        append_line_once 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' "$HOME/.bashrc"
        [[ -f "$HOME/.zshrc" ]] && append_line_once 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' "$HOME/.zshrc"
    fi
}

install_databases() {
    log_info "Installing database clients"
    apt_install mysql-client postgresql-client redis-tools
    apt_install_if_available mongodb-mongosh mongosh
}

install_virtualization() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        log_info "WSL detected; skipping virtualization tools"
        SKIPPED+=("VirtualBox" "Vagrant")
        return
    fi

    log_info "Installing optional virtualization tools"
    apt_install_if_available vagrant virtualbox
}

install_desktop_tools() {
    log_info "Installing desktop development tools"

    if ! command_exists code; then
        run_shell "wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null"
        run_shell "echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main' | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null"
        run sudo apt-get update
        apt_install code
    fi

    apt_install_if_available firefox chromium-browser

    if ! command_exists brave-browser && ! command_exists brave; then
        run_shell "sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"
        run_shell "echo 'deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main' | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null"
        run sudo apt-get update
        apt_install brave-browser
    fi

    if command_exists snap && ! command_exists postman; then
        run sudo snap install postman || FAILED+=("Postman")
    fi
}

configure_shell() {
    local shell_rc="$HOME/.zshrc"
    [[ -f "$shell_rc" ]] || shell_rc="$HOME/.bashrc"
    log_info "Adding shell quality-of-life aliases to $shell_rc"
    append_line_once '# DevTools aliases' "$shell_rc"
    append_line_once 'alias ll="lsd -lah"' "$shell_rc"
    append_line_once 'alias la="lsd -a"' "$shell_rc"
    append_line_once 'alias cat="bat"' "$shell_rc"
    append_line_once 'alias grep="rg"' "$shell_rc"
    append_line_once 'alias k="kubectl"' "$shell_rc"
    command_exists kubecolor && append_line_once 'alias kubectl="kubecolor"' "$shell_rc"
    command_exists direnv && append_line_once 'eval "$(direnv hook bash)"' "$HOME/.bashrc"
    command_exists direnv && [[ -f "$HOME/.zshrc" ]] && append_line_once 'eval "$(direnv hook zsh)"' "$HOME/.zshrc"
}

summary() {
    log_success "Ubuntu/Debian installer finished"
    [[ ${#SKIPPED[@]} -gt 0 ]] && log_warning "Skipped: ${SKIPPED[*]}"
    if [[ ${#FAILED[@]} -gt 0 ]]; then
        log_error "Failures: ${FAILED[*]}"
        exit 1
    fi
    if $SKIP_SHELL_CONFIG; then
        log_info "Log out/in for Docker group membership."
    else
        log_info "Restart your shell. Log out/in for Docker group membership."
    fi
}

main() {
    parse_args "$@"
    confirm
    if ! $DRY_RUN && ! sudo -v; then
        log_error "sudo authentication is required to install packages"
        exit 1
    fi
    prepare_system
    install_core_tools
    install_github_cli
    install_docker
    install_languages
    install_cloud_iac
    install_kubernetes_tools
    install_databases
    install_desktop_tools
    install_virtualization
    if $SKIP_SHELL_CONFIG; then
        log_info "Skipping shell configuration"
    else
        configure_shell
    fi
    summary
}

main "$@"
