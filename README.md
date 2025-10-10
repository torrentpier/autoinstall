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
# Default installation (NGINX, v2.4)
./autoinstall/install.sh

# With custom options
./autoinstall/install.sh --webserver nginx --version v2.4
./autoinstall/install.sh --webserver apache --version v2.8
./autoinstall/install.sh --webserver caddy --version v2.4
```

**Available options:**
- `--webserver <nginx|apache|caddy>` - Choose web server (default: nginx)
- `--version <v2.4|v2.8>` - Choose TorrentPier version (default: v2.4)
- `--help` - Show help message

> [!NOTE]
> install.sh always downloads the latest release.\
> If you want to run it directly, use deb.install.sh for Debian and Ubuntu.

**Running the installation script directly for debian and ubuntu**
```bash
chmod +x ./autoinstall/deb.install.sh && ./autoinstall/deb.install.sh --webserver nginx --version v2.4
```
## Additional information:
- **Web server:** NGINX/Apache/Caddy + PHP 8.4-FPM (configurable)
- **PHP version:** 8.4 (latest from Ondřej Surý's repository)
- **Cron schedule:** Every 10 minutes
- **Installation logs directory:** /var/log/torrentpier_install.log
- **Temporary directory:** /tmp/torrentpier
- **The file with the data after installation:** /root/torrentpier.cfg

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
