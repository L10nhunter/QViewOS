#!/bin/bash

set -e # Exit on any error
# set -x  # Debug mode for visibility

# Define repository URLs
CAM_REPO_URL="https://github.com/nvtkaszpir/prusa-connect-camera-script.git"
SERVICES_REPO_URL="https://github.com/L10nhunter/QViewOS.git"

# Define directories
BASE_DIR="/home/dietpi/src"
CAM_DIR="$BASE_DIR/prusa-connect-camera-script"
SERVICES_REPO_DIR="$BASE_DIR/services-repo"
SERVICES_DIR="$SERVICES_REPO_DIR/services"
SCRIPTS_DIR="$SERVICES_REPO_DIR/scripts"
SYSTEMD_DIR="/etc/systemd/system"
BIN_DIR="/usr/local/bin"
ENV_FILE="$CAM_DIR/.env"

# Function to collect printer and camera details using Whiptail
collect_printer_details() {
  echo "Collecting printer and camera details..."

  # Check if .env file already exists
  if [[ -f "$ENV_FILE" ]]; then
    echo "Error: .env file already exists. Please remove it before running this script."
    exit 1
  fi
  # Prompt for printer and camera details
  local PRINTER_ADDRESS
  local PRUSA_CONNECT_CAMERA_TOKEN
  local CAMERA_COMMAND
  local CAMERA_COMMAND_EXTRA_PARAMS

  while true; do
    # Collect inputs using Whiptail
    PRINTER_ADDRESS=$(whiptail --inputbox "Enter Printer Address:" 10 60 "192.168.0.100" 3>&1 1>&2 2>&3)
    PRUSA_CONNECT_CAMERA_TOKEN=$(whiptail --inputbox "Enter Prusa Connect Camera Token:" 10 60 "check-PrusaConnect" 3>&1 1>&2 2>&3)
    CAMERA_COMMAND=$(whiptail --inputbox "Enter Camera Command:" 10 60 "rpicam-still" 3>&1 1>&2 2>&3)
    CAMERA_COMMAND_EXTRA_PARAMS=$(whiptail --inputbox "Enter Camera Command Extra Params:" 10 60 "--immediate --nopreview --mode 4608:2592 --lores-width 0 --lores-height 0 --thumb none -o" 3>&1 1>&2 2>&3)

    # Check if any field is empty
    if [[ -z "$PRINTER_ADDRESS" || -z "$PRUSA_CONNECT_CAMERA_TOKEN" || -z "$CAMERA_COMMAND" || -z "$CAMERA_COMMAND_EXTRA_PARAMS" ]]; then
      whiptail --msgbox "All fields are required. Please fill in all details." 10 60
      continue
    fi

    # If no fields are empty, break the loop
    break
  done

  # Save to .env file
  {
    echo "PRINTER_ADDRESS=\"$PRINTER_ADDRESS\""
    echo "PRUSA_CONNECT_CAMERA_TOKEN=\"$PRUSA_CONNECT_CAMERA_TOKEN\""
    echo "PRUSA_CONNECT_CAMERA_FINGERPRINT=\"$(uuidgen)\""
    echo "CAMERA_COMMAND=\"$CAMERA_COMMAND\""
    echo "CAMERA_COMMAND_EXTRA_PARAMS=\"$CAMERA_COMMAND_EXTRA_PARAMS\""
    echo "CAMERA_DEVICE=/dev/video0"
  } >"$ENV_FILE"

  echo "Printer and camera details saved to $ENV_FILE"
}

services() {
  # Clone services repository
  if [[ ! -d "$SERVICES_REPO_DIR" ]]; then
    echo "Cloning services and scripts repository..."
    git clone "$SERVICES_REPO_URL" "$SERVICES_REPO_DIR"
  else
    echo "Services repository already exists, pulling latest changes..."
    cd "$SERVICES_REPO_DIR"
    git pull
  fi

  local FILE
  local SERVICE

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
}

# Ensure base directory exists
mkdir -p "$BASE_DIR"

# Clone camera repository
if [[ ! -d "$CAM_DIR" ]]; then
  echo "Cloning camera repository..."
  git clone "$CAM_REPO_URL" "$CAM_DIR"
else
  echo "Camera repository already exists, pulling latest changes..."
  cd "$CAM_DIR"
  git pull
fi

# Collect printer details
collect_printer_details

#TODO: install python3.12.9 and pip, then install requirements

# start services
services

echo "Auto-start setup completed successfully."
