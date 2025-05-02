#!/bin/bash

CAM_DIR="${$HOME/prusa-connect-camera-script}"
CAM_REPO_URL="https://github.com/nvtkaszpir/prusa-connect-camera-script.git"

# Clone camera repository
if [[ ! -d "$CAM_DIR" ]]; then
    echo "Cloning camera repository..."
    git clone "$CAM_REPO_URL" "$CAM_DIR"
else
    echo "Camera repository already exists, pulling latest changes..."
    cd "$CAM_DIR" || exit 1
    git pull
fi
