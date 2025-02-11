#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

echo "🔧 Updating and upgrading system packages..."
sudo apt update && sudo apt upgrade -y

echo "📦 Installing core utilities..."
sudo apt install -y \
    curl wget unzip jq software-properties-common apt-transport-https ca-certificates \
    vim nano git htop fzf tree lsd bat zsh

echo "🐙 Installing GitHub CLI..."
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install -y gh

echo "🐳 Installing Docker CLI (not Docker Desktop)..."
sudo apt install -y docker.io
sudo usermod -aG docker $USER  # Allow running Docker without sudo

echo "☁️ Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "☁️ Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws

echo "🌍 Installing Terraform..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

echo "🐍 Installing Python and Pip..."
sudo apt install -y python3 python3-pip python3-venv
pip3 install --upgrade pip

echo "☸️ Installing Kubernetes CLI (`kubectl`)..."
sudo curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo chmod +x /usr/local/bin/kubectl

echo "🐬 Installing MySQL Client (Workbench not supported on WSL)..."
sudo apt install -y mysql-client

echo "📦 Installing Postman..."
sudo snap install postman

echo "🔐 Installing Bitwarden..."
sudo snap install bitwarden

echo "🦊 Installing Firefox..."
sudo apt install -y firefox

echo "📦 Installing Vagrant..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y vagrant

echo "🎨 Installing Visual Studio Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
sudo apt update && sudo apt install -y code

echo "🔄 Cleaning up..."
sudo apt autoremove -y
sudo apt clean

echo "✅ Installation completed! Restart your terminal or run 'exec zsh' if you installed Zsh."
