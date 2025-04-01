#!/bin/bash
# set -x  # uncomment for spammy logs

# Define paths
PROJECT_DIR="$HOME/Desktop/QView3D"
VENV_DIR="$PROJECT_DIR/.venv"
SERVER_DIR="$PROJECT_DIR/server"
DEPENDENCIES_FILE="$SERVER_DIR/dependencies.txt"

# Check if virtual environment exists, create if necessary
if [[ ! -d "$VENV_DIR" ]]; then
    echo "Virtual environment not found. Creating one in $VENV_DIR..."
    python3 -m venv "$VENV_DIR"

    # Ensure venv was created successfully
    if [[ $? -ne 0 ]]; then
        echo "Failed to create virtual environment." >&2
        exit 1
    fi
fi

# Activate the virtual environment
echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Check and install dependencies if the dependencies.txt file exists
if [[ -f "$DEPENDENCIES_FILE" ]]; then
    echo "Checking dependencies in $DEPENDENCIES_FILE..."
    pip install --upgrade pip  # Ensure pip is up to date
    pip install -r "$DEPENDENCIES_FILE"
else
    echo "Warning: Dependencies file ($DEPENDENCIES_FILE) not found!"
fi

# Navigate to the server directory
cd "$SERVER_DIR" || { echo "Failed to change directory to server"; exit 1; }

# Start the Flask server and log output
echo "Starting QView3D server..."
flask run >> /var/log/qview3d_server.log 2>&1
