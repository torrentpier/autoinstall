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

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Color output functions
print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$logsInst" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$logsInst"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$logsInst"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$logsInst"
}

# Error handler
error_exit() {
    print_error "$1"
    print_error "Installation failed. Check log file: $logsInst"
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
DRY_RUN=false

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
        --php-version)
            PHP_VERSION="$2"
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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --webserver <nginx|apache|caddy>  Choose web server (default: nginx)"
            echo "  --version <v2.4|v2.8>              Choose TorrentPier version (default: v2.4)"
            echo "  --php-version <8.2|8.3|8.4>        Choose PHP version (default: 8.4)"
            echo "  --ssl <auto|yes|no>                Enable SSL/TLS (default: auto - only for domains)"
            echo "  --email <email@example.com>        Email for SSL certificate (required if domain is used)"
            echo "  --dry-run                          Test mode - check requirements without installing"
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

# Validate PHP version choice
if [[ ! "$PHP_VERSION" =~ ^(8\.2|8\.3|8\.4)$ ]]; then
    echo "Error: Invalid PHP version. Choose: 8.2, 8.3, or 8.4"
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
LOCK_FILE="/var/lock/torrentpier_install.lock"

# TorrentPier auth (default credentials)
torrentPierUser="admin"
torrentPierPass="admin"

# User verification
if [ "$(whoami)" != "root" ]; then
    echo "It needs to be run under the root user!" 2>&1 | tee -a "$logsInst"
    exit 1
fi

# Lock file check to prevent concurrent installations
if [ -f "$LOCK_FILE" ]; then
    print_error "Another installation is already running (lock file exists: $LOCK_FILE)"
    print_error "If you're sure no other installation is running, remove the lock file manually:"
    print_error "  rm $LOCK_FILE"
    exit 1
fi

# Create lock file
touch "$LOCK_FILE" || error_exit "Failed to create lock file"

# Start installation timer
START_TIME=$(date +%s)

# Remove lock file on exit
cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# Print system information for diagnostics
print_system_info() {
    print_info "System Information:"
    echo "OS: $(grep ^PRETTY_NAME= /etc/os-release | awk -F= '{print $2}' | tr -d '\"')" | tee -a "$logsInst"
    echo "Kernel: $(uname -r)" | tee -a "$logsInst"
    echo "Architecture: $(dpkg --print-architecture)" | tee -a "$logsInst"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$logsInst"
    echo ""
}

# Calculate installation time
calculate_time() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    if [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m ${seconds}s"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

# Health check function
perform_health_check() {
    local all_ok=true
    
    echo ""
    print_info "Performing post-installation health check..."
    echo ""
    
    # Check web server
    echo -n "[Web Server] Checking $WEB_SERVER... "
    local webserver_service="$WEB_SERVER"
    # Apache service is called apache2 on Debian/Ubuntu
    if [ "$WEB_SERVER" = "apache" ]; then
        webserver_service="apache2"
    fi
    if systemctl is-active --quiet "$webserver_service" 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        all_ok=false
    fi
    
    # Check PHP-FPM
    echo -n "[PHP-FPM] Checking PHP $PHP_VERSION-FPM... "
    if systemctl is-active --quiet "php$PHP_VERSION-fpm" 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        all_ok=false
    fi
    
    # Check MariaDB
    echo -n "[Database] Checking MariaDB... "
    if systemctl is-active --quiet mariadb 2>/dev/null || systemctl is-active --quiet mysql 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        all_ok=false
    fi
    
    # Check website accessibility
    echo -n "[Website] Checking accessibility... "
    if curl -sf -o /dev/null -m 10 "$PROTOCOL://$HOST/" 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}WARNING (might need DNS or firewall config)${NC}"
    fi
    
    # Check phpMyAdmin
    echo -n "[phpMyAdmin] Checking accessibility... "
    if curl -sf -o /dev/null -m 10 "$PROTOCOL://$HOST:9090/" 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}WARNING${NC}"
    fi
    
    # Check database connection
    echo -n "[DB Connection] Checking connection... "
    if MYSQL_PWD="$passSql" mysql -u "$userSql" -e "SELECT 1;" "$dbSql" &>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        all_ok=false
    fi
    
    # Check TorrentPier files
    echo -n "[Files] Checking TorrentPier files... "
    if [ -f "$TORRENTPIER_PATH/index.php" ] && [ -f "$TORRENTPIER_PATH/.env" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        all_ok=false
    fi
    
    # Check vendor directory
    echo -n "[Dependencies] Checking Composer... "
    if [ -d "$TORRENTPIER_PATH/vendor" ] && [ -f "$TORRENTPIER_PATH/vendor/autoload.php" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        all_ok=false
    fi
    
    # Check cron job
    echo -n "[Cron] Checking cron job... "
    if crontab -l 2>/dev/null | grep -q "$TORRENTPIER_PATH/cron.php"; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}WARNING${NC}"
    fi
    
    # Check file permissions
    echo -n "[Permissions] Checking file permissions... "
    if [ "$(stat -c '%U' "$TORRENTPIER_PATH")" = "www-data" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}WARNING${NC}"
    fi
    
    echo ""
    
    if [ "$all_ok" = true ]; then
        print_success "Health check passed! All critical services are running."
    else
        print_warning "Health check completed with warnings. Some services may need attention."
    fi
    
    echo ""
}

# Print final summary
print_final_summary() {
    local install_time=$(calculate_time)
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}║          🎉 TorrentPier Installation Complete! 🎉           ║${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}⏱️  Installation Time:${NC} $install_time"
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ 📋 INSTALLATION SUMMARY                                      ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}🌐 Access Information:${NC}"
    echo -e "   ${GREEN}➜${NC} TorrentPier URL:    ${BLUE}$PROTOCOL://$HOST/${NC}"
    echo -e "   ${GREEN}➜${NC} phpMyAdmin URL:     ${BLUE}$PROTOCOL://$HOST:9090/${NC}"
    echo ""
    echo -e "${YELLOW}🔐 TorrentPier Credentials:${NC}"
    echo -e "   ${GREEN}➜${NC} Username:  ${BLUE}$torrentPierUser${NC}"
    echo -e "   ${GREEN}➜${NC} Password:  ${BLUE}$torrentPierPass${NC}"
    echo ""
    echo -e "${YELLOW}🗄️  Database Information:${NC}"
    echo -e "   ${GREEN}➜${NC} Database:  ${BLUE}$dbSql${NC}"
    echo -e "   ${GREEN}➜${NC} Username:  ${BLUE}$userSql${NC}"
    echo -e "   ${GREEN}➜${NC} Password:  ${BLUE}$passSql${NC}"
    echo ""
    echo -e "${YELLOW}💾 Configuration:${NC}"
    echo -e "   ${GREEN}➜${NC} Web Server:      ${BLUE}$WEB_SERVER${NC}"
    echo -e "   ${GREEN}➜${NC} PHP Version:     ${BLUE}$PHP_VERSION${NC}"
    echo -e "   ${GREEN}➜${NC} TorrentPier:     ${BLUE}$TP_VERSION${NC}"
    [ "$USE_SSL" = true ] && echo -e "   ${GREEN}➜${NC} SSL/TLS:         ${GREEN}Enabled${NC} (${SSL_EMAIL})"
    echo ""
    echo -e "${YELLOW}📁 Important Files:${NC}"
    echo -e "   ${GREEN}➜${NC} Config file:     ${BLUE}$saveFile${NC}"
    echo -e "   ${GREEN}➜${NC} Install log:     ${BLUE}$logsInst${NC}"
    echo -e "   ${GREEN}➜${NC} Application:     ${BLUE}$TORRENTPIER_PATH${NC}"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}✨ Next Steps:${NC}"
    echo -e "   ${YELLOW}1.${NC} Open your browser: ${BLUE}$PROTOCOL://$HOST/${NC}"
    echo -e "   ${YELLOW}2.${NC} Login with credentials above"
    echo -e "   ${YELLOW}3.${NC} ${RED}IMPORTANT:${NC} Change default admin password immediately!"
    [ "$USE_SSL" = false ] && echo -e "   ${YELLOW}4.${NC} ${YELLOW}Consider enabling SSL for production${NC}"
    echo ""
    echo -e "${GREEN}🎯 Good luck with your tracker!${NC}"
    echo ""
}

# System requirements check functions
check_ram() {
    local min_ram=512 # MB
    local available_ram=$(free -m | awk '/^Mem:/{print $2}')
    
    if [ "$available_ram" -lt "$min_ram" ]; then
        error_exit "Insufficient RAM. Required: ${min_ram}MB, Available: ${available_ram}MB"
    fi
    print_success "RAM check passed: ${available_ram}MB available"
}

check_disk_space() {
    local min_space=2 # GB
    local available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ "$available_space" -lt "$min_space" ]; then
        error_exit "Insufficient disk space. Required: ${min_space}GB, Available: ${available_space}GB"
    fi
    print_success "Disk space check passed: ${available_space}GB available"
}

check_port() {
    local port=$1
    local service=$2
    
    if ss -tuln | grep -q ":$port "; then
        print_warning "Port $port is already in use (required for $service)"
        return 1
    fi
    return 0
}

check_ports() {
    print_info "Checking required ports availability..."
    local ports_ok=true
    
    check_port 80 "HTTP" || ports_ok=false
    check_port 443 "HTTPS" || ports_ok=false
    check_port 9090 "phpMyAdmin" || ports_ok=false
    
    if [ "$ports_ok" = false ]; then
        print_error "Some required ports are already in use!"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "All required ports are available"
    fi
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
    # Print system information for diagnostics
    print_system_info
    
    # Run system requirements checks
    print_info "Running system requirements checks..."
    check_ram
    check_disk_space
    check_ports
    echo ""
    
    # Dry-run mode - show what would be installed and exit
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY-RUN MODE - No actual installation will be performed"
        echo ""
        print_info "Configuration Summary:"
        echo "  Web Server: $WEB_SERVER"
        echo "  TorrentPier Version: $TP_VERSION"
        echo "  PHP Version: $PHP_VERSION"
        echo "  SSL/TLS: $SSL_ENABLE"
        [ -n "$SSL_EMAIL" ] && echo "  SSL Email: $SSL_EMAIL"
        echo ""
        print_info "Packages to be installed:"
        echo "  - php$PHP_VERSION-fpm php$PHP_VERSION-mbstring php$PHP_VERSION-bcmath"
        echo "  - php$PHP_VERSION-intl php$PHP_VERSION-tidy php$PHP_VERSION-xml"
        echo "  - php$PHP_VERSION-zip php$PHP_VERSION-gd php$PHP_VERSION-curl php$PHP_VERSION-mysql"
        echo "  - mariadb-server composer"
        echo "  - $WEB_SERVER"
        # Certbot is only needed for nginx/apache with SSL enabled
        if [[ "$WEB_SERVER" != "caddy" ]] && [[ "$SSL_ENABLE" =~ ^(auto|yes)$ ]]; then
            echo "  - certbot python3-certbot-$WEB_SERVER (if domain is used)"
        fi
        echo ""
        print_success "Dry-run completed successfully!"
        print_info "Run without --dry-run to perform actual installation"
        exit 0
    fi
    
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
                    if [[ "$SSL_EMAIL" =~ ^[a-zA-Z0-9._%+\'-]+@[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
                        break
                    else
                        echo "Incorrect email format. Please try again."
                    fi
                done
            fi
            
            print_success "SSL will be automatically configured for domain: $HOST"
            print_info "Email for certificates: $SSL_EMAIL"
        fi
    else
        # It's an IP address
        if [ "$SSL_ENABLE" = "yes" ]; then
            print_warning "SSL cannot be automatically configured for IP addresses."
            print_warning "SSL will be disabled."
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
    DocumentRoot /usr/share/phpmyadmin

    <Directory /usr/share/phpmyadmin>
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
    root * /usr/share/phpmyadmin
    encode gzip zstd
    php_fastcgi unix:/run/php/php$PHP_VERSION-fpm.sock
    file_server
    tls $SSL_EMAIL
}"
    else
        # For IP addresses or when SSL is disabled, use http:// prefix to prevent automatic HTTPS
        caddy_config="http://$HOST {
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

http://$HOST:9090 {
    root * /usr/share/phpmyadmin
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

    # Remove old sury.org repository if exists (it's blocked)
    if [ -f /etc/apt/sources.list.d/php.list ]; then
        print_warning "Removing old blocked php.list repository"
        rm -f /etc/apt/sources.list.d/php.list >> "$logsInst" 2>&1
    fi

    # Updating tables and packages
    print_info "Updating tables and packages"
    apt-get -y update >> "$logsInst" 2>&1
    apt-get -y dist-upgrade >> "$logsInst" 2>&1

    # Add PHP repository
    print_info "Adding PHP $PHP_VERSION repository"
    apt-get install -y lsb-release ca-certificates apt-transport-https software-properties-common >> "$logsInst" 2>&1
    
    # Add Ondřej Surý's PPA for PHP (via Launchpad, more reliable)
    if ! grep -q "ondrej/php" /etc/apt/sources.list.d/* 2>/dev/null; then
        LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -y >> "$logsInst" 2>&1
        print_success "PHP PPA repository added"
    else
        print_info "PHP PPA repository already exists"
    fi
    
    apt-get -y update >> "$logsInst" 2>&1
    
    # Log available PHP packages for diagnostics
    echo "Available PHP $PHP_VERSION packages:" >> "$logsInst"
    apt-cache search "php$PHP_VERSION" | grep "^php$PHP_VERSION" | head -20 >> "$logsInst" 2>&1 || true

    # Check and installation sudo
    if ! dpkg-query -W -f='${Status}' "sudo" 2>/dev/null | grep -q "install ok installed"; then
        print_info "sudo not installed. Installation in progress..."
        apt-get install -y sudo >> "$logsInst" 2>&1
    fi

    # Install Caddy repository and package if needed
    if [ "$WEB_SERVER" == "caddy" ]; then
        if ! dpkg-query -W -f='${Status}' "caddy" 2>/dev/null | grep -q "install ok installed"; then
            print_info "Adding Caddy repository and installing Caddy..."
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg >> "$logsInst" 2>&1
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list >> "$logsInst" 2>&1
            apt-get update >> "$logsInst" 2>&1
            apt-get install -y caddy >> "$logsInst" 2>&1
            print_success "Caddy installed successfully"
        fi
    fi

    # Temporarily disable error trap for package installation
    trap - ERR
    
    # Calculate total packages for progress tracking
    total_packages=${#pkgsList[@]}
    current_package=0
    
    # Package installation cycle
    for package in "${pkgsList[@]}"; do
        ((current_package++))
        # Checking for packages and installing packages
        if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
            print_info "[$current_package/$total_packages] Installing $package..."
            
            # Check if package is available in repositories
            if ! apt-cache show "$package" &>/dev/null; then
                print_warning "Package $package is not available in repositories"
                print_info "Updating package cache and retrying..."
                apt-get update >> "$logsInst" 2>&1 || true
                
                if ! apt-cache show "$package" &>/dev/null; then
                    trap 'error_exit "An error occurred on line $LINENO"' ERR
                    error_exit "Package $package is not available in repositories. Check PHP repository configuration."
                fi
            fi
            
            # Special handling for PHP-FPM to avoid startup failures during installation
            if [[ "$package" == php*-fpm ]]; then
                # Install without starting the service
                DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" >> "$logsInst" 2>&1 || {
                    # If installation fails, try to fix it
                    print_warning "PHP-FPM installation encountered issues, attempting to fix..."
                    dpkg --configure -a >> "$logsInst" 2>&1 || true
                    systemctl stop "php$PHP_VERSION-fpm" 2>/dev/null || true
                    apt-get install -y -f >> "$logsInst" 2>&1 || true
                    
                    # Verify installation succeeded
                    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                        trap 'error_exit "An error occurred on line $LINENO"' ERR
                        error_exit "Failed to install $package. Check log file: $logsInst"
                    fi
                }
            else
                # Install package and check if it succeeded
                if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" >> "$logsInst" 2>&1; then
                    print_warning "Installation of $package failed, attempting to fix..."
                    echo "=== APT Error for $package ===" >> "$logsInst"
                    DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" 2>&1 | tail -50 >> "$logsInst" || true
                    echo "=== End of APT Error ===" >> "$logsInst"
                    
                    # Try to fix broken packages
                    dpkg --configure -a >> "$logsInst" 2>&1 || true
                    apt-get install -y -f >> "$logsInst" 2>&1 || true
                    
                    # Retry installation
                    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" >> "$logsInst" 2>&1; then
                        # Verify if package is actually installed despite error
                        if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                            echo "=== Final APT Error for $package ===" >> "$logsInst"
                            DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" 2>&1 | tail -100 >> "$logsInst" || true
                            echo "=== End of Final APT Error ===" >> "$logsInst"
                            trap 'error_exit "An error occurred on line $LINENO"' ERR
                            error_exit "Failed to install $package after retry. Check log file: $logsInst"
                        else
                            print_warning "$package installed but with warnings"
                        fi
                    fi
                fi
            fi
            
            # Final verification that package was installed successfully
            if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                print_success "[$current_package/$total_packages] $package installed successfully"
            else
                trap 'error_exit "An error occurred on line $LINENO"' ERR
                error_exit "Package $package failed to install. Check log file: $logsInst"
            fi
        else
            print_info "[$current_package/$total_packages] $package is already installed"
        fi
    done
    
    # Re-enable error trap
    trap 'error_exit "An error occurred on line $LINENO"' ERR

    # Configure and start PHP-FPM
    print_info "Configuring PHP $PHP_VERSION-FPM..."
    
    # Check if PHP-FPM is installed
    if ! dpkg-query -W -f='${Status}' "php$PHP_VERSION-fpm" 2>/dev/null | grep -q "install ok installed"; then
        error_exit "PHP $PHP_VERSION-FPM is not installed. Installation failed."
    fi
    
    # Enable PHP-FPM on boot
    systemctl enable "php$PHP_VERSION-fpm" >> "$logsInst" 2>&1 || true
    
    # Start PHP-FPM if not running
    if ! systemctl is-active --quiet "php$PHP_VERSION-fpm" 2>/dev/null; then
        print_info "Starting PHP-FPM service..."
        if systemctl start "php$PHP_VERSION-fpm" >> "$logsInst" 2>&1; then
            print_success "PHP-FPM started successfully"
        else
            print_warning "Failed to start PHP-FPM, attempting fix..."
            dpkg --configure -a >> "$logsInst" 2>&1 || true
            apt-get install --reinstall -y "php$PHP_VERSION-fpm" >> "$logsInst" 2>&1 || true
            systemctl start "php$PHP_VERSION-fpm" >> "$logsInst" 2>&1 || print_warning "PHP-FPM may need manual configuration"
        fi
    else
        print_success "PHP-FPM is already running"
    fi

    passPma="$(pwgen -1Bs 12)"
    dbSql="torrentpier_$(pwgen -1 8)"
    userSql="torrentpier_$(pwgen -1 8)"
    passSql="$(pwgen -1Bs 12)"

    # Installation phpMyAdmin
    if ! dpkg-query -W -f='${Status}' "phpmyadmin" 2>/dev/null | grep -q "install ok installed"; then
        print_info "phpMyAdmin not installed. Installation in progress..."

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
        print_error "phpMyAdmin is already installed on the system. The installation cannot continue."
        read -rp "Press Enter to complete..."
        exit 1
    fi

    # Installation and setting Composer
    if [ ! -f "/usr/local/bin/composer" ]; then
        print_info "Composer not installed. Installation in progress..."
        curl -sSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer >> "$logsInst" 2>&1
    fi

    # Installation TorrentPier
    if [ ! -d "$TORRENTPIER_PATH" ]; then
        print_info "TorrentPier not installed. Installation in progress..."
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
        
        # Create parent directory if it doesn't exist
        mkdir -p "$(dirname "$TORRENTPIER_PATH")" >> "$logsInst" 2>&1 || error_exit "Failed to create parent directory for TorrentPier"
        
        mv "$TEMP_PATH"/torrentpier-torrentpier-* "$TORRENTPIER_PATH" >> "$logsInst" 2>&1 || error_exit "Failed to move TorrentPier files"

        # Remove temporary folder
        rm -rf "$TEMP_PATH" >> "$logsInst" 2>&1

        # Installing composer dependencies
        if [ ! -d "$TORRENTPIER_PATH/vendor" ]; then
            print_info "Installing composer dependencies..."
            COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --prefer-dist --optimize-autoloader --working-dir="$TORRENTPIER_PATH" >> "$logsInst" 2>&1 || error_exit "Failed to install composer dependencies"
            print_success "Composer dependencies installed successfully"
        else
            print_info "Vendor directory already exists, skipping composer install"
        fi

        # Setting up the configuration file
        mv "$TORRENTPIER_PATH/.env.example" "$TORRENTPIER_PATH/.env" >> "$logsInst" 2>&1
        sed -i "s/APP_CRON_ENABLED=true/APP_CRON_ENABLED=false/g" "$TORRENTPIER_PATH/.env" >> "$logsInst" 2>&1
        sed -i "s/DB_DATABASE=torrentpier/DB_DATABASE=$dbSql/g" "$TORRENTPIER_PATH/.env" >> "$logsInst" 2>&1
        sed -i "s/DB_USERNAME=root/DB_USERNAME=$userSql/g" "$TORRENTPIER_PATH/.env" >> "$logsInst" 2>&1
        sed -i "s/DB_PASSWORD=secret/DB_PASSWORD=$passSql/g" "$TORRENTPIER_PATH/.env" >> "$logsInst" 2>&1

        # Check and start MariaDB before database operations
        if ! systemctl is-active --quiet mariadb 2>/dev/null && ! systemctl is-active --quiet mysql 2>/dev/null; then
            print_info "MariaDB is not running. Starting..."
            if ! systemctl start mariadb 2>/dev/null && ! systemctl start mysql 2>/dev/null; then
                error_exit "Failed to start MariaDB/MySQL. Please check the service status."
            fi
            print_success "MariaDB started successfully"
        fi

        # Creating a user
        mysql -e "CREATE USER '$userSql'@'localhost' IDENTIFIED BY '$passSql';" >> "$logsInst" 2>&1

        # Creating a database
        mysql -e "CREATE DATABASE $dbSql CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" >> "$logsInst" 2>&1

        # Granting privileges to the user on the database
        mysql -e "GRANT ALL PRIVILEGES ON $dbSql.* TO '$userSql'@'localhost';" >> "$logsInst" 2>&1

        # Applying privilege changes
        mysql -e "FLUSH PRIVILEGES;" >> "$logsInst" 2>&1

        # Import/Initialize database based on TorrentPier version
        if [ "$TP_VERSION" == "v2.4" ]; then
            # v2.4: Import database from SQL dump
            print_info "Importing database from SQL dump (v2.4)..."
            if [ ! -f "$TORRENTPIER_PATH/install/sql/mysql.sql" ]; then
                error_exit "SQL file not found: $TORRENTPIER_PATH/install/sql/mysql.sql"
            fi
            { MYSQL_PWD="$passSql" mysql --default-character-set=utf8mb4 -u "$userSql" "$dbSql" < "$TORRENTPIER_PATH/install/sql/mysql.sql"; } >> "$logsInst" 2>&1 || error_exit "Failed to import database"
            print_success "Database imported successfully"
        elif [ "$TP_VERSION" == "v2.8" ]; then
            # v2.8: Run Phinx migrations
            print_info "Running Phinx migrations (v2.8)..."
            cd "$TORRENTPIER_PATH" || error_exit "Failed to change directory to $TORRENTPIER_PATH"
            php vendor/bin/phinx migrate --configuration=phinx.php >> "$logsInst" 2>&1 || error_exit "Failed to run Phinx migrations"
            print_success "Database migrations completed successfully"
        fi

        # We set the rights to directories and files
        chown -R www-data:www-data "$TORRENTPIER_PATH" >> "$logsInst" 2>&1
        find "$TORRENTPIER_PATH" -type f -exec chmod 644 {} \; >> "$logsInst" 2>&1
        find "$TORRENTPIER_PATH" -type d -exec chmod 755 {} \; >> "$logsInst" 2>&1

        # Setting the CRON task
        print_info "Setting up CRON task for TorrentPier..."
        if ! crontab -l 2>/dev/null | grep -q "$TORRENTPIER_PATH/cron.php"; then
            (crontab -l 2>/dev/null; echo "*/10 * * * * sudo -u www-data php $TORRENTPIER_PATH/cron.php") | crontab - >> "$logsInst" 2>&1
            print_success "CRON task configured successfully"
        else
            print_info "CRON task already configured"
        fi
    else
        print_error "TorrentPier is already installed on the system. The installation cannot continue."
        read -rp "Press Enter to complete..."
        exit 1
    fi

    # Setting up web server
    case "$WEB_SERVER" in
        nginx)
            if dpkg-query -W -f='${Status}' "nginx" 2>/dev/null | grep -q "install ok installed"; then
                print_info "NGINX is not configured. The setup in progress..."
                # We remove the default one and create the TorrentPier config
                rm /etc/nginx/sites-enabled/default >> "$logsInst" 2>&1
                echo -e "$nginx_torrentpier" | tee /etc/nginx/sites-available/01-torrentpier.conf >> "$logsInst" 2>&1
                ln -s /etc/nginx/sites-available/01-torrentpier.conf /etc/nginx/sites-enabled/ >> "$logsInst" 2>&1

                # We are testing and running the NGINX config
                nginx -t >> "$logsInst" 2>&1
                systemctl restart nginx >> "$logsInst" 2>&1

                # Setup SSL if enabled
                if [ "$USE_SSL" = true ]; then
                    print_info "Obtaining SSL certificate for NGINX..."
                    certbot --nginx -d "$HOST" --non-interactive --agree-tos --email "$SSL_EMAIL" --redirect >> "$logsInst" 2>&1
                    
                    # Setup auto-renewal
                    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
                        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab - >> "$logsInst" 2>&1
                    fi
                fi
            else
                print_error "NGINX is not installed. The installation cannot continue."
                read -rp "Press Enter to complete..."
                exit 1
            fi
            ;;
        apache)
            if dpkg-query -W -f='${Status}' "apache2" 2>/dev/null | grep -q "install ok installed"; then
                print_info "Apache is not configured. The setup in progress..."
                # Enable required modules
                a2enmod proxy_fcgi setenvif rewrite ssl >> "$logsInst" 2>&1
                a2enconf php$PHP_VERSION-fpm >> "$logsInst" 2>&1
                
                # Create port 9090 configuration for Apache
                if ! grep -q "Listen 9090" /etc/apache2/ports.conf; then
                    echo "Listen 9090" >> /etc/apache2/ports.conf 2>> "$logsInst"
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
                    print_info "Obtaining SSL certificate for Apache..."
                    certbot --apache -d "$HOST" --non-interactive --agree-tos --email "$SSL_EMAIL" --redirect >> "$logsInst" 2>&1
                    
                    # Setup auto-renewal
                    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
                        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload apache2'") | crontab - >> "$logsInst" 2>&1
                    fi
                fi
            else
                print_error "Apache is not installed. The installation cannot continue."
                read -rp "Press Enter to complete..."
                exit 1
            fi
            ;;
        caddy)
            if dpkg-query -W -f='${Status}' "caddy" 2>/dev/null | grep -q "install ok installed"; then
                print_info "Caddy is not configured. The setup in progress..."
                # Create Caddy config
                echo -e "$caddy_config" | tee /etc/caddy/Caddyfile >> "$logsInst" 2>&1

                # Reload Caddy config
                systemctl reload caddy >> "$logsInst" 2>&1

                # Inform about automatic SSL
                if [ "$USE_SSL" = true ]; then
                    print_info "Caddy will automatically obtain SSL certificate for: $HOST"
                    print_info "This may take a few moments on first access..."
                fi
            else
                print_error "Caddy is not installed. The installation cannot continue."
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

    # Perform health check
    perform_health_check
    
    # Print beautiful final summary
    print_final_summary | tee -a "$saveFile"
    
    # Save detailed credentials to file (without colors)
    {
        echo ""
        echo "================================================"
        echo "TorrentPier Installation Details"
        echo "================================================"
        echo "Installation Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Installation Time: $(calculate_time)"
        echo ""
        echo "TorrentPier credentials:"
        echo "-> $PROTOCOL://$HOST/"
        echo "-> Username: $torrentPierUser"
        echo "-> Password: $torrentPierPass"
        echo ""
        echo "Database credentials:"
        echo "-> Database name: $dbSql"
        echo "-> Username: $userSql"
        echo "-> Password: $passSql"
        echo ""
        echo "phpMyAdmin credentials:"
        echo "-> $PROTOCOL://$HOST:9090/"
        echo "-> Username: $userSql"
        echo "-> Password: $passSql"
        echo ""
        echo "DO NOT USE IT IF YOU DO NOT KNOW WHAT IT IS INTENDED FOR"
        echo "phpMyAdmin credentials (super admin):"
        echo "-> $PROTOCOL://$HOST:9090/"
        echo "-> Username: phpmyadmin"
        echo "-> Password: $passPma"
        echo ""
        if [ "$USE_SSL" = true ]; then
            echo "SSL/TLS Information:"
            echo "-> SSL is enabled and configured"
            echo "-> Certificate email: $SSL_EMAIL"
            if [ "$WEB_SERVER" != "caddy" ]; then
                echo "-> Auto-renewal: Enabled (daily check at 3 AM)"
            else
                echo "-> Auto-renewal: Automatic (Caddy built-in)"
            fi
        fi
        echo ""
        echo "Configuration:"
        echo "-> Web Server: $WEB_SERVER"
        echo "-> PHP Version: $PHP_VERSION"
        echo "-> TorrentPier Version: $TP_VERSION"
        echo ""
        echo "================================================"
    } >> "$saveFile"
else
    echo "Your system is not supported." 2>&1 | tee -a "$logsInst"
fi
