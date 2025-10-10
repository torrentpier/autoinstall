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
  --help                             Show this help message
```

## What's New

### Changes in this version:
1. **Web Server Selection** - Choose between NGINX, Apache, or Caddy
2. **Version Selection** - Install either v2.4.x or v2.8.x of TorrentPier
3. **Cron Interval** - Changed from 1 minute to 10 minutes for better performance
4. **PHP 8.4** - Automatic installation of PHP 8.4 from Ondřej Surý's repository

### Default Values:
- Web Server: `nginx`
- TorrentPier Version: `v2.4`
- PHP Version: `8.4` (automatically installed)
- Cron Schedule: `*/10 * * * *` (every 10 minutes)

## Post-Installation

After installation, you'll find credentials in:
```
/root/torrentpier.cfg
```

### Access Points:
- **TorrentPier:** `http://YOUR_HOST/`
- **phpMyAdmin:** `http://YOUR_HOST:9090/phpmyadmin`

### Log File:
```
/var/log/torrentpier_install.log
```

