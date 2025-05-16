#!/bin/bash
echo $CAM_DIR
INSTALL_DIR="${CAM_DIR}/prusa-connect-camera-script"
CAM_REPO_URL="https://github.com/nvtkaszpir/prusa-connect-camera-script.git"

# Clone camera repository
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "Cloning camera repository..."
    git clone "$CAM_REPO_URL" "$INSTALL_DIR"
else
    echo "Camera repository already exists, pulling latest changes..."
    cd "$INSTALL_DIR" || exit 1
    git pull
fi
