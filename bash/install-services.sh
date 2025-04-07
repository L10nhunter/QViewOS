#!/bin/bash
# This script installs the services and scripts for Prusa Connect Camera and QView3D
BASE_DIR="${1-$HOME/src}"
SERVICES_REPO_DIR="$BASE_DIR/services-repo"
SERVICES_DIR="$SERVICES_REPO_DIR/services"
SCRIPTS_DIR="$SERVICES_REPO_DIR/scripts"
SYSTEMD_DIR="/etc/systemd/system"
SERVICES_REPO_URL="https://github.com/L10nhunter/QViewOS.git"
BIN_DIR="/usr/local/bin"
# Clone services repository
if [[ ! -d "$SERVICES_REPO_DIR" ]]; then
    echo "Cloning services and scripts repository..."
    git clone "$SERVICES_REPO_URL" "$SERVICES_REPO_DIR"
else
    echo "Services repository already exists, pulling latest changes..."
    cd "$SERVICES_REPO_DIR" || exit 1
    git pull
fi

# Move systemd service files to /etc/systemd/system/
echo "Moving systemd service files..."
for FILE in "$SERVICES_DIR"/*; do
    if [ -f "$FILE" ]; then
        sudo mv "$SERVICES_DIR/$(basename "$FILE")" "$SYSTEMD_DIR/"
    fi
done

# Move bash scripts to /usr/local/bin/
echo "Moving bash scripts to /usr/local/bin/..."
for FILE in "$SCRIPTS_DIR"/*; do
    if [ -f "$FILE" ]; then
        sudo mv "$SCRIPTS_DIR/$(basename "$FILE")" "$BIN_DIR/"
        sudo chmod +754 "$BIN_DIR/$(basename "$FILE")"
    fi
done

# add services to dietpi-services
echo "Adding services to dietpi-services..."
{
    echo "+ prusa-camera-connect"
    echo "+ qview3d-server"
    echo "+ qview3d-client"
} >>"/boot/dietpi/dietpi-services_include_exclude"

# Reload systemd to recognize new services
sudo systemctl daemon-reload

# Enable and start services
echo "Enabling and starting services..."
for SERVICE in prusa-camera-connect qview3d-server qview3d-client; do
    sudo systemctl enable "$SERVICE.service"
    sudo systemctl start "$SERVICE.service"
done

# cleanup
echo "Cleaning up..."
sudo rm -rf "$SERVICES_REPO_DIR"
