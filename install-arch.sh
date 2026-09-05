#!/usr/bin/env bash
set -u -o pipefail

ASSUME_YES=false
DRY_RUN=false
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

Install a practical Linux development toolchain on Arch-based systems.

OPTIONS:
    -y, --yes, --no-confirm    Skip confirmation prompts
    --dry-run                  Print planned commands without running them
    -h, --help                 Show this help message

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes|--no-confirm) ASSUME_YES=true ;;
            --dry-run) DRY_RUN=true ;;
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

pacman_install() {
    local packages=("$@")
    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi
    if ! run sudo pacman -S --needed --noconfirm "${packages[@]}"; then
        FAILED+=("pacman: ${packages[*]}")
        return 1
    fi
}

aur_install() {
    local packages=("$@")
    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi
    if command_exists yay; then
        run yay -S --needed --noconfirm "${packages[@]}" || FAILED+=("AUR: ${packages[*]}")
    elif command_exists paru; then
        run paru -S --needed --noconfirm "${packages[@]}" || FAILED+=("AUR: ${packages[*]}")
    else
        log_warning "AUR helper missing; skipping AUR packages: ${packages[*]}"
        SKIPPED+=("${packages[@]}")
    fi
}

confirm() {
    $ASSUME_YES && return 0
    if [[ ! -t 0 ]]; then
        log_error "Interactive confirmation is unavailable. Re-run with -y to install."
        exit 1
    fi
    read -r -p "Install Arch dev tools? [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]] || exit 0
}

prepare_system() {
    log_info "Updating pacman package database"
    run sudo pacman -Syu --noconfirm
}

install_core_tools() {
    log_info "Installing core CLI tools"
    pacman_install \
        base-devel make cmake pkgconf \
        git curl wget unzip zip tar gzip bzip2 xz \
        openssh openssl ca-certificates gnupg \
        jq yq ripgrep fd fzf tree lsd bat \
        vim neovim nano zsh tmux screen \
        htop btop ncdu tldr net-tools bind traceroute direnv mise \
        shellcheck shfmt
}

install_languages() {
    log_info "Installing language toolchains"
    pacman_install python python-pip python-pipx python-virtualenv nodejs npm yarn pnpm go

    if ! command_exists rustc; then
        pacman_install rustup
        run rustup default stable || true
    fi

    if command_exists pipx; then
        run python -m pipx ensurepath || true
        for tool in pipenv poetry black ruff pytest ipython; do
            command_exists "$tool" || run pipx install "$tool" || true
        done
    fi
}

install_cloud_iac() {
    log_info "Installing cloud and IaC CLIs"
    pacman_install github-cli azure-cli aws-cli terraform terragrunt ansible
    aur_install google-cloud-cli
}

install_docker() {
    log_info "Installing Docker"
    pacman_install docker docker-compose docker-buildx
    run sudo systemctl enable --now docker || FAILED+=("Docker service")
    run sudo usermod -aG docker "$USER" || true
}

install_kubernetes_tools() {
    log_info "Installing Kubernetes tools"
    pacman_install kubectl helm k9s kubectx
    aur_install kubecolor
    install_krew
}

install_krew() {
    if command_exists kubectl-krew || kubectl krew version >/dev/null 2>&1; then
        SKIPPED+=("krew")
        return
    fi
    run_shell "tmpdir=\$(mktemp -d) && cd \"\$tmpdir\" && os=\$(uname | tr '[:upper:]' '[:lower:]') && arch=\$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/') && krew=krew-\${os}_\${arch} && curl -fsSLO https://github.com/kubernetes-sigs/krew/releases/latest/download/\${krew}.tar.gz && tar zxvf \${krew}.tar.gz >/dev/null && ./\${krew} install krew && rm -rf \"\$tmpdir\""
    append_line_once 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' "$HOME/.zshrc"
    append_line_once 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' "$HOME/.bashrc"
}

install_databases() {
    log_info "Installing database clients"
    pacman_install mariadb-clients postgresql-libs redis
    aur_install mongosh-bin mongodb-compass
}

install_virtualization() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        log_info "WSL detected; skipping virtualization tools"
        SKIPPED+=("VirtualBox" "Vagrant")
        return
    fi

    log_info "Installing optional virtualization tools"
    pacman_install virtualbox virtualbox-host-dkms
    aur_install vagrant
}

install_desktop_tools() {
    log_info "Installing desktop development tools"
    pacman_install firefox chromium
    aur_install visual-studio-code-bin postman-bin brave-bin
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
    command_exists mise && append_line_once 'eval "$(mise activate zsh)"' "$HOME/.zshrc"
}

summary() {
    log_success "Arch installer finished"
    [[ ${#SKIPPED[@]} -gt 0 ]] && log_warning "Skipped: ${SKIPPED[*]}"
    if [[ ${#FAILED[@]} -gt 0 ]]; then
        log_error "Failures: ${FAILED[*]}"
        exit 1
    fi
    log_info "Restart your shell. Log out/in for Docker group membership."
}

main() {
    parse_args "$@"
    confirm
    $DRY_RUN || sudo -v
    prepare_system
    install_core_tools
    install_languages
    install_cloud_iac
    install_docker
    install_kubernetes_tools
    install_databases
    install_desktop_tools
    install_virtualization
    configure_shell
    summary
}

main "$@"
