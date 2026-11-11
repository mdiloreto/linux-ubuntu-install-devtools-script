# Linux and macOS DevTools Installation Scripts

Install a practical development environment on Ubuntu/Debian, Arch-based systems (including Omarchy), and macOS.

## Features

- `install.sh` dispatcher that detects the current distro family
- `install-ubuntu.sh` for Ubuntu, Debian, Linux Mint, Pop!_OS, and Elementary OS
- `install-arch.sh` for Arch, Manjaro, EndeavourOS, Garuda Linux, and Omarchy
- `install-macos.sh` for Apple Silicon Macs, compatible with native Bash 3.2
- Herdr on Linux through its official installer and on macOS through Homebrew
- `-y`/`--yes` unattended mode
- `--dry-run` mode to review commands before changing the system
- `--skip-shell-config` mode for systems with externally managed shell files
- Idempotent shell alias additions and package installs where package managers support it

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/mdiloreto/linux-ubuntu-install-devtools-script/main/install.sh | bash -s -- -y --skip-shell-config
```

Manual install:

```bash
git clone https://github.com/mdiloreto/linux-ubuntu-install-devtools-script.git
cd linux-ubuntu-install-devtools-script
./install.sh --dry-run
./install.sh -y --skip-shell-config
```

Run a specific distro installer:

```bash
./install-ubuntu.sh -y
./install-arch.sh -y
./install-macos.sh -y
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
- mongosh when available for the distro

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
- Uses `yay` or `paru` only for AUR-only packages: `google-cloud-cli`, `kubecolor`, `visual-studio-code-bin`, `postman-bin`, `brave-bin`, `mongosh-bin`, and `vagrant`.
- Does not install MongoDB Compass automatically because its AUR dependency chain builds Electron from Chromium sources.
- Installs Python CLI tools through `pipx` to comply with externally managed Python environments.
- Enables Docker with `systemctl enable --now docker` and adds the current user to the Docker group.
- Configures `.zshrc` and sets zsh as the current user's default login shell.
- On Omarchy, installs `omarchy-zsh` to retain the distribution's shell environment and integrations.

### macOS

- Supports Apple Silicon (arm64) only, matching the current official Homebrew bootstrap; Intel Macs are rejected before installation. Uses Homebrew formulae and casks, bootstrapping Homebrew when missing. Install Apple's Command Line Tools first (`xcode-select --install`). For unattended (`-y`) bootstrap, first run `sudo -v` in a terminal: the installer checks `sudo -n -v` and stops with recovery instructions if authorization is unavailable. Interactive bootstrap delegates authentication to Homebrew. Current OrbStack requires macOS 14 or later.
- Installs OrbStack with Docker CLI, Compose and Buildx, plus Kubernetes and database clients. Open OrbStack once after installation to finish its setup. Docker Desktop, VirtualBox, Vagrant and Claude are not installed on macOS.
- Desktop apps include Ghostty, Ubuntu Mono (`font-ubuntu-mono`), LinearMouse, CodexBar, VS Code, Postman, Firefox and Brave. CodexBar shows account quota in the menu bar after authentication. Chromium is omitted because its Homebrew cask is disabled. `tlrc` supplies the `tldr` command.
- Installs **uv-managed Python 3.13** and checks SSL/XML imports before using it. Python CLIs (`pipx`, `virtualenv`, `pipenv`, `poetry`, `black`, `ruff`, `pytest`, `ipython`, `ansible-core`, `azure-cli`) use `uv tool install` with that interpreter. They do not use Homebrew Python, which has exhibited XML-symbol crashes on the reference Mac. Other formulae may still bring Python as a transitive dependency.
- Uses the [official Google Cloud SDK archive](https://docs.cloud.google.com/sdk/docs/downloads-versioned-archives) at `~/.local/share/google-cloud-sdk`, with `CLOUDSDK_PYTHON` set to the healthy uv interpreter during installation. After the SDK health check, installs `gke-gcloud-auth-plugin` through `gcloud components install --quiet`. Archive extraction avoids the SDK installer downloading a different Python or editing shell files.
- Uses the [official AWS installer](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#install-macos), retaining its package-signature verification, at `~/.local/aws-cli` with symlinks in `~/.local/bin`. Existing installations at these SDK paths are health-checked and reused. Installation does not migrate or remove SDKs installed elsewhere.
- Installs Google Workspace CLI (`gws`) through Homebrew's `googleworkspace-cli` formula and Shortcut CLI (`short`) through `npm install -g @shortcut-cli/shortcut-cli`; an existing `short` command is reused.
- **Dotfiles own configuration:** this installer always preserves shell startup files, login shell, Git identity and application preferences. `--skip-shell-config` is accepted for cross-platform parity. Manage PATH entries for Homebrew, `~/.local/bin`, `~/.cargo/bin`, the SDK's `bin`, and Homebrew's `opt/rustup/bin`, `opt/libpq/bin`, `opt/mysql-client/bin` externally. Set `CLOUDSDK_PYTHON` to the result of `uv python find --managed-python 3.13`; select that interpreter for interactive Python through your dotfiles too.
- Configure Docker plugin discovery through dotfiles: `cliPluginsExtraDirs` in `~/.docker/config.json` needs Homebrew's `lib/docker/cli-plugins` directory. Then verify `docker info`, `docker compose version` and `docker buildx version`.

### Herdr (Linux)

The [official installer](https://herdr.dev/install.sh) downloads the platform binary and requires a matching SHA-256 from its HTTPS release manifest before installing. It supports x86_64 and ARM64 and defaults to `~/.local/bin` (or `HERDR_INSTALL_DIR`). Existing binaries on PATH or in the install directory are skipped. It prints PATH advice without editing shell files. The installer and manifest remain trusted upstream inputs; versions are not pinned.

## Options

```bash
./install.sh -y            # unattended install
./install.sh --dry-run     # print commands without running them
./install.sh --skip-shell-config # preserve shell startup files and login shell
./install.sh --help        # usage
```

## Post-Install

1. Unless `--skip-shell-config` was used, open a new login session to start zsh on Arch-based systems, or restart the terminal on Ubuntu/Debian.
2. With `--skip-shell-config`, add any required PATH entries and shell integrations through your external configuration manager.
3. On Linux, log out and back in so Docker group membership takes effect. On macOS, finish OrbStack setup.
4. Authenticate tools as needed: `gh auth login`, `az login`, `aws configure`, `gcloud auth login`.
5. Review optional tools skipped because a package or AUR helper was unavailable.

### Optional Herdr Navigator Restore

If your managed Herdr configuration enables Navigator, restore its pinned plugin explicitly after installation. Building it requires Cargo; on macOS, Homebrew's keg-only Rust proxies at `$(brew --prefix rustup)/bin` must be on PATH. The installer does not install plugins automatically.

```bash
herdr plugin install thanhdat77/herdr-navigator --ref v0.3.3 --yes
```

## Safety

These scripts install packages; Linux shell setup is optional with `--skip-shell-config`, and macOS configuration is always external. Review a local checkout with `--dry-run` first. Dry-runs need no confirmation and execute no install/download commands; a standalone dispatcher prints the remote installer URL instead of downloading it. This reproduces the tool selection, not a version-locked environment: package managers and vendor installers select current releases.

## Installer Checks

Run `/bin/bash .ci/check-installers.sh` for syntax and isolated stub-based checks (including native Bash 3.2 on macOS). They cover dispatch/argument forwarding, dry-run side effects, Herdr idempotence, failure reporting, Python runtime selection, and SDK paths. No real packages are installed; clean-machine installation and GUI onboarding need separate validation.
