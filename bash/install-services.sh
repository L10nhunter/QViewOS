#!/bin/bash
# This script installs the services and scripts for Prusa Connect Camera and QView3D
SERVICES_REPO_BASE_URL="https://raw.githubusercontent.com/L10nhunter/QViewOS/refs/heads/main/"
SERVICES_URL="$SERVICES_REPO_BASE_URL/services"
SCRIPTS_URL="$SERVICES_REPO_BASE_URL/bash"
SYSTEMD_DIR="/etc/systemd/system"
BIN_DIR="/usr/local/bin"

for_all_services() {
    local SERVICE
    for SERVICE in prusa-camera-connect qview3d-server qview3d-client; do
        "$1" "$SERVICE"
    done
}

for_all_scripts() {
    local SCRIPT
    for SCRIPT in run-qview3d-server run-qview3d-client; do
        "$1" "$SCRIPT.sh"
    done
}

# download services from repo with wget
download_service() {
    echo "Downloading $1...";
    if ! wget "$SERVICES_URL/$1.service" -O "$SYSTEMD_DIR/"; then
        echo "Failed to download $1";
        exit 1;
    fi
}

enable_and_start_service() {
    local SERVICE="$1"
    sudo systemctl enable "$SERVICE.service"
    sudo systemctl start "$SERVICE.service"
}

add_service_to_dietpi_services() {
    local SERVICE="$1"
    # Check if the service is already in dietpi-services
    if grep -q "$SERVICE" "/boot/dietpi/.dietpi-services_include_exclude"; then
        return
    fi
    { echo "+ $SERVICE"; } >>"/boot/dietpi/.dietpi-services_include_exclude"
}

# download bash scripts from repo with wget
download_script() {
    if ! sudo wget "$SCRIPTS_URL/$1" -O "$BIN_DIR/"; then
        echo "Failed to download $1";
        exit 1;
    fi
    if ! sudo chmod 754 "$BIN_DIR/$1"; then
        echo "Failed to set permissions for $1";
        exit 1;
    fi
}

# download services
echo "Downloading services..."
for_all_services download_service

# download bash scripts
echo "Downloading bash scripts..."
for_all_scripts download_script

# add services to dietpi-services
echo "Adding services to dietpi-services..."
for_all_services add_service_to_dietpi_services

# Reload systemd to recognize new services
sudo systemctl daemon-reload

# Enable and start services
echo "Enabling and starting services..."
for_all_services enable_and_start_service
