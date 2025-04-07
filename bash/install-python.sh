#!/bin/bash
PYTHON_VERSION=3.12.9
PYTHON_DOWNLOAD_DIR="/tmp/python"


# function to install pip if not installed
install_pip() {
    if "$PYTHON_BIN" -v pip &>/dev/null; then
        echo "pip is already installed."
    else
        echo "pip is not installed. Installing pip..."
        wget https://bootstrap.pypa.io/get-pip.py | sudo "$PYTHON_BIN"
    fi
    # Upgrade pip
    echo "Upgrading pip..."
    sudo "$PYTHON_BIN" -m pip install --upgrade pip
    return 0
}

# Function to check if a package is installed (for Debian-based distros)
check_package() {
    dpkg -l | grep -qw "$1" || return 1
}

# Function to check if a list of packages are installed
check_list() {
    MISSING_PACKAGES=()
    local pkg
    local REQUIRED_PACKAGES=("$@")
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

# Function to check for built-in modules
check_modules() {
    echo "Checking for built-in modules..."
    local MODULES=("ctypes" "sqlite3" "gzip" "ssl" "readline" "uuid" "xml")
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
}

# Function to check if Python is installed
python_install_check() {
    local VERB=${1-"installed"}
    # Verify installation
    if ! $(which python${PYTHON_VERSION%.*}) --version 2>&1 | grep -q "Python $PYTHON_VERSION"; then
        return 1
    fi

    PYTHON_BIN=$(which python${PYTHON_VERSION%.*})

    if [[ "/usr/local/bin/python3\.12" != "$PYTHON_BIN" ]]; then
        echo "Python $VERB in an unexpected location, but found at $PYTHON_BIN"
    else
        echo "Python $VERB at: $PYTHON_BIN"
    fi

    # Check for essential Python modules
    check_modules
    # Install and upgrade pip
    install_pip
}

# Check if Python is already installed
if python_install_check found; then
    PYTHON_BIN=$(which python${PYTHON_VERSION%.*})
    echo "Python $PYTHON_VERSION is already installed."
    return 0
fi

echo "Starting Python installation..."

# List of required packages
REQUIRED_PACKAGES=(
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
MISSING_PACKAGES=()
while ! check_list "${REQUIRED_PACKAGES[@]}"; do
    echo "Installing missing packages: ${MISSING_PACKAGES[*]}"
    sudo apt update && sudo apt install -y "${MISSING_PACKAGES[@]}"
done
echo "All required dependencies are installed."

# use wget to download the python tarball
echo "Downloading Python $PYTHON_VERSION..."
mkdir -p "$PYTHON_DOWNLOAD_DIR"
if ! wget "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz" -P "$PYTHON_DOWNLOAD_DIR"; then
    echo "Failed to download Python $PYTHON_VERSION"
    exit 1
fi

# Define the path to the Python tarball
PYTHON_TARBALL="$PYTHON_DOWNLOAD_DIR/Python-$PYTHON_VERSION.tgz"

if [[ -z "$PYTHON_TARBALL" ]]; then
    echo "No Python tarball found in $PYTHON_DOWNLOAD_DIR"
    exit 1
fi

# Extract the tarball
echo "Extracting..."
tar -zxvf "$PYTHON_TARBALL" -C "$PYTHON_DOWNLOAD_DIR"

# Get the extracted folder name
PYTHON_SRC_DIR="$PYTHON_DOWNLOAD_DIR/Python-$PYTHON_VERSION"

if [[ -z "$PYTHON_SRC_DIR" ]]; then
    echo "Failed to determine extracted folder name."
    exit 1
fi

cd "$PYTHON_SRC_DIR" || exit 1

# Configure, make, and install
echo "Configuring..."
./configure --enable-optimizations --disable-test-modules

echo "Building (this may take some time)..."
make "-j$(nproc)" # Uses all available cores

echo "Installing..."
sudo make install

# Check if Python was installed successfully
if ! python_install_check installed; then
    echo "Python installation failed."
    exit 1
fi

# cleanup
echo "Cleaning up..."
make distclean
rm -rf "$PYTHON_DOWNLOAD_DIR"

"$PYTHON_BIN" --version
pip --version

if [[ ${MISSING[*]} -eq 0 ]]; then
    echo "Python installation complete!"
else
    if [[ "${MISSING[*]}" =~ "ctypes" || "${MISSING[*]}" =~ "sqlite3" || "${MISSING[*]}" =~ "gzip" ]]; then
        echo "Python installation complete, but missing modules: ${MISSING[*]}. At least some of these are required for QView3D to work."
    else
        echo "Python installation complete, with missing packages: ${MISSING[*]}. These should not be required."
    fi
fi
