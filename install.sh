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
        sudo apt-get -y update
        sudo apt-get -y dist-upgrade

        if [ -f "apt.install.sh" ]; then
            sudo chmod +x install.sh
            sudo ./apt.install.sh
        else
            sudo apt install -y jq curl
            # Coming soon
        fi

    fi
else
    echo "Your system is not supported."
fi