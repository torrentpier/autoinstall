## Automatic installation for TorrentPier v2.4.*
**This shell script allows you to:**
- Install TorrentPier v2.4.* in automatic mode;
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
./autoinstall/install.sh
```
> [!NOTE]
> install.sh always downloads the latest release.\
> If you want to run it directly, use deb.install.sh for Debian and Ubuntu.

**Running the installation script directly for debian and ubuntu**
```bash
chmod +x ./autoinstall/deb.install.sh && ./autoinstall/deb.install.sh
```
## Additional information:
- **Web server:** NGINX + PHP-FPM
- **NGINX config for phpMyAdmin:** /etc/nginx/sites-available/00-phpmyadmin.conf
- **NGINX config for TorrentPier:** /etc/nginx/sites-available/01-torrentpier.conf
- **Installation logs directory:** /var/log/torrentpier_install.log
- **Temporary directory:** /tmp/torrentpier
- **The file with the data after installation:** /root/torrentpier.cfg
## Removing phpMyAdmin public access:
**Removing the symbolic link**
```bash
rm /etc/nginx/sites-enabled/00-phpmyadmin.conf
```
**We check the current NGINX configs for errors**
```bash
nginx -t
```
**Restarting the NGINX process**
```bash
systemctl restart nginx
```
