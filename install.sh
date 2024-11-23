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
            apt-get -y update 2>&1 | tee -a "$logsInst"
            apt-get -y dist-upgrade 2>&1 | tee -a "$logsInst"

            apt-get install -y sudo jq curl zip unzip 2>&1 | tee -a "$logsInst"

            sudo mkdir -p /tmp/torrentpier 2>&1 | sudo tee -a "$logsInst"
            sudo rm -rf /tmp/torrentpier/* 2>&1 | sudo tee -a "$logsInst"

            curl -s https://api.github.com/repos/SeAnSolovev/torrentpier-autoinstall/releases | jq -r 'map(select(.prerelease == true)) | .[0].zipball_url' | xargs -n 1 curl -L -o /tmp/torrentpier/autoinstall.zip 2>&1 | sudo tee -a "$logsInst"
            sudo unzip -o /tmp/torrentpier/autoinstall.zip -d /tmp/torrentpier 2>&1 | sudo tee -a "$logsInst"
            sudo mv /tmp/torrentpier/*autoinstall-* /tmp/torrentpier/autoinstall 2>&1 | sudo tee -a "$logsInst"

            sudo chmod +x /tmp/torrentpier/autoinstall/apt.install.sh 2>&1 | sudo tee -a "$logsInst"
            sudo /tmp/torrentpier/autoinstall/apt.install.sh 2>&1 | sudo tee -a "$logsInst"
        fi
    done
else
    echo "Your system is not supported." 2>&1 | tee -a "$logsInst"
fi