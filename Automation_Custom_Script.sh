#!/bin/bash

set -e # Exit on any error
# set -x  # Debug mode for visibility

# Define directories
BASE_DIR="/home/dietpi/src"

# function to install apt packages
install_apt_packages() {
    local packages=(
        "rpicam-apps"
        "whiptail"
        "git"
        "uuid"
    )
    local package
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
}

# function to install prusa-connect-camera-script
camera_repo_download() {
    local CAM_DIR="$BASE_DIR/prusa-connect-camera-script"
    local CAM_REPO_URL="https://github.com/nvtkaszpir/prusa-connect-camera-script.git"

    # Clone camera repository
    if [[ ! -d "$CAM_DIR" ]]; then
        echo "Cloning camera repository..."
        git clone "$CAM_REPO_URL" "$CAM_DIR"
    else
        echo "Camera repository already exists, pulling latest changes..."
        cd "$CAM_DIR"
        git pull
    fi

}

# Function to collect printer and camera details using Whiptail
collect_printer_details() {
    max() {
        local max=0; local num
        for num in "$@"; do
            if ((num > max)); then
                max=$num
            fi
        done
        echo "$max"
    }
    min() {
        local min=99999; local num
        for num in "$@"; do
            if ((num < min)); then
                min=$num
            fi
        done
        echo "$min"
    }
    user_cancel(){
        echo "User cancelled input"
        exit 1
    }

    local ENV_FILE="$CAM_DIR/.env"

    echo "Collecting printer and camera details..."

    # Check if .env file already exists
    if [[ -f "$ENV_FILE" ]]; then
        if whiptail --yesno --title \
            "Error: .env already exists!!!" ".env file already exists. Do you want to remove it and rerun the script?" \
            "$(min 10 "$MENU_HEIGHT")" "$(min 60 "$MENU_WIDTH")" \
            3>&1 1>&2 2>&3; then
            rm "$ENV_FILE"
        else
            echo "Exiting script."
            exit 1
        fi
    fi
    # Prompt for printer and camera details
    local PRINTER_ADDRESS="192.168.0.100"                        													# Default value
    local PRUSA_CONNECT_CAMERA_TOKEN="check-Prusa-Connect-Token" 													# Default value
    local CAMERA_COMMAND="rpicam-still"                          													# Default value
    local EXTRA_PARAMS='--immediate --nopreview --mode 4608:2592 --lores-width 0 --lores-height 0 --thumb none -o'	# Default value
    local PADDING=24
    local CHOICE; local MENU_WIDTH; local MENU_HEIGHT; local o1; local o2; local o3; local o4

    # Collect inputs using Whiptail
    while true; do
        # calculate the width of the longest menu item
        MENU_WIDTH=$(max $((${#EXTRA_PARAMS} + PADDING)) \
            $((${#CAMERA_COMMAND} + PADDING)) \
            $((${#PRINTER_ADDRESS} + PADDING)) \
            $((${#PRUSA_CONNECT_CAMERA_TOKEN} + PADDING)))
        MENU_HEIGHT=$(tput lines)
        # Show the menu
        CHOICE=$(whiptail --title "Printer & Camera Setup" --notags --ok-button "Select Option" --menu \
            "Select an option to edit, then choose 'Submit and Continue' to finish." \
            "$(min 20 "$MENU_HEIGHT")" "$MENU_WIDTH" 5 \
            "1" "Printer Address     : $PRINTER_ADDRESS" \
            "2" "Camera Token        : $PRUSA_CONNECT_CAMERA_TOKEN" \
            "3" "Camera Command      : $CAMERA_COMMAND" \
            "4" "Extra Params        : $EXTRA_PARAMS" \
            "5" "Submit and Continue" \
            3>&1 1>&2 2>&3) || user_cancel

        case "$CHOICE" in
        "1")
            while true; do
                # store old value in case of cancel
                local OLD_PRINTER_ADDRESS="$PRINTER_ADDRESS"
                PRINTER_ADDRESS="$(whiptail --inputbox "Enter Printer Address (IPv4):" \
                    "$(min 10 "$MENU_HEIGHT")" \
                    "$(min 60 "$MENU_WIDTH")" \
                    "$PRINTER_ADDRESS" 3>&1 1>&2 2>&3)" \
                    || PRINTER_ADDRESS=$OLD_PRINTER_ADDRESS

                # Validate IPv4 format
                if [[ ! "$PRINTER_ADDRESS" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                    whiptail --msgbox "Invalid IPv4 format! Please enter a valid IPv4 address." \
                        "$(min 10 "$MENU_HEIGHT")" "$(min 60 "$MENU_WIDTH")"
                    continue
                fi
                # Check if each octet is between 0-255
                IFS='.' read -r o1 o2 o3 o4 <<<"$PRINTER_ADDRESS"
                if ((o1 > 255 || o2 > 255 || o3 > 255 || o4 > 255)); then
                    whiptail --msgbox "Invalid IPv4 address! Each octet must be between 0 and 255." \
                        "$(min 10 "$MENU_HEIGHT")" "$(min 60 "$MENU_WIDTH")"
                    continue
                fi

                break # Valid IPv4, exit loop
            done

            ;;
        "2")
            # store old value in case of cancel
            local OLD_PRUSA_CONNECT_CAMERA_TOKEN="$PRUSA_CONNECT_CAMERA_TOKEN"
            PRUSA_CONNECT_CAMERA_TOKEN=$(whiptail --inputbox "Enter Prusa Connect Camera Token:" \
                "$(min 10 "$MENU_HEIGHT")" "$(min 60 "$MENU_WIDTH")" "$PRUSA_CONNECT_CAMERA_TOKEN" 3>&1 1>&2 2>&3) \
                || PRUSA_CONNECT_CAMERA_TOKEN=$OLD_PRUSA_CONNECT_CAMERA_TOKEN
            ;;
        "3")
            # store old value in case of cancel
            local OLD_CAMERA_COMMAND="$CAMERA_COMMAND"
            CAMERA_COMMAND=$(whiptail --inputbox "Enter Camera Command:" "$(min 10 "$MENU_HEIGHT")" \
                "$(min 60 "$MENU_WIDTH")" "$CAMERA_COMMAND" 3>&1 1>&2 2>&3) || CAMERA_COMMAND=$OLD_CAMERA_COMMAND
            ;;
        "4")
            # Escape dashes in the extra params
            EXTRA_PARAMS=${EXTRA_PARAMS/-/\\-}
            EXTRA_PARAMS=${EXTRA_PARAMS// -/ \\-}
            # store old value in case of cancel
            local OLD_EXTRA_PARAMS="$EXTRA_PARAMS"
            EXTRA_PARAMS=$(whiptail --inputbox \
                "Enter Camera Command Extra Params (dashed commands need to be escaped with \\):" \
                "$(min 10 "$MENU_HEIGHT")" "$(min 60 "$MENU_WIDTH")" "$EXTRA_PARAMS" 3>&1 1>&2 2>&3) \
                || EXTRA_PARAMS=$OLD_EXTRA_PARAMS
            EXTRA_PARAMS=${EXTRA_PARAMS//\\/}
            ;;
        "5")
            # Final confirmation
            # Check if any field is empty
            if [[ -z "$PRINTER_ADDRESS" || -z "$PRUSA_CONNECT_CAMERA_TOKEN" || \
                -z "$CAMERA_COMMAND" || -z "$EXTRA_PARAMS" ]]; then
                whiptail --msgbox "All fields are required. Please fill in all details." \
                    "$(min 10 "$MENU_HEIGHT")" "$(min 60 "$MENU_WIDTH")" 3>&1 1>&2 2>&3
                continue
            fi
            local CONFIRMATION=(
                "Confirm your entries:\n"
                "Printer Address: $PRINTER_ADDRESS"
                "Camera Token: $PRUSA_CONNECT_CAMERA_TOKEN"
                "Camera Command: $CAMERA_COMMAND"
                "Extra Params: $EXTRA_PARAMS\n"
                "Continue?"
            )
            local CONFIRMATION_TEXT
            IFS=$'\n' read -r -d '' CONFIRMATION_TEXT <<< "$(printf "%s\n" "${CONFIRMATION[@]}")"
            # Show confirmation dialog
            if whiptail --yesno "$CONFIRMATION_TEXT" "$(min 15 "$MENU_HEIGHT")" \
                "$(min 70 "$MENU_WIDTH")" 3>&1 1>&2 2>&3; then
                break # Exit loop and continue with the script
            fi
            ;;
        esac
    done

    # Save to .env file
    {
        echo "PRINTER_ADDRESS=\"$PRINTER_ADDRESS\""
        echo "PRUSA_CONNECT_CAMERA_TOKEN=\"$PRUSA_CONNECT_CAMERA_TOKEN\""
        echo "PRUSA_CONNECT_CAMERA_FINGERPRINT=\"$(uuidgen)\""
        echo "CAMERA_COMMAND=\"$CAMERA_COMMAND\""
        echo "CAMERA_COMMAND_EXTRA_PARAMS=\"$EXTRA_PARAMS\""
        echo "CAMERA_DEVICE=/dev/video0"
    } >"$ENV_FILE"

    echo "Printer and camera details saved to $ENV_FILE"
}

# function to install and start services
services() {
    local SERVICES_REPO_DIR="$BASE_DIR/services-repo"
    local SERVICES_DIR="$SERVICES_REPO_DIR/services"
    local SCRIPTS_DIR="$SERVICES_REPO_DIR/scripts"
    local SYSTEMD_DIR="/etc/systemd/system"
    local SERVICES_REPO_URL="https://github.com/L10nhunter/QViewOS.git"
    local BIN_DIR="/usr/local/bin"
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

    # cleanup
    echo "Cleaning up..."
    sudo rm -rf "$SERVICES_REPO_DIR"
}

# function to install python 3.12.9
install_python() {
    local PYTHON_VERSION=3.12.9
    local PYTHON_SRC_DIR
    local PYTHON_DOWNLOAD_DIR="/tmp/python"
    echo "Starting Python installation..."

    # Function to check if a package is installed (for Debian-based distros)
    check_package() {
        dpkg -l | grep -qw "$1" || return 1
    }

    check_list() {
        MISSING_PACKAGES=()
        local pkg; local REQUIRED_PACKAGES=("$@")
        for pkg in "${REQUIRED_PACKAGES[@]}"; do
            if ! check_package "$pkg"; then
                MISSING_PACKAGES+=("$pkg")
            fi
        done
        if [[ ${#MISSING_PACKAGES[@]} -ne 0 ]]; then
            return 1
        fi
        return 0
    }

    # List of required packages
    local REQUIRED_PACKAGES=(
        build-essential
        wget
        gcc
        make
        zlib1g-dev
        libnss3-dev
        libssl-dev
        libreadline-dev
        libffi-dev
        libsqlite3-dev
        libuuid1
        libexpat1-dev
    )

    # Install missing dependencies
    echo "Checking for required dependencies..."
    local MISSING_PACKAGES=(); local pkg
    while ! check_list "${REQUIRED_PACKAGES[@]}"; do
        echo "Installing missing packages: ${MISSING_PACKAGES[*]}"
        sudo apt update && sudo apt install -y "${MISSING_PACKAGES[@]}"
    done
    echo "All required dependencies are installed."

    # use wget to download the python tarball
    echo "Downloading Python $PYTHON_VERSION..."
    mkdir -p "$PYTHON_DOWNLOAD_DIR"
    if ! wget  "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz" -P "$PYTHON_DOWNLOAD_DIR"; \
     then
        echo "Failed to download Python $PYTHON_VERSION"
        exit 1
    fi

    # Define the path to the Python tarball
    local PYTHON_TARBALL="$PYTHON_DOWNLOAD_DIR/Python-$PYTHON_VERSION.tgz"

    if [[ -z "$PYTHON_TARBALL" ]]; then
        echo "No Python tarball found in $PYTHON_DOWNLOAD_DIR"
        exit 1
    fi

    # Extract the tarball
    echo "Extracting..."
    tar -zxvf "$PYTHON_TARBALL" -C "$PYTHON_DOWNLOAD_DIR"

    # Get the extracted folder name
    PYTHON_SRC_DIR=$(tar -tf "$PYTHON_TARBALL" | head -1 | cut -d '/' -f1)

    if [[ -z "$PYTHON_SRC_DIR" ]]; then
        echo "Failed to determine extracted folder name."
        exit 1
    fi

    cd "$PYTHON_DOWNLOAD_DIR"

    # Configure, make, and install
    echo "Configuring..."
    ./configure --enable-optimizations --disable-test-modules

    echo "Building (this may take some time)..."
    make "-j$(nproc)" # Uses all available cores

    echo "Installing..."
    sudo make install

    # Verify installation
    local PYTHON_BIN
    PYTHON_BIN=$(find /usr/local/bin -type f -name 'python[0-9]*.[0-9]*' | grep -E 'python3\.12\.9' | tail -n 1)

    if [[ -z "$PYTHON_BIN" ]]; then
        echo "Python installation failed."
        exit 1
    fi

    echo "Python installed at: $PYTHON_BIN"

    # Check for essential Python modules
    echo "Checking for built-in modules..."

    local MODULES=("ctypes" "sqlite3" "ssl" "readline" "uuid" "xml")
    local MISSING=()
    local mod

    for mod in "${MODULES[@]}"; do
        if ! "$PYTHON_BIN" -c "import $mod" 2>/dev/null; then
            MISSING+=("$mod")
            echo "Error: Python is missing the $mod module."
        else
            echo "$mod module is available!"
        fi
    done

    # Install pip
    echo "Installing pip..."
    curl -sS https://bootstrap.pypa.io/get-pip.py | sudo "$PYTHON_BIN"

    # Upgrade pip
    echo "Upgrading pip..."
    sudo "$PYTHON_BIN" -m pip install --upgrade pip

    # cleanup
    echo "Cleaning up..."
    make distclean
    rm -rf "$PYTHON_DOWNLOAD_DIR"

    if [[ ${MISSING[*]} -ne 0 ]]; then
        echo "Python installation complete!"
    else
        echo "Python installation complete, with missing packages: ${MISSING[*]}"
    fi
    "$PYTHON_BIN" --version
    "$PYTHON_BIN" -m pip --version
}

# function to run everything with failures
run_with_failures() {
    local RETRIES=${2-3}
    local COUNT=0
    while [[ $COUNT -lt $RETRIES ]]; do
        if [[ $COUNT -gt 0 ]]; then
            echo "$1 failed. Retry attempt ($((COUNT+1))/$RETRIES)"
        fi
        if "$@" && return 0; then
            echo "$1 completed successfully."
            return 0
        else
            ((COUNT++))
        fi
    done
    echo "$1 failed after $RETRIES attempts."
    exit 1
}

# Ensure base directory exists
mkdir -p "$BASE_DIR"

# Install required apt packages
run_with_failures install_apt_packages

# Download camera repository
run_with_failures camera_repo_download

# Collect printer details
run_with_failures collect_printer_details

# install python3.12.9 and pip, then install requirements
run_with_failures install_python

# start services
run_with_failures services

echo "Auto-start setup completed successfully."
