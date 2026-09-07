#!/usr/bin/env bash
set -u -o pipefail

SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
RAW_BASE_URL="${LINUX_DEVTOOLS_RAW_URL:-https://raw.githubusercontent.com/mdiloreto/linux-ubuntu-install-devtools-script/main}"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Linux DevTools installer dispatcher.

OPTIONS:
    -y, --yes, --no-confirm    Skip confirmation prompts
    --dry-run                  Print planned commands without running them
    --skip-shell-config        Do not modify shell startup files or login shell
    -h, --help                 Show this help message

EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ ! -r /etc/os-release ]]; then
    echo "Unsupported system: /etc/os-release not found" >&2
    exit 1
fi

. /etc/os-release

run_installer() {
    local script="$1"
    shift

    if [[ -n "${SCRIPT_DIR}" && -r "${SCRIPT_DIR}/${script}" ]]; then
        exec bash "${SCRIPT_DIR}/${script}" "$@"
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${RAW_BASE_URL}/${script}" | bash -s -- "$@"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "${RAW_BASE_URL}/${script}" | bash -s -- "$@"
    else
        echo "Neither curl nor wget is available to fetch ${script}" >&2
        exit 1
    fi
}

case "${ID}" in
    ubuntu|debian|linuxmint|pop|elementary)
        run_installer install-ubuntu.sh "$@"
        ;;
    arch|manjaro|endeavouros|garuda|omarchy)
        run_installer install-arch.sh "$@"
        ;;
    *)
        echo "Unsupported Linux distribution: ${ID}" >&2
        echo "Supported families: Ubuntu/Debian and Arch." >&2
        exit 1
        ;;
esac
