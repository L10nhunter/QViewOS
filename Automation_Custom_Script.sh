#!/bin/bash

set -e # Exit on any error
# set -x  # Debug mode for visibility

# Define directories
BASE_DIR="/home/dietpi/src"
CAM_DIR="$BASE_DIR/prusa-connect-camera-script"

# function to run everything with failures
run_with_failures() {
    local RETRIES=${2-3}
    local COUNT=0
    local RESULT
    while [[ $COUNT -lt $RETRIES ]]; do
        if [[ $COUNT -gt 0 ]]; then
            echo "$1 failed. Retry attempt ($((COUNT + 1))/$RETRIES)"
        fi
        "$@"
        RESULT=$?
        if [[ $RESULT -eq 0 ]]; then
            echo "$1 completed successfully."
            return 0
        else
            if [[ $RESULT -eq 1 ]]; then
                ((COUNT++))
            else
                echo "$1 failed. Exiting."
                exit $RESULT
            fi
        fi
    done
    echo "$1 failed after $RETRIES attempts."
    exit 1
}

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please run with sudo."
    exit 1
fi

# Ensure base directory exists
mkdir -p "$BASE_DIR"

# Install required apt packages
packages=("wget" "rpicam-apps" "whiptail" "git" "uuid")
echo "Installing required packages..."
sudo apt update
for package in "${packages[@]}"; do
    if ! dpkg -l | grep -q "$package"; then
        if ! sudo apt install -y "$package"; then
            echo "$package installed"
        else
            echo "$package failed to install!"
            exit 1
        fi
    else
        echo "$package is already installed."
    fi
done

# Download camera repository
run_with_failures "$(bash -s -- "$CAM_DIR" < <(wget -qO - https://raw.githubusercontent.com/L10nhunter/QViewOS/main/bash/camera-repo-download.sh))"

# Collect printer details
run_with_failures "$(bash -s -- "$CAM_DIR" < <(wget -qO - https://raw.githubusercontent.com/L10nhunter/QViewOS/main/bash/collect-printer-details.sh))"

# install python and pip, then install requirements
run_with_failures "$(bash -s < <(wget -qO - https://raw.githubusercontent.com/L10nhunter/QViewOS/main/bash/install-python.sh))"

# start services
run_with_failures "$(bash -s < <(wget -qO - https://raw.githubusercontent.com/L10nhunter/QViewOS/main/bash/install-services.sh))"

echo "Auto-start setup completed successfully."
