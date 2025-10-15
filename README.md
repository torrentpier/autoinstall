## Automatic installation for TorrentPier
**This shell script allows you to:**
- Install TorrentPier (v2.4 or v2.8) in automatic mode;
- Choose web server (NGINX, Apache, or Caddy);
- Flexible configuration with command-line arguments;
## Supported systems:
- **GNU/Linux:** Debian 12 and newer
- **GNU/Linux:** Ubuntu 22.04, 24.04 and newer
> [!IMPORTANT]
> The architecture and bit depth of x86_64 are required.
> 
> Minimum supported versions: **Debian 12** and **Ubuntu 22.04**
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
# Default installation (NGINX, v2.8, SSL auto)
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

# Enable Manticore Search (for v2.8 with 4GB+ RAM)
./autoinstall/install.sh --version v2.8 --manticore yes

# Disable Manticore Search (use MySQL for search)
./autoinstall/install.sh --version v2.8 --manticore no
```

**Available options:**
- `--webserver <nginx|apache|caddy>` - Choose web server (default: nginx)
- `--version <v2.4|v2.8>` - Choose TorrentPier version (default: v2.8)
- `--php-version <8.2|8.3|8.4>` - Choose PHP version (default: 8.4)
- `--ssl <auto|yes|no>` - Enable SSL/TLS (default: auto - enabled for domains only)
- `--email <email@example.com>` - Email for SSL certificate (required if domain is used)
- `--manticore <auto|yes|no>` - Enable Manticore Search for v2.8 (default: auto - enabled if RAM >= 4GB)
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
- **Manticore Search:** For v2.8, requires 4GB RAM minimum (RT indexes, auto-enabled if RAM >= 4GB)
- **SSL/TLS:** Automatic Let's Encrypt certificates (for domains)
  - **Caddy:** Built-in automatic HTTPS
  - **NGINX/Apache:** Certbot with auto-renewal
- **Cron schedule:** Every 10 minutes
- **Installation logs directory:** /var/log/torrentpier_install.log
- **Temporary directory:** /tmp/torrentpier
- **The file with the data after installation:** /root/torrentpier.cfg
- **Lock file:** /var/lock/torrentpier_install.lock (prevents concurrent installations)

### Troubleshooting:
If you encounter any issues during installation:

1. **Check the installation log:**
   ```bash
   tail -100 /var/log/torrentpier_install.log
   ```

2. **Common issues:**
   - Package installation fails → Log will show detailed APT errors
   - PHP-FPM won't start → Check `sudo systemctl status php8.4-fpm`
   - Ports occupied → Use `sudo ss -tulpn | grep ':80\|:443\|:9090'`

### Configuration file locations:
**NGINX:**
- phpMyAdmin config: `/etc/nginx/sites-available/00-phpmyadmin.conf`
- TorrentPier config: `/etc/nginx/sites-available/01-torrentpier.conf`

**Apache:**
- phpMyAdmin config: `/etc/apache2/sites-available/00-phpmyadmin.conf`
- TorrentPier config: `/etc/apache2/sites-available/01-torrentpier.conf`

**Caddy:**
- Main config: `/etc/caddy/Caddyfile`

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
