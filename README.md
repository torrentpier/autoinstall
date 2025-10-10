## Automatic installation for TorrentPier
**This shell script allows you to:**
- Install TorrentPier (v2.4 or v2.8) in automatic mode;
- Choose web server (NGINX, Apache, or Caddy);
- Flexible configuration with command-line arguments;
## Supported systems:
- **GNU/Linux:** Debian 12
- **GNU/Linux:** Ubuntu 22.04, 24.04
> [!IMPORTANT]
> The architecture and bit depth of x86_64 are required.
## Starting the auto installer:
**Update indexes and packages**
```bash
apt -y update && apt -y full-upgrade
```
**Install GIT**
```bash
apt -y install git
```
**Clone the repository**
```bash
git clone https://github.com/torrentpier/autoinstall.git
```
**Make the installation file executable**
```bash
chmod +x ./autoinstall/install.sh
```
**Run automatic installation**
```bash
# Default installation (NGINX, v2.4, SSL auto)
./autoinstall/install.sh

# With custom options
./autoinstall/install.sh --webserver nginx --version v2.4
./autoinstall/install.sh --webserver apache --version v2.8
./autoinstall/install.sh --webserver caddy --version v2.4

# With SSL and email (for domain)
./autoinstall/install.sh --webserver nginx --version v2.4 --email admin@example.com

# Disable SSL (use HTTP only)
./autoinstall/install.sh --webserver nginx --ssl no

# Custom PHP version
./autoinstall/install.sh --php-version 8.3

# Dry-run mode (test without installing)
./autoinstall/install.sh --dry-run
```

**Available options:**
- `--webserver <nginx|apache|caddy>` - Choose web server (default: nginx)
- `--version <v2.4|v2.8>` - Choose TorrentPier version (default: v2.4)
- `--php-version <8.2|8.3|8.4>` - Choose PHP version (default: 8.4)
- `--ssl <auto|yes|no>` - Enable SSL/TLS (default: auto - enabled for domains only)
- `--email <email@example.com>` - Email for SSL certificate (required if domain is used)
- `--dry-run` - Test mode - check requirements without installing
- `--help` - Show help message

> [!NOTE]
> install.sh always downloads the latest release.\
> If you want to run it directly, use deb.install.sh for Debian and Ubuntu.

**Running the installation script directly for debian and ubuntu**
```bash
chmod +x ./autoinstall/deb.install.sh && ./autoinstall/deb.install.sh --webserver nginx --version v2.4
```
## Additional information:
- **Web server:** NGINX/Apache/Caddy + PHP-FPM (configurable)
- **PHP version:** 8.2/8.3/8.4 (configurable, from Ondřej Surý's repository)
- **System checks:** RAM (512MB min), Disk space (2GB min), Ports availability
- **SSL/TLS:** Automatic Let's Encrypt certificates (for domains)
  - **Caddy:** Built-in automatic HTTPS
  - **NGINX/Apache:** Certbot with auto-renewal
- **Cron schedule:** Every 10 minutes
- **Installation logs directory:** /var/log/torrentpier_install.log
- **Temporary directory:** /tmp/torrentpier
- **The file with the data after installation:** /root/torrentpier.cfg
- **Lock file:** /var/lock/torrentpier_install.lock (prevents concurrent installations)

### New Features:
- ✅ **Colored output** - Error messages in red, success in green, warnings in yellow
- ✅ **System requirements check** - Validates RAM, disk space, and port availability before installation
- ✅ **Flexible PHP version** - Choose between PHP 8.2, 8.3, or 8.4
- ✅ **Dry-run mode** - Test configuration without actual installation (`--dry-run`)
- ✅ **Lock file protection** - Prevents multiple simultaneous installations
- ✅ **MariaDB health check** - Automatically starts MariaDB if not running
- ✅ **Enhanced error handling** - Better error messages and automatic rollback on failure
- ✅ **Installation timer** - Shows total installation time
- ✅ **Beautiful final summary** - Structured output with all credentials and next steps
- ✅ **Post-installation health check** - Validates all services, database, website accessibility

### Post-Installation Health Check:
After installation completes, an automatic health check validates:
- 🌐 Web server status (nginx/apache/caddy)
- 🐘 PHP-FPM service
- 🗄️ MariaDB/MySQL service
- 🌍 Website accessibility (HTTP/HTTPS)
- 💾 phpMyAdmin accessibility
- 🔗 Database connection
- 📁 TorrentPier files presence
- 📦 Composer dependencies
- ⏰ Cron job configuration
- 🔒 File permissions

### Configuration file locations:
**NGINX:**
- phpMyAdmin config: `/etc/nginx/sites-available/00-phpmyadmin.conf`
- TorrentPier config: `/etc/nginx/sites-available/01-torrentpier.conf`
- Example config: `examples/nginx.conf`

**Apache:**
- phpMyAdmin config: `/etc/apache2/sites-available/00-phpmyadmin.conf`
- TorrentPier config: `/etc/apache2/sites-available/01-torrentpier.conf`
- Example config: `examples/apache.conf`

**Caddy:**
- Main config: `/etc/caddy/Caddyfile`
- Example config: `examples/caddy.conf`

### Security features:

**NGINX and Caddy configurations include:**
- **Directory blocking:** Prevents access to `/install/`, `/internal_data/`, `/library/`
- **Hidden files protection:** Blocks access to `.ht*`, `.en*`, `.git/`
- **File type restrictions:** Denies access to `.sql`, `.tpl`, `.db`, `.inc`, `.log`, `.md` files
- **Sitemap redirect:** Automatically redirects `/sitemap.xml` to `/sitemap/sitemap.xml`
- **Gzip/Zstd compression:** Reduces bandwidth usage (Caddy)
- **UTF-8 charset:** Proper charset headers for HTML, CSS, JS, JSON, XML, TXT files (Caddy)

**Apache configuration:**
- Minimal setup with `AllowOverride All` enabled
- TorrentPier's `.htaccess` file handles all security rules automatically

## Removing phpMyAdmin public access:

### For NGINX:
```bash
rm /etc/nginx/sites-enabled/00-phpmyadmin.conf
nginx -t
systemctl restart nginx
```

### For Apache:
```bash
a2dissite 00-phpmyadmin
apache2ctl configtest
systemctl restart apache2
```

### For Caddy:
Edit `/etc/caddy/Caddyfile` and remove the phpMyAdmin section, then:
```bash
systemctl reload caddy
```
