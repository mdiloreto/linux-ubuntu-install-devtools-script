# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Added Omarchy support through the Arch installer, including the official `omarchy-zsh` integration.

### Changed
- The Arch installer now configures zsh as the current user's default login shell.

### Fixed
- Fixed the documented `curl | bash` installation path when `BASH_SOURCE` is unavailable.

## [3.0.0] - 2026-09-04

### Added
- Added `install-arch.sh` for Arch-based development machines.
- Added `install-ubuntu.sh` for Ubuntu/Debian-based development machines.
- Added `install.sh` as a distro-detecting dispatcher.
- Added `--dry-run` support to review commands before making system changes.
- Added audited tool coverage for `neovim`, `mise`, `direnv`, `shellcheck`, `shfmt`, `terragrunt`, Brave, kubecolor, krew, database CLIs, optional virtualization tools, and pipx-managed Python CLIs.

### Changed
- Replaced the broken mixed-distro monolith with focused distro-specific installers.
- Updated Arch installs to prefer official `pacman` packages and reserve AUR helpers for AUR-only tools.
- Updated Ubuntu installs to use vendor repositories for Docker, GitHub CLI, Google Cloud CLI, Terraform, VS Code, and Brave.

### Fixed
- Fixed shell syntax breakages in the previous `install.sh` implementation.
- Fixed Ubuntu `fd`/`bat` command-name differences by adding local shims when needed.

## [2.1.0] - 2025-10-19

### Added
- **Installation status check**: Script now checks which tools are already installed before proceeding
- **Visual summary**: Color-coded display showing installed (✓) and missing (✗) tools
- **Command-line flags**: Support for `-y`, `--yes`, and `--no-confirm` to skip confirmation prompts
- **Help flag**: Added `--help` option to display usage information
- **Smart skip**: Automatically exits if all tools are already installed
- **Better user experience**: Shows count of tools to install vs already installed
- **kubectl QoL Tools integration**: 
  - kubectx (switch between clusters)
  - kubens (switch between namespaces)
  - kubecolor (colorize kubectl output)
  - krew (kubectl plugin manager)
  - kubectl-ai (AI-powered kubectl assistant)
- **Enhanced Zsh setup**:
  - Powerlevel10k theme installation
  - zsh-completions plugin
  - Pre-configured plugins (docker, kubectl, terraform, aws, gcloud, etc.)
  - Custom productivity aliases (ll, la, gs, ga, gc, d, dc, etc.)
  - Automatic .zshrc configuration
  - Backup of original .zshrc

### Changed
- Script now requires explicit confirmation before installation (unless `-y` flag is used)
- Improved logging with more visual feedback
- Better organization of tool categories in status check
- **Python installation on Arch Linux**: Now uses `pipx` for tools to comply with PEP 668 (externally-managed-environment)
- Python tools (pipenv, poetry, black, etc.) installed in isolated environments on Arch

### Fixed
- Script no longer attempts to reinstall already present tools unnecessarily
- **Fixed Python installation error on Arch Linux** (externally-managed-environment)
- Improved error handling for Python package installation

## [2.0.0] - 2025-10-19

### Added
- **Multi-distribution support**: Now supports both Debian-based and Arch-based Linux distributions
- **Automatic distribution detection**: Script automatically detects the Linux distribution
- **Enhanced logging system**: Color-coded output (INFO, SUCCESS, WARNING, ERROR)
- **Additional tools installed**:
  - Node.js with npm, yarn, and pnpm
  - Go programming language
  - Rust programming language
  - Google Cloud CLI
  - Ansible
  - Helm (Kubernetes package manager)
  - k9s (Kubernetes CLI manager)
  - PostgreSQL client
  - Redis CLI
  - MongoDB client
  - Chromium browser
  - Oh My Zsh with popular plugins
  - Additional core utilities (btop, neofetch, ripgrep, fd, exa, etc.)
  - Python development tools (pipenv, poetry, black, flake8, pylint, pytest)
- **Smart installation checks**: Prevents reinstalling existing tools
- **Modular function design**: Each tool category has its own installation function
- **Enhanced error handling**: Better error detection and reporting
- **Comprehensive README**: Detailed documentation with usage examples

### Changed
- Docker installation now uses official Docker CE repository instead of docker.io
- Python installation includes more development tools
- Improved Go installation with proper PATH configuration
- Better Terraform installation with version checking
- Enhanced VS Code installation process

### Fixed
- Fixed GitHub CLI installation with proper GPG key handling
- Fixed Docker group permissions
- Improved cleanup process for both package managers

### Removed
- Removed Bitwarden installation (can be added if needed)
- Removed hardcoded Ubuntu-specific commands

## [1.0.0] - Initial Release

### Added
- Basic Ubuntu/Debian installation script
- Core utilities installation
- GitHub CLI
- Docker
- Azure CLI
- AWS CLI
- Terraform
- Python
- kubectl
- MySQL client
- Postman (via snap)
- Bitwarden (via snap)
- Firefox
- Vagrant
- Visual Studio Code
