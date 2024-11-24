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

clear

# Arrays and variables used
suppOs=("debian" "ubuntu")
aptOs=("debian" "ubuntu")
currOs=$(grep ^ID /etc/os-release | awk -F= '{print $2}')
logsInst="/var/log/torrentpier_install.log"

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
    for os in "${aptOs[@]}"; do
        if [[ "$os" == "$currOs" ]]; then
            # Required packages
            pkgsList=("jq" "curl" "zip" "unzip")

            # Updating tables and packages
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            echo "Updating tables and packages" | tee -a "$logsInst"
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            apt-get -y update 2>&1 | tee -a "$logsInst" > /dev/null
            apt-get -y dist-upgrade 2>&1 | tee -a "$logsInst" > /dev/null

            # Check and installation sudo
            if ! dpkg-query -W -f='${Status}' "sudo" 2>/dev/null | grep -q "install ok installed"; then
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                echo "sudo not installed. Installation in progress..." | tee -a "$logsInst"
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                apt-get install -y sudo 2>&1 | sudo tee -a "$logsInst" > /dev/null
            fi

            # Package installation сycle
            for package in "${pkgsList[@]}"; do
                # Checking for packages and installing packages
                if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "$package not installed. Installation in progress..." | tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo apt-get install -y "$package" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                fi
            done

            # Preparing a temporary catalog
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            echo "Preparing a temporary catalog" | tee -a "$logsInst"
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo mkdir -p /tmp/torrentpier 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo rm -rf /tmp/torrentpier/* 2>&1 | sudo tee -a "$logsInst" > /dev/null

            # Downloading the installation script
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            echo "Downloading the installation script" | tee -a "$logsInst"
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            curl -s https://api.github.com/repos/SeAnSolovev/torrentpier-autoinstall/releases | jq -r 'map(select(.prerelease == true)) | .[0].zipball_url' | xargs -n 1 curl -L -o /tmp/torrentpier/autoinstall.zip 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo unzip -o /tmp/torrentpier/autoinstall.zip -d /tmp/torrentpier 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo mv /tmp/torrentpier/*autoinstall-* /tmp/torrentpier/autoinstall 2>&1 | sudo tee -a "$logsInst" > /dev/null

            # Starting the automatic installation
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            echo "Starting the automatic installation" | tee -a "$logsInst"
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo chmod +x /tmp/torrentpier/autoinstall/apt.install.sh 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo /tmp/torrentpier/autoinstall/apt.install.sh 2>&1 | sudo tee -a "$logsInst"
        fi
    done
else
    echo "Your system is not supported." 2>&1 | tee -a "$logsInst"
fi