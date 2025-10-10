#!/bin/bash
##
# TorrentPier – Bull-powered BitTorrent tracker engine
#
# @copyright Copyright (c) 2024-present TorrentPier (https://torrentpier.com)
# @copyright Copyright (c) 2024-present Solovev Sergei <inbox@seansolovev.ru>
#
# @link      https://github.com/torrentpier/autoinstall for the canonical source repository
#
# @license   https://github.com/torrentpier/autoinstall/blob/main/LICENSE MIT License
##

# Exit on error, undefined variables
set -e
set -u

# Arrays and variables used
suppOs=("debian" "ubuntu")
currOs=$(grep ^ID= /etc/os-release | awk -F= '{print $2}')
logsInst="/var/log/torrentpier_install.log"
TEMP_PATH="/tmp/torrentpier"

# User verification
if [ "$(whoami)" != "root" ]; then
    echo "It needs to be run under the root user!" 2>&1 | tee -a "$logsInst"
    exit 1
fi

# Checking for system support
foundOs=false
for os in "${suppOs[@]}"; do
    if [[ "$os" == "$currOs" ]]; then
        foundOs=true
        break
    fi
done

# Downloading and running the installation file
if $foundOs; then
    # Required packages
    pkgsList=("curl")

    # Updating tables and packages
    echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
    echo "Updating tables and packages" | tee -a "$logsInst"
    echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
    apt-get -y update 2>&1 | tee -a "$logsInst" > /dev/null
    apt-get -y dist-upgrade 2>&1 | tee -a "$logsInst" > /dev/null

    # Check and installation sudo
    if ! dpkg-query -W -f='${Status}' "sudo" 2>/dev/null | grep -q "install ok installed"; then
        echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
        echo "sudo not installed. Installation in progress..." | tee -a "$logsInst"
        echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
        apt-get install -y sudo 2>&1 | tee -a "$logsInst" > /dev/null
    fi

    # Package installation cycle
    for package in "${pkgsList[@]}"; do
        # Checking for packages and installing packages
        if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            echo "$package not installed. Installation in progress..." | tee -a "$logsInst"
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo apt-get install -y "$package" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        fi
    done

    # Get the directory where install.sh is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    INSTALL_SCRIPT="$SCRIPT_DIR/deb.install.sh"

    # Check if deb.install.sh exists in the current directory
    if [ -f "$INSTALL_SCRIPT" ]; then
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        echo "Using local installation script" | tee -a "$logsInst"
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
    else
        # Preparing a temporary catalog
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        echo "Preparing a temporary catalog" | tee -a "$logsInst"
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        sudo mkdir -p "$TEMP_PATH" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        
        # Downloading the installation script
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        echo "Downloading the installation script" | tee -a "$logsInst"
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        sudo curl -fsSL https://raw.githubusercontent.com/torrentpier/autoinstall/main/deb.install.sh -o "$TEMP_PATH/deb.install.sh" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        INSTALL_SCRIPT="$TEMP_PATH/deb.install.sh"
    fi

    # Starting the automatic installation
    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
    echo "Starting the automatic installation" | tee -a "$logsInst"
    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
    sudo chmod +x "$INSTALL_SCRIPT" 2>&1 | sudo tee -a "$logsInst" > /dev/null
    sudo "$INSTALL_SCRIPT" "$@"
else
    echo "Your system is not supported." 2>&1 | tee -a "$logsInst"
fi
