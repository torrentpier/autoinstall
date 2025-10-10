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

# Default values
WEB_SERVER="nginx"
TP_VERSION="v2.4"
SSL_ENABLE="auto"
SSL_EMAIL=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --webserver)
            WEB_SERVER="$2"
            shift 2
            ;;
        --version)
            TP_VERSION="$2"
            shift 2
            ;;
        --ssl)
            SSL_ENABLE="$2"
            shift 2
            ;;
        --email)
            SSL_EMAIL="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --webserver <nginx|apache|caddy>  Choose web server (default: nginx)"
            echo "  --version <v2.4|v2.8>              Choose TorrentPier version (default: v2.4)"
            echo "  --ssl <auto|yes|no>                Enable SSL/TLS (default: auto - only for domains)"
            echo "  --email <email@example.com>        Email for SSL certificate (required if domain is used)"
            echo "  --help                             Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate web server choice
if [[ ! "$WEB_SERVER" =~ ^(nginx|apache|caddy)$ ]]; then
    echo "Error: Invalid web server. Choose: nginx, apache, or caddy"
    exit 1
fi

# Validate version choice
if [[ ! "$TP_VERSION" =~ ^(v2\.4|v2\.8)$ ]]; then
    echo "Error: Invalid version. Choose: v2.4 or v2.8"
    exit 1
fi

# Validate SSL choice
if [[ ! "$SSL_ENABLE" =~ ^(auto|yes|no)$ ]]; then
    echo "Error: Invalid SSL option. Choose: auto, yes, or no"
    exit 1
fi

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

    # Determine if SSL should be enabled
    USE_SSL=false
    if is_domain "$HOST"; then
        # It's a domain, check SSL settings
        if [ "$SSL_ENABLE" = "auto" ] || [ "$SSL_ENABLE" = "yes" ]; then
            USE_SSL=true
            
            # Request email if not provided
            if [ -z "$SSL_EMAIL" ]; then
                while true; do
                    echo "Enter your email for SSL certificate (Let's Encrypt):"
                    read -r SSL_EMAIL
                    if [[ "$SSL_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                        break
                    else
                        echo "Incorrect email format. Please try again."
                    fi
                done
            fi
            
            echo "===================================" 2>&1 | tee -a "$logsInst"
            echo "SSL will be automatically configured for domain: $HOST" | tee -a "$logsInst"
            echo "Email for certificates: $SSL_EMAIL" | tee -a "$logsInst"
            echo "===================================" 2>&1 | tee -a "$logsInst"
        fi
    else
        # It's an IP address
        if [ "$SSL_ENABLE" = "yes" ]; then
            echo "===================================" 2>&1 | tee -a "$logsInst"
            echo "Warning: SSL cannot be automatically configured for IP addresses." | tee -a "$logsInst"
            echo "SSL will be disabled." | tee -a "$logsInst"
            echo "===================================" 2>&1 | tee -a "$logsInst"
        fi
        USE_SSL=false
    fi

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
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
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
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}"

    # Apache configuration file for TorrentPier
    apache_torrentpier="<VirtualHost *:80>
    ServerName $HOST
    DocumentRoot /var/www/torrentpier

    <Directory /var/www/torrentpier>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \\.php$>
        SetHandler \"proxy:unix:/run/php/php8.4-fpm.sock|fcgi://localhost\"
    </FilesMatch>

    ErrorLog \${APACHE_LOG_DIR}/torrentpier_error.log
    CustomLog \${APACHE_LOG_DIR}/torrentpier_access.log combined
</VirtualHost>"

    # Apache configuration file for phpMyAdmin
    apache_phpmyadmin="<VirtualHost *:9090>
    ServerName $HOST
    DocumentRoot /usr/share/phpmyadmin

    <Directory /usr/share/phpmyadmin>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \\.php$>
        SetHandler \"proxy:unix:/run/php/php8.4-fpm.sock|fcgi://localhost\"
    </FilesMatch>

    ErrorLog \${APACHE_LOG_DIR}/phpmyadmin_error.log
    CustomLog \${APACHE_LOG_DIR}/phpmyadmin_access.log combined
</VirtualHost>"

    # Caddy configuration file (SSL automatic if domain is used)
    if [ "$USE_SSL" = true ]; then
        caddy_config="$HOST {
    root * /var/www/torrentpier
    encode gzip
    php_fastcgi unix//run/php/php8.4-fpm.sock
    file_server
    tls $SSL_EMAIL
}

$HOST:9090 {
    root * /usr/share/phpmyadmin
    encode gzip
    php_fastcgi unix//run/php/php8.4-fpm.sock
    file_server
    tls $SSL_EMAIL
}"
    else
        caddy_config="$HOST {
    root * /var/www/torrentpier
    encode gzip
    php_fastcgi unix//run/php/php8.4-fpm.sock
    file_server
}

$HOST:9090 {
    root * /usr/share/phpmyadmin
    encode gzip
    php_fastcgi unix//run/php/php8.4-fpm.sock
    file_server
}"
    fi

    # Packages for installation, TorrentPier, phpMyAdmin
    # Base packages (PHP 8.4)
    pkgsList=("php8.4-fpm" "php8.4-mbstring" "php8.4-bcmath" "php8.4-intl" "php8.4-tidy" "php8.4-xml" "php8.4-zip" "php8.4-gd" "php8.4-curl" "php8.4-mysql" "mariadb-server" "pwgen" "jq" "curl" "zip" "unzip" "cron")
    
    # Add web server specific packages
    case "$WEB_SERVER" in
        nginx)
            pkgsList+=("nginx")
            if [ "$USE_SSL" = true ]; then
                pkgsList+=("certbot" "python3-certbot-nginx")
            fi
            ;;
        apache)
            pkgsList+=("apache2" "libapache2-mod-fcgid")
            if [ "$USE_SSL" = true ]; then
                pkgsList+=("certbot" "python3-certbot-apache")
            fi
            ;;
        caddy)
            pkgsList+=("debian-keyring" "debian-archive-keyring" "apt-transport-https")
            # Caddy has built-in automatic HTTPS, no need for certbot
            ;;
    esac

    # Updating tables and packages
    echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
    echo "Updating tables and packages" | tee -a "$logsInst"
    echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
    apt-get -y update 2>&1 | tee -a "$logsInst" > /dev/null
    apt-get -y dist-upgrade 2>&1 | tee -a "$logsInst" > /dev/null

    # Add PHP 8.4 repository
    echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
    echo "Adding PHP 8.4 repository" | tee -a "$logsInst"
    echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
    apt-get install -y lsb-release ca-certificates apt-transport-https software-properties-common gnupg2 2>&1 | tee -a "$logsInst" > /dev/null
    curl -sSL https://packages.sury.org/php/apt.gpg -o /etc/apt/trusted.gpg.d/php.gpg 2>&1 | tee -a "$logsInst" > /dev/null
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list 2>&1 | tee -a "$logsInst" > /dev/null
    apt-get -y update 2>&1 | tee -a "$logsInst" > /dev/null

    # Check and installation sudo
    if ! dpkg-query -W -f='${Status}' "sudo" 2>/dev/null | grep -q "install ok installed"; then
        echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
        echo "sudo not installed. Installation in progress..." | tee -a "$logsInst"
        echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
        apt-get install -y sudo 2>&1 | tee -a "$logsInst" > /dev/null
    fi

    # Install Caddy repository if needed
    if [ "$WEB_SERVER" == "caddy" ]; then
        if ! dpkg-query -W -f='${Status}' "caddy" 2>/dev/null | grep -q "install ok installed"; then
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            echo "Adding Caddy repository..." | sudo tee -a "$logsInst"
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>&1 | sudo tee -a "$logsInst" > /dev/null
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo apt-get update 2>&1 | sudo tee -a "$logsInst" > /dev/null
        fi
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
    
    # Install Caddy separately
    if [ "$WEB_SERVER" == "caddy" ]; then
        if ! dpkg-query -W -f='${Status}' "caddy" 2>/dev/null | grep -q "install ok installed"; then
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            echo "caddy not installed. Installation in progress..." | sudo tee -a "$logsInst"
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo apt-get install -y caddy 2>&1 | sudo tee -a "$logsInst" > /dev/null
        fi
    fi

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
        
        # Configure phpMyAdmin for selected web server
        case "$WEB_SERVER" in
            nginx)
                echo -e "$nginx_phpmyadmin" | sudo tee /etc/nginx/sites-available/00-phpmyadmin.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null
                sudo ln -s /etc/nginx/sites-available/00-phpmyadmin.conf /etc/nginx/sites-enabled/ 2>&1 | sudo tee -a "$logsInst" > /dev/null
                sudo nginx -t 2>&1 | sudo tee -a "$logsInst" > /dev/null
                sudo systemctl restart nginx 2>&1 | sudo tee -a "$logsInst" > /dev/null
                ;;
            apache)
                echo -e "$apache_phpmyadmin" | sudo tee /etc/apache2/sites-available/00-phpmyadmin.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null
                sudo a2ensite 00-phpmyadmin 2>&1 | sudo tee -a "$logsInst" > /dev/null
                sudo apache2ctl configtest 2>&1 | sudo tee -a "$logsInst" > /dev/null
                sudo systemctl restart apache2 2>&1 | sudo tee -a "$logsInst" > /dev/null
                ;;
            caddy)
                # Caddy config already includes phpMyAdmin
                sudo systemctl reload caddy 2>&1 | sudo tee -a "$logsInst" > /dev/null
                ;;
        esac
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

        # Downloading TorrentPier based on selected version
        if [ "$TP_VERSION" == "v2.4" ]; then
            curl -s https://api.github.com/repos/torrentpier/torrentpier/releases | jq -r 'map(select(.prerelease == false and (.tag_name | test("^v2\\.4\\.")))) | .[0].zipball_url' | xargs -n 1 curl -L -o /tmp/torrentpier/torrentpier.zip 2>&1 | sudo tee -a "$logsInst" > /dev/null
        elif [ "$TP_VERSION" == "v2.8" ]; then
            curl -s https://api.github.com/repos/torrentpier/torrentpier/releases | jq -r 'map(select(.prerelease == false and (.tag_name | test("^v2\\.8\\.")))) | .[0].zipball_url' | xargs -n 1 curl -L -o /tmp/torrentpier/torrentpier.zip 2>&1 | sudo tee -a "$logsInst" > /dev/null
        fi
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
        { (sudo crontab -l; echo "*/10 * * * * sudo -u www-data php /var/www/torrentpier/cron.php") | sudo crontab -; } 2>&1 | sudo tee -a "$logsInst" > /dev/null
    else
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        echo "TorrentPier is already installed on the system. The installation cannot continue." | sudo tee -a "$logsInst"
        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
        read -rp "Press Enter to complete..."
        exit 1
    fi

    # Setting up web server
    case "$WEB_SERVER" in
        nginx)
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

                # Setup SSL if enabled
                if [ "$USE_SSL" = true ]; then
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "Obtaining SSL certificate for NGINX..." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo certbot --nginx -d "$HOST" --non-interactive --agree-tos --email "$SSL_EMAIL" --redirect 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    
                    # Setup auto-renewal
                    if ! sudo crontab -l 2>/dev/null | grep -q "certbot renew"; then
                        (sudo crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | sudo crontab - 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    fi
                fi
            else
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                echo "NGINX is not installed. The installation cannot continue." | sudo tee -a "$logsInst"
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                read -rp "Press Enter to complete..."
                exit 1
            fi
            ;;
        apache)
            if dpkg-query -W -f='${Status}' "apache2" 2>/dev/null | grep -q "install ok installed"; then
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                echo "Apache is not configured. The setup in progress..." | sudo tee -a "$logsInst"
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                # Enable required modules
                sudo a2enmod proxy_fcgi setenvif rewrite ssl 2>&1 | sudo tee -a "$logsInst" > /dev/null
                sudo a2enconf php8.4-fpm 2>&1 | sudo tee -a "$logsInst" > /dev/null
                
                # Create port 9090 configuration for Apache
                if ! grep -q "Listen 9090" /etc/apache2/ports.conf; then
                    echo "Listen 9090" | sudo tee -a /etc/apache2/ports.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null
                fi
                
                # Disable default site and create TorrentPier config
                sudo a2dissite 000-default 2>&1 | sudo tee -a "$logsInst" > /dev/null
                echo -e "$apache_torrentpier" | sudo tee /etc/apache2/sites-available/01-torrentpier.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null
                sudo a2ensite 01-torrentpier 2>&1 | sudo tee -a "$logsInst" > /dev/null

                # We are testing and running the Apache config
                sudo apache2ctl configtest 2>&1 | sudo tee -a "$logsInst" > /dev/null
                sudo systemctl restart apache2 2>&1 | sudo tee -a "$logsInst" > /dev/null

                # Setup SSL if enabled
                if [ "$USE_SSL" = true ]; then
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "Obtaining SSL certificate for Apache..." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo certbot --apache -d "$HOST" --non-interactive --agree-tos --email "$SSL_EMAIL" --redirect 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    
                    # Setup auto-renewal
                    if ! sudo crontab -l 2>/dev/null | grep -q "certbot renew"; then
                        (sudo crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload apache2'") | sudo crontab - 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    fi
                fi
            else
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                echo "Apache is not installed. The installation cannot continue." | sudo tee -a "$logsInst"
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                read -rp "Press Enter to complete..."
                exit 1
            fi
            ;;
        caddy)
            if dpkg-query -W -f='${Status}' "caddy" 2>/dev/null | grep -q "install ok installed"; then
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                echo "Caddy is not configured. The setup in progress..." | sudo tee -a "$logsInst"
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                # Create Caddy config
                echo -e "$caddy_config" | sudo tee /etc/caddy/Caddyfile 2>&1 | sudo tee -a "$logsInst" > /dev/null

                # Reload Caddy config
                sudo systemctl reload caddy 2>&1 | sudo tee -a "$logsInst" > /dev/null

                # Inform about automatic SSL
                if [ "$USE_SSL" = true ]; then
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "Caddy will automatically obtain SSL certificate for: $HOST" | sudo tee -a "$logsInst"
                    echo "This may take a few moments on first access..." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                fi
            else
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                echo "Caddy is not installed. The installation cannot continue." | sudo tee -a "$logsInst"
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                read -rp "Press Enter to complete..."
                exit 1
            fi
            ;;
    esac

    # Determine protocol
    if [ "$USE_SSL" = true ]; then
        PROTOCOL="https"
    else
        PROTOCOL="http"
    fi

    echo "" | sudo tee -a "$saveFile"
    echo "Woah! TorrentPier successfully installed!" | sudo tee -a "$saveFile"
    echo "" | sudo tee -a "$saveFile"
    echo "===================================" | sudo tee -a "$saveFile"
    echo "TorrentPier credentials:" | sudo tee -a "$saveFile"
    echo "-> $PROTOCOL://$HOST/" | sudo tee -a "$saveFile"
    echo "-> Username: $torrentPierUser" | sudo tee -a "$saveFile"
    echo "-> Password: $torrentPierPass" | sudo tee -a "$saveFile"
    echo "===================================" | sudo tee -a "$saveFile"
    echo "Database credentials:" | sudo tee -a "$saveFile"
    echo "-> Database name: $dbSql" | sudo tee -a "$saveFile"
    echo "-> Username: $userSql" | sudo tee -a "$saveFile"
    echo "-> Password: $passSql" | sudo tee -a "$saveFile"
    echo "===================================" | sudo tee -a "$saveFile"
    echo "phpMyAdmin credentials:" | sudo tee -a "$saveFile"
    echo "-> $PROTOCOL://$HOST:9090/phpmyadmin" | sudo tee -a "$saveFile"
    echo "-> Username: $userSql" | sudo tee -a "$saveFile"
    echo "-> Password: $passSql" | sudo tee -a "$saveFile"
    echo "===================================" | sudo tee -a "$saveFile"
    echo "DO NOT USE IT IF YOU DO NOT KNOW WHAT IT IS INTENDED FOR" | sudo tee -a "$saveFile" > /dev/null
    echo "phpMyAdmin credentials (super admin):" | sudo tee -a "$saveFile" > /dev/null
    echo "-> $PROTOCOL://$HOST:9090/phpmyadmin" | sudo tee -a "$saveFile" > /dev/null
    echo "-> Username: phpmyadmin" | sudo tee -a "$saveFile" > /dev/null
    echo "-> Password: $passPma" | sudo tee -a "$saveFile" > /dev/null
    echo "===================================" | sudo tee -a "$saveFile" > /dev/null
    
    # SSL information
    if [ "$USE_SSL" = true ]; then
        echo "SSL/TLS Information:" | sudo tee -a "$saveFile"
        echo "-> SSL is enabled and configured" | sudo tee -a "$saveFile"
        echo "-> Certificate email: $SSL_EMAIL" | sudo tee -a "$saveFile"
        if [ "$WEB_SERVER" != "caddy" ]; then
            echo "-> Auto-renewal: Enabled (daily check at 3 AM)" | sudo tee -a "$saveFile"
        else
            echo "-> Auto-renewal: Automatic (Caddy built-in)" | sudo tee -a "$saveFile"
        fi
        echo "===================================" | sudo tee -a "$saveFile"
    fi
    
    echo "" | sudo tee -a $saveFile
    echo "We are sure that you will be able to create the best tracker available!" | sudo tee -a $saveFile
    echo "Good luck!" | sudo tee -a $saveFile
    echo "" | sudo tee -a $saveFile
else
    echo "Your system is not supported." 2>&1 | tee -a "$logsInst"
fi
