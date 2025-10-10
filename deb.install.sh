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

# Error handler
error_exit() {
    echo "ERROR: $1" | tee -a "$logsInst" >&2
    echo "Installation failed. Check log file: $logsInst" | tee -a "$logsInst" >&2
    exit 1
}

# Trap errors
trap 'error_exit "An error occurred on line $LINENO"' ERR

# Default values
WEB_SERVER="nginx"
TP_VERSION="v2.4"
SSL_ENABLE="auto"
SSL_EMAIL=""
PHP_VERSION="8.4"

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

# Installation paths
TORRENTPIER_PATH="/var/www/torrentpier"
TEMP_PATH="/tmp/torrentpier"
PHPMYADMIN_PATH="/usr/share/phpmyadmin"

# TorrentPier auth (generated secure passwords)
torrentPierUser="admin"
torrentPierPass="$(pwgen -1Bs 16)"

# User verification
if [ "$(whoami)" != "root" ]; then
    echo "It needs to be run under the root user!" 2>&1 | tee -a "$logsInst"
    exit 1
fi

# Logging function
log_message() {
    echo "$1" | tee -a "$logsInst"
}

log_separator() {
    echo "===================================" | tee -a "$logsInst"
}

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
                # Remove leading zeros and check range
                octet=$((10#$octet))
                if (( octet > 255 )); then
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
        # Check for localhost
        if [[ "$domain" == "localhost" ]]; then
            return 1
        fi
        # Checking the format of the domain name (letters, numbers, hyphens, and dots)
        # Domain must have at least one dot and valid TLD (2+ chars)
        # Labels can't start or end with hyphen
        if [[ "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
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
                    # Improved email validation (RFC 5322 simplified)
                    if [[ "$SSL_EMAIL" =~ ^[a-zA-Z0-9._%+'-]+@[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
                        break
                    else
                        echo "Incorrect email format. Please try again."
                    fi
                done
            fi
            
            log_separator
            log_message "SSL will be automatically configured for domain: $HOST"
            log_message "Email for certificates: $SSL_EMAIL"
            log_separator
        fi
    else
        # It's an IP address
        if [ "$SSL_ENABLE" = "yes" ]; then
            log_separator
            log_message "Warning: SSL cannot be automatically configured for IP addresses."
            log_message "SSL will be disabled."
            log_separator
        fi
        USE_SSL=false
    fi

    # NGINX configuration file for TorrentPier
    nginx_torrentpier="server {
    listen 80;
    server_name $HOST;
    root $TORRENTPIER_PATH;
    index index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \/(install|internal_data|library)\/ {
        return 404;
    }

    location ~ /\.(ht|en) {
        return 404;
    }

    location ~ /\.git {
        return 404;
    }

    location ~ \.(.*sql|tpl|db|inc|log|md)$ {
        return 404;
    }

    rewrite ^/sitemap.xml$ /sitemap/sitemap.xml;

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}"

    # NGINX configuration file for phpMyAdmin
    nginx_phpmyadmin="server {
    listen 9090;
    server_name $HOST;

    root $PHPMYADMIN_PATH;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php;
    }

    location ~* ^/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
        root $PHPMYADMIN_PATH;
    }

    location ~ /\.ht {
        deny all;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}"

    # Apache configuration file for TorrentPier
    apache_torrentpier="<VirtualHost *:80>
    ServerName $HOST
    DocumentRoot $TORRENTPIER_PATH

    <Directory $TORRENTPIER_PATH>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \\.php$>
        SetHandler \"proxy:unix:/run/php/php$PHP_VERSION-fpm.sock|fcgi://localhost\"
    </FilesMatch>

    ErrorLog \${APACHE_LOG_DIR}/torrentpier_error.log
    CustomLog \${APACHE_LOG_DIR}/torrentpier_access.log combined
</VirtualHost>"

    # Apache configuration file for phpMyAdmin
    apache_phpmyadmin="<VirtualHost *:9090>
    ServerName $HOST
    DocumentRoot $PHPMYADMIN_PATH

    <Directory $PHPMYADMIN_PATH>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \\.php$>
        SetHandler \"proxy:unix:/run/php/php$PHP_VERSION-fpm.sock|fcgi://localhost\"
    </FilesMatch>

    ErrorLog \${APACHE_LOG_DIR}/phpmyadmin_error.log
    CustomLog \${APACHE_LOG_DIR}/phpmyadmin_access.log combined
</VirtualHost>"

    # Caddy configuration file (SSL automatic if domain is used)
    if [ "$USE_SSL" = true ]; then
        caddy_config="$HOST {
        root * $TORRENTPIER_PATH
    encode gzip zstd
    php_fastcgi unix:/run/php/php$PHP_VERSION-fpm.sock
    try_files {path} {path}/ /index.php?{query}
    file_server
    tls $SSL_EMAIL

    @blocked {
        path /install/* /internal_data/* /library/*
        path /.ht* /.en*
        path /.git/*
        path *.sql *.tpl *.db *.inc *.log *.md
    }
    respond @blocked 404

    redir /sitemap.xml /sitemap/sitemap.xml

    @html_css_js {
        path *.html *.css *.js *.json *.xml *.txt
    }
    header @html_css_js Content-Type \"{mime}; charset=utf-8\"
}

$HOST:9090 {
    root * $PHPMYADMIN_PATH
    encode gzip zstd
    php_fastcgi unix:/run/php/php$PHP_VERSION-fpm.sock
    file_server
    tls $SSL_EMAIL
}"
    else
        caddy_config="$HOST {
        root * $TORRENTPIER_PATH
    encode gzip zstd
    php_fastcgi unix:/run/php/php$PHP_VERSION-fpm.sock
    try_files {path} {path}/ /index.php?{query}
    file_server

    @blocked {
        path /install/* /internal_data/* /library/*
        path /.ht* /.en*
        path /.git/*
        path *.sql *.tpl *.db *.inc *.log *.md
    }
    respond @blocked 404

    redir /sitemap.xml /sitemap/sitemap.xml

    @html_css_js {
        path *.html *.css *.js *.json *.xml *.txt
    }
    header @html_css_js Content-Type \"{mime}; charset=utf-8\"
}

$HOST:9090 {
    root * $PHPMYADMIN_PATH
    encode gzip zstd
    php_fastcgi unix:/run/php/php$PHP_VERSION-fpm.sock
    file_server
}"
    fi

    # Packages for installation, TorrentPier, phpMyAdmin
    # Base packages (PHP $PHP_VERSION)
    pkgsList=("php$PHP_VERSION-fpm" "php$PHP_VERSION-mbstring" "php$PHP_VERSION-bcmath" "php$PHP_VERSION-intl" "php$PHP_VERSION-tidy" "php$PHP_VERSION-xml" "php$PHP_VERSION-zip" "php$PHP_VERSION-gd" "php$PHP_VERSION-curl" "php$PHP_VERSION-mysql" "mariadb-server" "pwgen" "jq" "curl" "zip" "unzip" "cron")
    
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
    log_separator
    log_message "Updating tables and packages"
    log_separator
    apt-get -y update >> "$logsInst" 2>&1
    apt-get -y dist-upgrade >> "$logsInst" 2>&1

    # Add PHP repository
    log_separator
    log_message "Adding PHP $PHP_VERSION repository"
    log_separator
    apt-get install -y lsb-release ca-certificates apt-transport-https software-properties-common gnupg2 >> "$logsInst" 2>&1
    curl -sSL https://packages.sury.org/php/apt.gpg -o /etc/apt/trusted.gpg.d/php.gpg >> "$logsInst" 2>&1
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list >> "$logsInst" 2>&1
    apt-get -y update >> "$logsInst" 2>&1

    # Check and installation sudo
    if ! dpkg-query -W -f='${Status}' "sudo" 2>/dev/null | grep -q "install ok installed"; then
        log_separator
        log_message "sudo not installed. Installation in progress..."
        log_separator
        apt-get install -y sudo >> "$logsInst" 2>&1
    fi

    # Install Caddy repository if needed
    if [ "$WEB_SERVER" == "caddy" ]; then
        if ! dpkg-query -W -f='${Status}' "caddy" 2>/dev/null | grep -q "install ok installed"; then
            log_separator
            log_message "Adding Caddy repository..."
            log_separator
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg >> "$logsInst" 2>&1
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list >> "$logsInst" 2>&1
            apt-get update >> "$logsInst" 2>&1
        fi
    fi

    # Package installation cycle
    for package in "${pkgsList[@]}"; do
        # Checking for packages and installing packages
        if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
            log_separator
            log_message "$package not installed. Installation in progress..."
            log_separator
            apt-get install -y "$package" >> "$logsInst" 2>&1
        fi
    done
    
    # Install Caddy separately
    if [ "$WEB_SERVER" == "caddy" ]; then
        if ! dpkg-query -W -f='${Status}' "caddy" 2>/dev/null | grep -q "install ok installed"; then
            log_separator
            log_message "caddy not installed. Installation in progress..."
            log_separator
            apt-get install -y caddy >> "$logsInst" 2>&1
        fi
    fi

    passPma="$(pwgen -1Bs 12)"
    dbSql="torrentpier_$(pwgen -1 8)"
    userSql="torrentpier_$(pwgen -1 8)"
    passSql="$(pwgen -1Bs 12)"

    # Installation phpMyAdmin
    if ! dpkg-query -W -f='${Status}' "phpmyadmin" 2>/dev/null | grep -q "install ok installed"; then
        log_separator
        log_message "phpMyAdmin not installed. Installation in progress..."
        log_separator

        debconf-set-selections <<EOF
phpmyadmin phpmyadmin/dbconfig-install boolean true
phpmyadmin phpmyadmin/mysql/app-pass password $passPma
phpmyadmin phpmyadmin/password-confirm password $passPma
phpmyadmin phpmyadmin/reconfigure-webserver multiselect
EOF
        DEBIAN_FRONTEND="noninteractive" apt-get install -y phpmyadmin >> "$logsInst" 2>&1
        
        # Configure phpMyAdmin for selected web server
        case "$WEB_SERVER" in
            nginx)
                echo -e "$nginx_phpmyadmin" | tee /etc/nginx/sites-available/00-phpmyadmin.conf >> "$logsInst" 2>&1
                ln -s /etc/nginx/sites-available/00-phpmyadmin.conf /etc/nginx/sites-enabled/ >> "$logsInst" 2>&1
                nginx -t >> "$logsInst" 2>&1
                systemctl restart nginx >> "$logsInst" 2>&1
                ;;
            apache)
                echo -e "$apache_phpmyadmin" | tee /etc/apache2/sites-available/00-phpmyadmin.conf >> "$logsInst" 2>&1
                a2ensite 00-phpmyadmin >> "$logsInst" 2>&1
                apache2ctl configtest >> "$logsInst" 2>&1
                systemctl restart apache2 >> "$logsInst" 2>&1
                ;;
            caddy)
                # Caddy config already includes phpMyAdmin
                systemctl reload caddy >> "$logsInst" 2>&1
                ;;
        esac
    else
        log_separator
        echo "phpMyAdmin is already installed on the system. The installation cannot continue." | tee -a "$logsInst"
        log_separator
        read -rp "Press Enter to complete..."
        exit 1
    fi

    # Installation and setting Composer
    if [ ! -f "/usr/local/bin/composer" ]; then
        log_separator
        log_message "Composer not installed. Installation in progress..."
        log_separator
        curl -sSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer >> "$logsInst" 2>&1
    fi

    # Installation TorrentPier
    if [ ! -d "$TORRENTPIER_PATH" ]; then
        log_separator
        log_message "TorrentPier not installed. Installation in progress..."
        log_separator
        # Creating a temporary directory
        mkdir -p "$TEMP_PATH" >> "$logsInst" 2>&1

        # Downloading TorrentPier based on selected version
        if [ "$TP_VERSION" == "v2.4" ]; then
            curl -s https://api.github.com/repos/torrentpier/torrentpier/releases | jq -r 'map(select(.prerelease == false and (.tag_name | test("^v2\\.4\\.")))) | .[0].zipball_url' | xargs -n 1 curl -L -o "$TEMP_PATH/torrentpier.zip" >> "$logsInst" 2>&1 || error_exit "Failed to download TorrentPier v2.4"
        elif [ "$TP_VERSION" == "v2.8" ]; then
            curl -s https://api.github.com/repos/torrentpier/torrentpier/releases | jq -r 'map(select(.prerelease == false and (.tag_name | test("^v2\\.8\\.")))) | .[0].zipball_url' | xargs -n 1 curl -L -o "$TEMP_PATH/torrentpier.zip" >> "$logsInst" 2>&1 || error_exit "Failed to download TorrentPier v2.8"
        fi
        
        # Check if download was successful
        [ -f "$TEMP_PATH/torrentpier.zip" ] || error_exit "TorrentPier archive not found after download"
        
        unzip -o "$TEMP_PATH/torrentpier.zip" -d "$TEMP_PATH" >> "$logsInst" 2>&1 || error_exit "Failed to extract TorrentPier archive"
        mv "$TEMP_PATH"/torrentpier-torrentpier-* "$TORRENTPIER_PATH" >> "$logsInst" 2>&1 || error_exit "Failed to move TorrentPier files"

        # Clearing the temporary folder
        rm -rf "$TEMP_PATH"/* >> "$logsInst" 2>&1

        # Installing composer dependencies
        COMPOSER_ALLOW_SUPERUSER=1 composer install --working-dir="$TORRENTPIER_PATH" >> "$logsInst" 2>&1

        # Setting up the configuration file
        mv "$TORRENTPIER_PATH/.env.example" "$TORRENTPIER_PATH/.env" 2>&1 | tee -a "$logsInst"
        sed -i "s/APP_CRON_ENABLED=true/APP_CRON_ENABLED=false/g" "$TORRENTPIER_PATH/.env" >> "$logsInst" 2>&1
        sed -i "s/DB_DATABASE=torrentpier/DB_DATABASE=$dbSql/g" "$TORRENTPIER_PATH/.env" >> "$logsInst" 2>&1
        sed -i "s/DB_USERNAME=root/DB_USERNAME=$userSql/g" "$TORRENTPIER_PATH/.env" >> "$logsInst" 2>&1
        sed -i "s/DB_PASSWORD=secret/DB_PASSWORD=$passSql/g" "$TORRENTPIER_PATH/.env" >> "$logsInst" 2>&1

        # Creating a user
        mysql -e "CREATE USER '$userSql'@'localhost' IDENTIFIED BY '$passSql';" >> "$logsInst" 2>&1

        # Creating a database
        mysql -e "CREATE DATABASE $dbSql CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" >> "$logsInst" 2>&1

        # Granting privileges to the user on the database
        mysql -e "GRANT ALL PRIVILEGES ON $dbSql.* TO '$userSql'@'localhost';" >> "$logsInst" 2>&1

        # Applying privilege changes
        mysql -e "FLUSH PRIVILEGES;" >> "$logsInst" 2>&1

        # Import a database (using MYSQL_PWD to avoid password in process list)
        if [ ! -f "$TORRENTPIER_PATH/install/sql/mysql.sql" ]; then
            error_exit "SQL file not found: $TORRENTPIER_PATH/install/sql/mysql.sql"
        fi
        { MYSQL_PWD="$passSql" mysql --default-character-set=utf8mb4 -u "$userSql" "$dbSql" < "$TORRENTPIER_PATH/install/sql/mysql.sql"; } >> "$logsInst" 2>&1 || error_exit "Failed to import database"

        # We set the rights to directories and files
        chown -R www-data:www-data "$TORRENTPIER_PATH" >> "$logsInst" 2>&1
        find "$TORRENTPIER_PATH" -type f -exec chmod 644 {} \; >> "$logsInst" 2>&1
        find "$TORRENTPIER_PATH" -type d -exec chmod 755 {} \; >> "$logsInst" 2>&1

        # Setting the CRON task
        { (crontab -l 2>/dev/null; echo "*/10 * * * * sudo -u www-data php $TORRENTPIER_PATH/cron.php") | crontab -; } >> "$logsInst" 2>&1
    else
        log_separator
        echo "TorrentPier is already installed on the system. The installation cannot continue." | tee -a "$logsInst"
        log_separator
        read -rp "Press Enter to complete..."
        exit 1
    fi

    # Setting up web server
    case "$WEB_SERVER" in
        nginx)
            if dpkg-query -W -f='${Status}' "nginx" 2>/dev/null | grep -q "install ok installed"; then
                log_separator
                echo "NGINX is not configured. The setup in progress..." | tee -a "$logsInst"
                log_separator
                # We remove the default one and create the TorrentPier config
                rm /etc/nginx/sites-enabled/default >> "$logsInst" 2>&1
                echo -e "$nginx_torrentpier" | tee /etc/nginx/sites-available/01-torrentpier.conf >> "$logsInst" 2>&1
                ln -s /etc/nginx/sites-available/01-torrentpier.conf /etc/nginx/sites-enabled/ >> "$logsInst" 2>&1

                # We are testing and running the NGINX config
                nginx -t >> "$logsInst" 2>&1
                systemctl restart nginx >> "$logsInst" 2>&1

                # Setup SSL if enabled
                if [ "$USE_SSL" = true ]; then
                    log_separator
                    echo "Obtaining SSL certificate for NGINX..." | tee -a "$logsInst"
                    log_separator
                    certbot --nginx -d "$HOST" --non-interactive --agree-tos --email "$SSL_EMAIL" --redirect >> "$logsInst" 2>&1
                    
                    # Setup auto-renewal
                    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
                        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab - >> "$logsInst" 2>&1
                    fi
                fi
            else
                log_separator
                echo "NGINX is not installed. The installation cannot continue." | tee -a "$logsInst"
                log_separator
                read -rp "Press Enter to complete..."
                exit 1
            fi
            ;;
        apache)
            if dpkg-query -W -f='${Status}' "apache2" 2>/dev/null | grep -q "install ok installed"; then
                log_separator
                echo "Apache is not configured. The setup in progress..." | tee -a "$logsInst"
                log_separator
                # Enable required modules
                a2enmod proxy_fcgi setenvif rewrite ssl >> "$logsInst" 2>&1
                a2enconf php$PHP_VERSION-fpm >> "$logsInst" 2>&1
                
                # Create port 9090 configuration for Apache
                if ! grep -q "Listen 9090" /etc/apache2/ports.conf; then
                    echo "Listen 9090" | tee -a /etc/apache2/ports.conf >> "$logsInst" 2>&1
                fi
                
                # Disable default site and create TorrentPier config
                a2dissite 000-default >> "$logsInst" 2>&1
                echo -e "$apache_torrentpier" | tee /etc/apache2/sites-available/01-torrentpier.conf >> "$logsInst" 2>&1
                a2ensite 01-torrentpier >> "$logsInst" 2>&1

                # We are testing and running the Apache config
                apache2ctl configtest >> "$logsInst" 2>&1
                systemctl restart apache2 >> "$logsInst" 2>&1

                # Setup SSL if enabled
                if [ "$USE_SSL" = true ]; then
                    log_separator
                    echo "Obtaining SSL certificate for Apache..." | tee -a "$logsInst"
                    log_separator
                    certbot --apache -d "$HOST" --non-interactive --agree-tos --email "$SSL_EMAIL" --redirect >> "$logsInst" 2>&1
                    
                    # Setup auto-renewal
                    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
                        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload apache2'") | crontab - >> "$logsInst" 2>&1
                    fi
                fi
            else
                log_separator
                echo "Apache is not installed. The installation cannot continue." | tee -a "$logsInst"
                log_separator
                read -rp "Press Enter to complete..."
                exit 1
            fi
            ;;
        caddy)
            if dpkg-query -W -f='${Status}' "caddy" 2>/dev/null | grep -q "install ok installed"; then
                log_separator
                echo "Caddy is not configured. The setup in progress..." | tee -a "$logsInst"
                log_separator
                # Create Caddy config
                echo -e "$caddy_config" | tee /etc/caddy/Caddyfile >> "$logsInst" 2>&1

                # Reload Caddy config
                systemctl reload caddy >> "$logsInst" 2>&1

                # Inform about automatic SSL
                if [ "$USE_SSL" = true ]; then
                    log_separator
                    echo "Caddy will automatically obtain SSL certificate for: $HOST" | tee -a "$logsInst"
                    echo "This may take a few moments on first access..." | tee -a "$logsInst"
                    log_separator
                fi
            else
                log_separator
                echo "Caddy is not installed. The installation cannot continue." | tee -a "$logsInst"
                log_separator
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

    echo "" | tee -a "$saveFile"
    echo "Woah! TorrentPier successfully installed!" | tee -a "$saveFile"
    echo "" | tee -a "$saveFile"
    echo "===================================" | tee -a "$saveFile"
    echo "TorrentPier credentials:" | tee -a "$saveFile"
    echo "-> $PROTOCOL://$HOST/" | tee -a "$saveFile"
    echo "-> Username: $torrentPierUser" | tee -a "$saveFile"
    echo "-> Password: $torrentPierPass" | tee -a "$saveFile"
    echo "===================================" | tee -a "$saveFile"
    echo "Database credentials:" | tee -a "$saveFile"
    echo "-> Database name: $dbSql" | tee -a "$saveFile"
    echo "-> Username: $userSql" | tee -a "$saveFile"
    echo "-> Password: $passSql" | tee -a "$saveFile"
    echo "===================================" | tee -a "$saveFile"
    echo "phpMyAdmin credentials:" | tee -a "$saveFile"
    echo "-> $PROTOCOL://$HOST:9090/phpmyadmin" | tee -a "$saveFile"
    echo "-> Username: $userSql" | tee -a "$saveFile"
    echo "-> Password: $passSql" | tee -a "$saveFile"
    echo "===================================" | tee -a "$saveFile"
    echo "DO NOT USE IT IF YOU DO NOT KNOW WHAT IT IS INTENDED FOR" | tee -a "$saveFile"
    echo "phpMyAdmin credentials (super admin):" | tee -a "$saveFile"
    echo "-> $PROTOCOL://$HOST:9090/phpmyadmin" | tee -a "$saveFile"
    echo "-> Username: phpmyadmin" | tee -a "$saveFile"
    echo "-> Password: $passPma" | tee -a "$saveFile"
    echo "===================================" | tee -a "$saveFile"
    
    # SSL information
    if [ "$USE_SSL" = true ]; then
        echo "SSL/TLS Information:" | tee -a "$saveFile"
        echo "-> SSL is enabled and configured" | tee -a "$saveFile"
        echo "-> Certificate email: $SSL_EMAIL" | tee -a "$saveFile"
        if [ "$WEB_SERVER" != "caddy" ]; then
            echo "-> Auto-renewal: Enabled (daily check at 3 AM)" | tee -a "$saveFile"
        else
            echo "-> Auto-renewal: Automatic (Caddy built-in)" | tee -a "$saveFile"
        fi
        echo "===================================" | tee -a "$saveFile"
    fi
    
    echo "" | tee -a "$saveFile"
    echo "We are sure that you will be able to create the best tracker available!" | tee -a "$saveFile"
    echo "Good luck!" | tee -a "$saveFile"
    echo "" | tee -a "$saveFile"
else
    echo "Your system is not supported." 2>&1 | tee -a "$logsInst"
fi
