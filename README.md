# Linux DevTools Installation Scripts

Install a practical Linux development environment on Ubuntu/Debian and Arch-based systems.

## Features

- `install.sh` dispatcher that detects the current distro family
- `install-ubuntu.sh` for Ubuntu, Debian, Linux Mint, Pop!_OS, and Elementary OS
- `install-arch.sh` for Arch, Manjaro, EndeavourOS, and Garuda Linux
- `-y`/`--yes` unattended mode
- `--dry-run` mode to review commands before changing the system
- Idempotent shell alias additions and package installs where package managers support it

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/mdiloreto/linux-ubuntu-install-devtools-script/main/install.sh | bash -s -- -y
```

Manual install:

```bash
git clone https://github.com/mdiloreto/linux-ubuntu-install-devtools-script.git
cd linux-ubuntu-install-devtools-script
./install.sh --dry-run
./install.sh -y
```

Run a specific distro installer:

```bash
./install-ubuntu.sh -y
./install-arch.sh -y
```

## Tool Coverage

The current Arch workstation audit was used as the baseline for the refreshed tool list.

### Core CLI

- Build tools: `gcc`, `make`, `cmake`, `pkg-config`/`pkgconf`, `base-devel` or `build-essential`
- Transfer/archive: `curl`, `wget`, `unzip`, `zip`, `tar`, `gzip`, `bzip2`, `xz`
- Search/data: `ripgrep`, `fd`, `fzf`, `jq`, `yq`
- Editors/shell: `vim`, `neovim`, `nano`, `zsh`, `tmux`, `screen`
- Monitoring/files: `htop`, `btop`, `tree`, `lsd`, `bat`, `ncdu`, `tldr`
- Networking/security: `openssh`, `openssl`, `net-tools`, `dnsutils`/`bind`, `traceroute`
- Workflow helpers: `mise`, `direnv`, `shellcheck`, `shfmt`

### Version Control

- Git
- GitHub CLI (`gh`)

### Languages

- Python 3, pip, venv, pipx, virtualenv
- Python tools via pipx: `pipenv`, `poetry`, `black`, `ruff`, `pytest`, `ipython`
- Node.js, npm, yarn, pnpm
- Go
- Rust via rustup

### Cloud And IaC

- Azure CLI
- AWS CLI v2
- Google Cloud CLI
- Terraform
- Terragrunt
- Ansible

### Containers And Kubernetes

- Docker, Docker Compose, Buildx
- kubectl
- Helm
- k9s
- kubectx/kubens
- kubecolor
- krew plugin manager

### Database Clients

- MySQL client
- PostgreSQL client (`psql`)
- Redis CLI
- MongoDB Compass/mongosh when available for the distro

### Optional Virtualization

- Vagrant
- VirtualBox outside WSL

### Desktop Development Tools

- Visual Studio Code
- Postman
- Firefox
- Chromium
- Brave Browser

## Distribution Notes

### Ubuntu/Debian

- Uses official vendor repositories for GitHub CLI, Docker, Google Cloud CLI, HashiCorp/Terraform, VS Code, and Brave.
- Installs kubectl and Helm from upstream release channels.
- Uses `pipx` for Python CLI tools to avoid system Python conflicts.
- Creates Ubuntu-friendly `fd` and `bat` shims when packages install as `fdfind` and `batcat`.
- Installs Postman through snap when snap is available.

### Arch

- Uses official `pacman` packages first.
- Uses `yay` or `paru` only for AUR-only packages: `google-cloud-cli`, `kubecolor`, `visual-studio-code-bin`, `postman-bin`, `brave-bin`, `mongosh-bin`, `mongodb-compass`, and `vagrant`.
- Installs Python CLI tools through `pipx` to comply with externally managed Python environments.
- Enables Docker with `systemctl enable --now docker` and adds the current user to the Docker group.

## Options

```bash
./install.sh -y            # unattended install
./install.sh --dry-run     # print commands without running them
./install.sh --help        # usage
```

## Post-Install

1. Restart your terminal or source your shell config.
2. Log out and back in so Docker group membership takes effect.
3. Authenticate tools as needed: `gh auth login`, `az login`, `aws configure`, `gcloud auth login`.
4. Review optional tools skipped because a package or AUR helper was unavailable.

## Safety

These scripts install packages and modify shell startup files. Review with `--dry-run` first when running on a new machine.
