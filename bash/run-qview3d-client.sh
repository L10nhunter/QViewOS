#!/bin/bash
# set -x  # uncomment for spammy logs

# Define paths
PROJECT_DIR="$HOME/Desktop/QView3D"
CLIENT_DIR="$PROJECT_DIR/client"
NVM_DIR="$HOME/.config/nvm"

# Function to install NVM
install_nvm() {
    echo "NVM not found. Installing..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
    export NVM_DIR="$HOME/.config/nvm"
    source "$NVM_DIR/nvm.sh"
}


# Check if NVM is installed
if [[ ! -d "$NVM_DIR" ]]; then
    install_nvm
elif ! command -v nvm &>/dev/null; then
    source "$NVM_DIR/nvm.sh"
fi

# Ensure Node.js is installed via NVM
if ! command -v node &>/dev/null; then
    echo "Node.js not found. Installing latest LTS version..."
    nvm install --lts
    nvm use --lts
else
    # Get currently installed version of Node.js
    CURRENT_NODE=$(nvm current)

    # Use the currently installed version
    echo "Using existing Node.js version: $CURRENT_NODE"
    nvm use "$CURRENT_NODE"
fi

# Navigate to client directory
cd "$CLIENT_DIR" || { echo "Failed to change directory to client"; exit 1; }

# Check and update node_modules
if [[ -d "node_modules" ]]; then
    echo "Removing outdated node_modules..."
    rm -rf node_modules
fi

echo "Installing dependencies..."
npm install

# Start Vue app
echo "Starting QView3D client..."
npm run start-vue >> /var/log/qview3d_client.log 2>&1