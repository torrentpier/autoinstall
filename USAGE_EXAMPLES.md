# TorrentPier AutoInstall - Usage Examples

## Quick Start

### Default Installation (NGINX + v2.8)
```bash
./autoinstall/install.sh
```

## Custom Installations

### Install with Apache and v2.4
```bash
./autoinstall/install.sh --webserver apache --version v2.4
```

### Install with Caddy and v2.8
```bash
./autoinstall/install.sh --webserver caddy --version v2.8
```

### Install with NGINX and v2.8
```bash
./autoinstall/install.sh --webserver nginx --version v2.8
```

## Manticore Search Configuration (v2.8 only)

### Automatic Manticore Installation (recommended)
```bash
# Manticore will be automatically installed if RAM >= 4GB
./autoinstall/install.sh --version v2.8
```

### Force Enable Manticore Search
```bash
# Force installation of Manticore Search (requires 4GB+ RAM)
./autoinstall/install.sh --version v2.8 --manticore yes
```

### Disable Manticore Search (use MySQL)
```bash
# Use MySQL for search instead of Manticore
./autoinstall/install.sh --version v2.8 --manticore no
```

> **Note:** Manticore Search requires at least 4GB of RAM. If your system has less RAM, use `--manticore no` to use MySQL for search instead.

### Manticore Search Features:
- **RT (Real-Time) indexes** - Fast full-text search
- **Automatic fallback to MySQL** - If Manticore is unavailable, searches will use MySQL
- **Configuration:**
  - Host: `127.0.0.1`
  - Port: `9306` (MySQL protocol)
  - Config location: `/etc/manticoresearch/manticore.conf`
  
### Check Manticore Status:
```bash
# Check if Manticore is running
systemctl status manticore

# View Manticore logs
journalctl -u manticore -f

# Connect to Manticore via MySQL client
mysql -h 127.0.0.1 -P 9306
```

## SSL/HTTPS Configurations

### Automatic SSL for domain (recommended)
```bash
# SSL will be automatically configured when you enter a domain
./autoinstall/install.sh --webserver nginx --email admin@example.com
```

### Caddy with automatic HTTPS
```bash
# Caddy automatically obtains and renews SSL certificates
./autoinstall/install.sh --webserver caddy --email admin@example.com
```

### Disable SSL (HTTP only)
```bash
# Use this for local development or if you have external SSL termination
./autoinstall/install.sh --webserver nginx --ssl no
```

### Force SSL even for IP (not recommended)
```bash
# This will fail, as Let's Encrypt requires a domain
./autoinstall/install.sh --webserver nginx --ssl yes
# Note: If you enter an IP, SSL will be automatically disabled with a warning
```

## Direct Installation (Skip Download)

If you've already cloned the repository:

```bash
# Make script executable
chmod +x ./autoinstall/deb.install.sh

# Run with options
./autoinstall/deb.install.sh --webserver nginx --version v2.4
```

## Get Help

```bash
./autoinstall/deb.install.sh --help
```

Output:
```
Usage: ./autoinstall/deb.install.sh [OPTIONS]

Options:
  --webserver <nginx|apache|caddy>  Choose web server (default: nginx)
  --version <v2.4|v2.8>              Choose TorrentPier version (default: v2.8)
  --php-version <8.2|8.3|8.4>        Choose PHP version (default: 8.4)
  --ssl <auto|yes|no>                Enable SSL/TLS (default: auto - only for domains)
  --email <email@example.com>        Email for SSL certificate (required if domain is used)
  --manticore <auto|yes|no>          Enable Manticore Search for v2.8 (default: auto - only if RAM >= 4GB)
  --dry-run                          Test mode - check requirements without installing
  --help                             Show this help message
```

## Post-Installation

After installation, you'll find credentials in:
```
/root/torrentpier.cfg
```

### Access Points:
- **TorrentPier:** `https://YOUR_DOMAIN/` (or `http://YOUR_IP/` for IP-based installs)
- **phpMyAdmin:** `https://YOUR_DOMAIN:9090/`

> **Note:** If you used a domain, the script automatically configures HTTPS. First access may take a few seconds while certificates are obtained (especially with Caddy).

### SSL Certificate Information:
- **Location (NGINX/Apache):** `/etc/letsencrypt/live/YOUR_DOMAIN/`
- **Auto-renewal:** Certificates renew automatically 30 days before expiration
- **Manual renewal (if needed):**
  ```bash
  # For NGINX
  certbot renew --nginx
  
  # For Apache
  certbot renew --apache
  
  # For Caddy (automatic, but can force)
  caddy reload --config /etc/caddy/Caddyfile
  ```

### Log File:
```
/var/log/torrentpier_install.log
```

### Manual Configuration

If you need to manually configure your web server, you can:

1. Copy the example configuration:
   ```bash
   # For NGINX
   cp examples/nginx.conf /etc/nginx/sites-available/torrentpier.conf
   
   # For Apache
   cp examples/apache.conf /etc/apache2/sites-available/torrentpier.conf
   
   # For Caddy
   cp examples/caddy.conf /etc/caddy/Caddyfile
   ```

2. Edit the configuration:
   - Replace `example.com` with your domain or IP
   - Replace `/path/to/www` with `/var/www/torrentpier`
   - Replace `/run/php/php-fpm.sock` with `/run/php/php8.4-fpm.sock`

3. Enable and restart the web server:
   ```bash
   # For NGINX
   ln -s /etc/nginx/sites-available/torrentpier.conf /etc/nginx/sites-enabled/
   nginx -t
   systemctl restart nginx
   
   # For Apache
   a2ensite torrentpier
   apache2ctl configtest
   systemctl restart apache2
   
   # For Caddy
   caddy validate --config /etc/caddy/Caddyfile
   systemctl reload caddy
   ```
