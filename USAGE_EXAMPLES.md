# TorrentPier AutoInstall - Usage Examples

## Quick Start

### Default Installation (NGINX + v2.4)
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
  --version <v2.4|v2.8>              Choose TorrentPier version (default: v2.4)
  --ssl <auto|yes|no>                Enable SSL/TLS (default: auto - only for domains)
  --email <email@example.com>        Email for SSL certificate (required if domain is used)
  --help                             Show this help message
```

## What's New

### Changes in this version:
1. **Web Server Selection** - Choose between NGINX, Apache, or Caddy
2. **Version Selection** - Install either v2.4.x or v2.8.x of TorrentPier
3. **Automatic SSL/HTTPS** - Let's Encrypt certificates with auto-renewal
   - **Caddy:** Built-in automatic HTTPS (zero configuration)
   - **NGINX/Apache:** Certbot with automatic renewal via cron
   - **Smart Detection:** SSL auto-enabled for domains, disabled for IPs
4. **Cron Interval** - Changed from 1 minute to 10 minutes for better performance
5. **PHP 8.4** - Automatic installation of PHP 8.4 from Ondřej Surý's repository

### Default Values:
- Web Server: `nginx`
- TorrentPier Version: `v2.4`
- PHP Version: `8.4` (automatically installed)
- SSL: `auto` (enabled for domains, disabled for IPs)
- Cron Schedule: `*/10 * * * *` (every 10 minutes)
- SSL Auto-Renewal: Daily check at 3 AM (NGINX/Apache) or automatic (Caddy)

## Post-Installation

After installation, you'll find credentials in:
```
/root/torrentpier.cfg
```

### Access Points:
- **TorrentPier:** `https://YOUR_DOMAIN/` (or `http://YOUR_IP/` for IP-based installs)
- **phpMyAdmin:** `https://YOUR_DOMAIN:9090/phpmyadmin`

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

