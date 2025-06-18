#!/bin/bash
set -e

# Color codes for better output
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m" # No Color

function status() {
  echo -e "${GREEN}[OK]${NC} $1"
}

function error_exit() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
  exit 1
}

# Ensure script is run as non-root but with sudo access
if [ "$EUID" -eq 0 ]; then
  error_exit "Do not run this script as root. Use a user with sudo privileges."
fi

# Update package list
sudo apt update || error_exit "Failed to update package list."

# Install Docker
if ! command -v docker &> /dev/null; then
  sudo apt install -y docker.io || error_exit "Docker installation failed."
  sudo systemctl enable --now docker || error_exit "Failed to enable Docker."
  sudo usermod -aG docker $USER
  status "Docker installed and enabled. Please restart your session or run 'newgrp docker' to use Docker without sudo."
else
  status "Docker already installed."
fi

# Install kubectl
if ! command -v kubectl &> /dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && sudo mv kubectl /usr/local/bin/
  status "kubectl installed."
else
  status "kubectl already installed."
fi

# Install KIND
if ! command -v kind &> /dev/null; then
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64 \
    && chmod +x kind \
    && sudo mv kind /usr/local/bin/
  status "KIND installed."
else
  status "KIND already installed."
fi

# Install Helm
if ! command -v helm &> /dev/null; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || error_exit "Helm installation failed."
  status "Helm installed."
else
  status "Helm already installed."
fi

# Run install-all.sh if available
if [ -f ./scripts/install-all.sh ]; then
  ./scripts/install-all.sh || error_exit "install-all.sh execution failed."
  status "install-all.sh executed successfully."
else
  error_exit "scripts/install-all.sh not found."
fi

status "Bootstrap completed."
