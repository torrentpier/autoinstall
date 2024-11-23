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
currOs=$(cat /etc/os-release | grep ^ID | awk -F= '{print $2}')
logsInst="$(dirname "$0")/torrentpier_install.log"

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
    if [[ " ${currOs} " =~ " ${aptOs} " ]]; then
        apt-get -y update 2>&1 | tee -a "$logsInst"
        apt-get -y dist-upgrade 2>&1 | tee -a "$logsInst"

        if [ -f "apt.install.sh" ]; then
            apt-get install -y sudo 2>&1 | tee -a "$logsInst"
            sudo chmod +x apt.install.sh 2>&1 | sudo tee -a "$logsInst"
            sudo ./apt.install.sh 2>&1 | sudo tee -a "$logsInst"
        else
            apt-get install -y sudo jq curl 2>&1 | tee -a "$logsInst"
            sudo mkdir -p /tmp/torrentpier 2>&1 | sudo tee -a "$logsInst"
            curl -s https://api.github.com/repos/SeAnSolovev/torrentpier-autoinstall | jq -r 'map(select(.prerelease == true)) | .[0].zipball_url' | xargs -n 1 curl -L -o /tmp/torrentpier/autoinstall.zip 2>&1 | sudo tee -a "$logsInst"
            sudo unzip -o /tmp/enginegp/enginegp.zip -d /tmp/enginegp/autoinstall 2>&1 | sudo tee -a "$logsInst"
            sudo chmod +x /tmp/enginegp/autoinstall/apt.install.sh 2>&1 | sudo tee -a "$logsInst"
            sudo /tmp/enginegp/autoinstall/apt.install.sh 2>&1 | sudo tee -a "$logsInst"
        fi
    fi
else
    echo "Your system is not supported." 2>&1 | tee -a "$logsInst"
fi