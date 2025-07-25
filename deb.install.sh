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
currOs=$(grep ^ID= /etc/os-release | awk -F= '{print $2}')
logsInst="/var/log/torrentpier_install.log"
saveFile="/root/torrentpier.cfg"

# TorrentPier auth
torrentPierUser="admin"
torrentPierPass="admin"

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

if $foundOs; then
    # A function to check whether a string is an IP address
    is_ip() {
        local ip="$1"
        # Checking the IP address format (4 numbers from 0 to 255, separated by dots)
        if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            # Checking that each number is in the range from 0 to 255
            IFS='.' read -r -a octets <<< "$ip"
            for octet in "${octets[@]}"; do
                if ((octet < 0 || octet > 255)); then
                    return 1
                fi
            done
            return 0
        else
            return 1
        fi
    }

    # A function to check whether a string is a domain name
    is_domain() {
        local domain="$1"
        # Checking the format of the domain name (consisting of letters, numbers and hyphens separated by dots)
        if [[ "$domain" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]; then
            return 0
        else
            return 1
        fi
    }

    # The cycle of checking and requesting a domain name or IP address
    while true; do
        echo "Enter the domain name or IP address:"
        read -r HOST

        # Checking the entered value
        if [ -n "$HOST" ]; then
            if is_ip "$HOST" || is_domain "$HOST"; then
                break
            else
                echo "Incorrect input. Please enter the correct domain name or IP address."
            fi
        else
            echo "You have not entered a domain name or IP address. Please try again."
        fi
    done

    # NGINX configuration file for TorrentPier
    nginx_torrentpier="server {
    listen 80;
    server_name $HOST;

    root /var/www/torrentpier;
    index index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ /\.(ht|en) {
        return 404;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}"

    # NGINX configuration file for phpMyAdmin
    nginx_phpmyadmin="server {
    listen 9090;
    server_name $HOST;

    root /usr/share/phpmyadmin;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php;
    }

    location ~* ^/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
        root /usr/share/phpmyadmin;
    }

    location ~ /\.ht {
        deny all;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}"

    # Packages for installation, TorrentPier, phpMyAdmin
    pkgsList=("php-fpm" "php-mbstring" "php-bcmath" "php-intl" "php-tidy" "php-xml" "php-xmlwriter" "php-zip" "php-gd" "php-json" "php-curl" "nginx" "mariadb-server" "pwgen" "jq" "curl" "zip" "unzip" "cron")

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
            echo "$package not installed. Installation in progress..." | sudo tee -a "$logsInst"
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo apt-get install -y "$package" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        fi
    done

    passPma="$(pwgen -1Bs 12)"
    dbSql="torrentpier_$(pwgen -1 8)"
    userSql="torrentpier_$(pwgen -1 8)"
    passSql="$(pwgen -1Bs 12)"

    # Installation phpMyAdmin
    if ! dpkg-query -W -f='${Status}' "phpmyadmin" 2>/dev/null | grep -q "install ok installed"; then
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        echo "phpMyAdmin not installed. Installation in progress..." | sudo tee -a "$logsInst"
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null

        sudo debconf-set-selections <<EOF
phpmyadmin phpmyadmin/dbconfig-install boolean true
phpmyadmin phpmyadmin/mysql/app-pass password $passPma
phpmyadmin phpmyadmin/password-confirm password $passPma
phpmyadmin phpmyadmin/reconfigure-webserver multiselect
EOF
        sudo DEBIAN_FRONTEND="noninteractive" apt-get install -y phpmyadmin 2>&1 | sudo tee -a "$logsInst" > /dev/null
        echo -e "$nginx_phpmyadmin" | sudo tee /etc/nginx/sites-available/00-phpmyadmin.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null
        sudo ln -s /etc/nginx/sites-available/00-phpmyadmin.conf /etc/nginx/sites-enabled/ 2>&1 | sudo tee -a "$logsInst" > /dev/null

        # Checking and running the NGINX configuration file
        sudo nginx -t 2>&1 | sudo tee -a "$logsInst" > /dev/null
        sudo systemctl restart nginx 2>&1 | sudo tee -a "$logsInst" > /dev/null
    else
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        echo "phpMyAdmin is already installed on the system. The installation cannot continue." | sudo tee -a "$logsInst"
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        read -rp "Press Enter to complete..."
        exit 1
    fi

    # Installation and setting Composer
    if [ ! -f "/usr/local/bin/composer" ]; then
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        echo "Composer not installed. Installation in progress..." | sudo tee -a "$logsInst"
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        curl -sSL https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer 2>&1 | sudo tee -a "$logsInst" > /dev/null
    fi

    # Installation TorrentPier
    if [ ! -d "/var/www/torrentpier" ]; then
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        echo "TorrentPier not installed. Installation in progress..." | sudo tee -a "$logsInst"
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        # Creating a temporary directory
        sudo mkdir -p /tmp/torrentpier 2>&1 | sudo tee -a "$logsInst" > /dev/null

        # Downloading TorrentPier
        curl -s https://api.github.com/repos/torrentpier/torrentpier/releases | jq -r 'map(select(.prerelease == false and (.tag_name | test("^v2\\.4\\.")))) | .[0].zipball_url' | xargs -n 1 curl -L -o /tmp/torrentpier/torrentpier.zip 2>&1 | sudo tee -a "$logsInst" > /dev/null
        sudo unzip -o /tmp/torrentpier/torrentpier.zip -d /tmp/torrentpier 2>&1 | sudo tee -a "$logsInst" > /dev/null
        sudo mv /tmp/torrentpier/torrentpier-torrentpier-* /var/www/torrentpier 2>&1 | sudo tee -a "$logsInst" > /dev/null

        # Clearing the temporary folder
        sudo rm -rf /tmp/torrentpier/* 2>&1 | sudo tee -a "$logsInst" > /dev/null

        # Installing composer dependencies
        sudo COMPOSER_ALLOW_SUPERUSER=1 composer install --working-dir=/var/www/torrentpier 2>&1 | sudo tee -a "$logsInst" > /dev/null

        # Setting up the configuration file
        sudo mv /var/www/torrentpier/.env.example /var/www/torrentpier/.env 2>&1 | sudo tee -a "$logsInst"
        sed -i "s/APP_CRON_ENABLED=true/APP_CRON_ENABLED=false/g" /var/www/torrentpier/.env 2>&1 | sudo tee -a "$logsInst" > /dev/null
        sed -i "s/DB_DATABASE=torrentpier/DB_DATABASE=$dbSql/g" /var/www/torrentpier/.env 2>&1 | sudo tee -a "$logsInst" > /dev/null
        sed -i "s/DB_USERNAME=root/DB_USERNAME=$userSql/g" /var/www/torrentpier/.env 2>&1 | sudo tee -a "$logsInst" > /dev/null
        sed -i "s/DB_PASSWORD=secret/DB_PASSWORD=$passSql/g" /var/www/torrentpier/.env 2>&1 | sudo tee -a "$logsInst" > /dev/null

        # Creating a user
        sudo mysql -e "CREATE USER '$userSql'@'localhost' IDENTIFIED BY '$passSql';" 2>&1 | sudo tee -a "$logsInst" > /dev/null

        # Creating a database
        sudo mysql -e "CREATE DATABASE $dbSql CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" 2>&1 | sudo tee -a "$logsInst" > /dev/null

        # Granting privileges to the user on the database
        sudo mysql -e "GRANT ALL PRIVILEGES ON $dbSql.* TO '$userSql'@'localhost';" 2>&1 | sudo tee -a "$logsInst" > /dev/null

        # Applying privilege changes
        sudo mysql -e "FLUSH PRIVILEGES;" 2>&1 | sudo tee -a "$logsInst" > /dev/null

        # Import a database
        { sudo cat /var/www/torrentpier/install/sql/mysql.sql | sudo mysql --default-character-set=utf8mb4 -u "$userSql" -p"$passSql" "$dbSql"; } 2>&1 | sudo tee -a "$logsInst" > /dev/null

        # We set the rights to directories and files
        sudo chown -R www-data:www-data /var/www/torrentpier 2>&1 | sudo tee -a "$logsInst" > /dev/null
        sudo find /var/www/torrentpier -type f -exec chmod 644 {} \; 2>&1 | sudo tee -a "$logsInst" > /dev/null
        sudo find /var/www/torrentpier -type d -exec chmod 755 {} \; 2>&1 | sudo tee -a "$logsInst" > /dev/null

        # Setting the CRON task
        { (sudo crontab -l; echo "* * * * * sudo -u www-data php /var/www/torrentpier/cron.php") | sudo crontab -; } 2>&1 | sudo tee -a "$logsInst" > /dev/null
    else
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        echo "TorrentPier is already installed on the system. The installation cannot continue." | sudo tee -a "$logsInst"
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        read -rp "Press Enter to complete..."
        exit 1
    fi

    # Setting up nginx
    if dpkg-query -W -f='${Status}' "nginx" 2>/dev/null | grep -q "install ok installed"; then
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        echo "NGINX is not configured. The setup in progress..." | sudo tee -a "$logsInst"
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        # We remove the default one and create the TorrentPier config
        sudo rm /etc/nginx/sites-enabled/default 2>&1 | sudo tee -a "$logsInst" > /dev/null
        echo -e "$nginx_torrentpier" | sudo tee /etc/nginx/sites-available/01-torrentpier.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null
        sudo ln -s /etc/nginx/sites-available/01-torrentpier.conf /etc/nginx/sites-enabled/ 2>&1 | sudo tee -a "$logsInst" > /dev/null

        # We are testing and running the NGINX config
        sudo nginx -t 2>&1 | sudo tee -a "$logsInst" > /dev/null
        sudo systemctl restart nginx 2>&1 | sudo tee -a "$logsInst" > /dev/null
    else
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        echo "NGINX is not installed. The installation cannot continue." | sudo tee -a "$logsInst"
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        read -rp "Press Enter to complete..."
        exit 1
    fi

    echo "" | sudo tee -a "$saveFile"
    echo "Woah! TorrentPier successfully installed!" | sudo tee -a "$saveFile"
    echo "" | sudo tee -a "$saveFile"
    echo "===================================" | sudo tee -a "$saveFile"
    echo "TorrentPier credentials:" | sudo tee -a "$saveFile"
    echo "-> http://$HOST/" | sudo tee -a "$saveFile"
    echo "-> Username: $torrentPierUser" | sudo tee -a "$saveFile"
    echo "-> Password: $torrentPierPass" | sudo tee -a "$saveFile"
    echo "===================================" | sudo tee -a "$saveFile"
    echo "Database credentials:" | sudo tee -a "$saveFile"
    echo "-> Database name: $dbSql" | sudo tee -a "$saveFile"
    echo "-> Username: $userSql" | sudo tee -a "$saveFile"
    echo "-> Password: $passSql" | sudo tee -a "$saveFile"
    echo "===================================" | sudo tee -a "$saveFile"
    echo "phpMyAdmin credentials:" | sudo tee -a "$saveFile"
    echo "-> http://$HOST:9090/phpmyadmin" | sudo tee -a "$saveFile"
    echo "-> Username: $userSql" | sudo tee -a "$saveFile"
    echo "-> Password: $passSql" | sudo tee -a "$saveFile"
    echo "===================================" | sudo tee -a "$saveFile"
    echo "DO NOT USE IT IF YOU DO NOT KNOW WHAT IT IS INTENDED FOR" | sudo tee -a "$saveFile" > /dev/null
    echo "phpMyAdmin credentials (super admin):" | sudo tee -a "$saveFile" > /dev/null
    echo "-> http://$HOST:9090/phpmyadmin" | sudo tee -a "$saveFile" > /dev/null
    echo "-> Username: phpmyadmin" | sudo tee -a "$saveFile" > /dev/null
    echo "-> Password: $passPma" | sudo tee -a "$saveFile" > /dev/null
    echo "===================================" | sudo tee -a "$saveFile" > /dev/null
    echo "" | sudo tee -a $saveFile
    echo "We are sure that you will be able to create the best tracker available!" | sudo tee -a $saveFile
    echo "Good luck!" | sudo tee -a $saveFile
    echo "" | sudo tee -a $saveFile
else
    echo "Your system is not supported." 2>&1 | tee -a "$logsInst"
fi
