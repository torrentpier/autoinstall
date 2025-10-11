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
- TorrentPier Version: `v2.8`
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

## Web Server Configuration Examples

The repository includes example configurations for all supported web servers in the `examples/` directory:

### NGINX Configuration
Example file: `examples/nginx.conf`

This configuration includes:
- Security rules for blocking sensitive directories and files
- PHP-FPM integration
- Sitemap redirect
- UTF-8 charset support

### Apache Configuration
Example file: `examples/apache.conf`

This configuration includes:
- PHP-FPM proxy configuration
- AllowOverride All (enables .htaccess)
- Logging configuration

**Note:** TorrentPier includes its own `.htaccess` file with all necessary security rules, so the Apache configuration is kept minimal with `AllowOverride All` enabled to allow `.htaccess` to work properly.

### Caddy Configuration
Example file: `examples/caddy.conf`

This configuration includes:
- Automatic HTTPS support
- Gzip and Zstd compression
- Security matchers for blocking sensitive paths
- Content-Type headers with UTF-8 charset
- Sitemap redirect

### Security Features

**NGINX and Caddy** configurations protect:
- **Sensitive directories:** `/install/`, `/internal_data/`, `/library/`
- **Hidden files:** `.ht*`, `.en*`, `.git/`
- **Sensitive file types:** `.sql`, `.tpl`, `.db`, `.inc`, `.log`, `.md`

**Apache** relies on TorrentPier's `.htaccess` file for all security rules.

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

