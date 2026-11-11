#!/usr/bin/env bash
set -u -o pipefail

ASSUME_YES=false
DRY_RUN=false
SKIP_SHELL_CONFIG=false
FAILED=()
SKIPPED=()
BREW=brew
UV_PYTHON=""

log_info() { printf '[INFO] %s\n' "$*"; }
log_warning() { printf '[WARN] %s\n' "$*"; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install development apps and CLIs on macOS (Apple Silicon only).
Shell files, login shell, app preferences and Git identity are managed externally.

OPTIONS:
    -y, --yes, --no-confirm    Skip confirmation prompts
    --dry-run                  Print planned commands without running them
    --skip-shell-config        Accepted for parity; macOS always preserves shell config
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
    /bin/bash -o pipefail -c "$*"
}

confirm() {
    $DRY_RUN && return 0
    $ASSUME_YES && return 0
    if [[ ! -t 0 ]]; then
        log_error "Interactive confirmation is unavailable. Re-run with -y to install."
        exit 1
    fi
    read -r -p "Install macOS dev tools? [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]] || exit 0
}

prepare_homebrew() {
    if command_exists brew; then
        BREW="$(command -v brew)"
    elif [[ -x /opt/homebrew/bin/brew ]]; then
        BREW=/opt/homebrew/bin/brew
    else
        log_info "Installing Homebrew from https://brew.sh (requires Xcode Command Line Tools)"
        if $ASSUME_YES; then
            if ! run sudo -n -v; then
                log_error "Unattended Homebrew setup requires sudo access. Run 'sudo -v' in a terminal, then retry with -y."
                return 1
            fi
            export NONINTERACTIVE=1
        fi
        run_shell 'tmpdir=$(mktemp -d) || exit 1
trap '\''rm -rf "$tmpdir"'\'' EXIT
curl --proto "=https" --tlsv1.2 -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$tmpdir/install.sh" &&
/bin/bash "$tmpdir/install.sh"' || return 1
        if ! $DRY_RUN; then
            BREW=/opt/homebrew/bin/brew
            [[ -x "$BREW" ]] || return 1
        fi
    fi
    if ! $DRY_RUN; then
        local prefix
        prefix="$("$BREW" --prefix)" || return 1
        export PATH="$prefix/opt/rustup/bin:$prefix/bin:$prefix/sbin:$PATH"
        export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1
    fi
}

brew_install() {
    local kind="$1" package
    shift
    for package in "$@"; do
        if ! $DRY_RUN && "$BREW" list "$kind" "$package" >/dev/null 2>&1; then
            SKIPPED+=("$package")
        elif ! run "$BREW" install "$kind" "$package"; then
            FAILED+=("Homebrew: $package")
        fi
    done
}

install_core_tools() {
    log_info "Installing core CLI tools"
    brew_install --formula \
        make cmake pkgconf git gh googleworkspace-cli curl wget unzip zip gnu-tar gzip bzip2 xz \
        openssh openssl@3 ca-certificates gnupg jq yq ripgrep fd fzf tree lsd bat \
        vim neovim nano zsh tmux screen htop btop ncdu tlrc bind direnv shellcheck shfmt mise
}

install_languages() {
    log_info "Installing language toolchains and uv-managed Python 3.13"
    brew_install --formula uv node yarn pnpm go rustup
    run rustup default stable || FAILED+=("Rust stable toolchain")
    if ! run uv python install 3.13; then
        FAILED+=("Python 3.13")
        return 1
    fi
    if $DRY_RUN; then
        UV_PYTHON="$HOME/.local/bin/python3.13"
    else
        UV_PYTHON="$(uv python find --managed-python 3.13)" || { FAILED+=("Python 3.13 discovery"); return 1; }
    fi
    if ! run "$UV_PYTHON" -c 'import ssl, xml.parsers.expat'; then
        UV_PYTHON=""
        FAILED+=("Python 3.13 SSL/XML health check")
        return 1
    fi
    local tool
    for tool in pipx virtualenv pipenv poetry black ruff pytest ipython ansible-core azure-cli; do
        run uv tool install --managed-python --python "$UV_PYTHON" "$tool" || FAILED+=("uv tool: $tool")
    done
}

install_shortcut_cli() {
    if command_exists short; then
        SKIPPED+=("Shortcut CLI")
        return 0
    fi
    log_info "Installing Shortcut CLI"
    run npm install -g @shortcut-cli/shortcut-cli || FAILED+=("Shortcut CLI")
}

install_google_cloud() {
    local sdk="$HOME/.local/share/google-cloud-sdk"
    if [[ -z "$UV_PYTHON" ]]; then
        log_error "Google Cloud SDK requires the healthy uv-managed Python 3.13"
        FAILED+=("Google Cloud SDK")
        return 1
    fi
    export CLOUDSDK_PYTHON="$UV_PYTHON"
    if [[ -x "$sdk/bin/gcloud" ]]; then
        SKIPPED+=("Google Cloud SDK")
    elif [[ -e "$sdk" ]]; then
        log_error "$sdk exists without bin/gcloud; inspect it before retrying"
        FAILED+=("Google Cloud SDK")
        return 1
    else
        log_info "Installing the official Google Cloud SDK archive"
        run_shell 'case "$(uname -m)" in
    arm64) arch=arm ;;
    x86_64) arch=x86_64 ;;
    *) exit 1 ;;
esac
tmpdir=$(mktemp -d) || exit 1
trap '\''rm -rf "$tmpdir"'\'' EXIT
curl --proto "=https" --tlsv1.2 -fsSL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-$arch.tar.gz" -o "$tmpdir/gcloud.tar.gz" &&
tar -xzf "$tmpdir/gcloud.tar.gz" -C "$tmpdir" &&
mkdir -p "$HOME/.local/share" &&
mv "$tmpdir/google-cloud-sdk" "$HOME/.local/share/google-cloud-sdk"' || { FAILED+=("Google Cloud SDK"); return 1; }
    fi
    run "$sdk/bin/gcloud" --version || { FAILED+=("Google Cloud SDK health check"); return 1; }
    run "$sdk/bin/gcloud" components install gke-gcloud-auth-plugin --quiet || FAILED+=("GKE auth plugin")
}

install_aws_cli() {
    local aws="$HOME/.local/aws-cli/aws"
    if [[ -x "$aws" ]]; then
        SKIPPED+=("AWS CLI")
    elif [[ -e "$HOME/.local/aws-cli" ]]; then
        log_error "$HOME/.local/aws-cli exists without aws; inspect it before retrying"
        FAILED+=("AWS CLI")
        return 1
    else
        log_info "Installing AWS CLI with the official signature-verifying installer"
        run_shell 'tmpdir=$(mktemp -d) || exit 1
trap '\''rm -rf "$tmpdir"'\'' EXIT
curl --proto "=https" --tlsv1.2 -fsSL https://awscli.amazonaws.com/v2/install.sh -o "$tmpdir/install.sh" &&
XDG_DATA_HOME="$HOME/.local" XDG_BIN_HOME="$HOME/.local/bin" AWS_CLI_INSTALL_SKIP_SIGNATURE_VERIFICATION=false /bin/bash "$tmpdir/install.sh"' || { FAILED+=("AWS CLI"); return 1; }
    fi
    run "$aws" --version || FAILED+=("AWS CLI health check")
}

install_cloud_iac() {
    log_info "Installing cloud and IaC CLIs"
    brew_install --formula hashicorp/tap/terraform terragrunt
    install_google_cloud
    install_aws_cli
}

install_containers_databases() {
    log_info "Installing container, Kubernetes and database clients"
    brew_install --formula docker docker-compose docker-buildx \
        kubernetes-cli helm k9s kubectx kubecolor krew mysql-client libpq redis mongosh
    brew_install --cask orbstack
}

install_herdr() {
    if command_exists herdr || [[ -x "${HERDR_INSTALL_DIR:-$HOME/.local/bin}/herdr" ]]; then
        SKIPPED+=("Herdr")
        return 0
    fi
    brew_install --formula herdr
}

install_desktop_tools() {
    log_info "Installing desktop development tools"
    brew_install --cask ghostty font-ubuntu-mono linearmouse codexbar visual-studio-code \
        postman firefox brave-browser
    install_herdr
}

summary() {
    [[ ${#SKIPPED[@]} -gt 0 ]] && log_info "Already installed: ${SKIPPED[*]}"
    if [[ ${#FAILED[@]} -gt 0 ]]; then
        log_error "Failures: ${FAILED[*]}"
        return 1
    fi
    log_info "macOS installer finished"
    log_info "Use dotfiles for PATH, CLOUDSDK_PYTHON, Docker plugin discovery and app preferences (see README)."
    log_info 'Rustup/cargo/rustc need "$(brew --prefix rustup)/bin" on PATH; configure this through dotfiles.'
    log_info "Open OrbStack once to finish setup, then verify docker info, docker compose version and docker buildx version."
}

main() {
    parse_args "$@"
    if [[ "$(uname -s)" != Darwin ]]; then
        log_error "This installer requires macOS"
        return 1
    fi
    case "$(uname -m)" in
        arm64) ;;
        *) log_error "This macOS installer supports Apple Silicon (arm64) only"; return 1 ;;
    esac
    confirm
    prepare_homebrew || { log_error "Homebrew setup failed; see https://brew.sh"; return 1; }
    install_core_tools
    install_languages
    install_shortcut_cli
    install_cloud_iac
    install_containers_databases
    install_desktop_tools
    $SKIP_SHELL_CONFIG && log_info "--skip-shell-config: preserving externally managed shell configuration"
    summary
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    main "$@"
fi
