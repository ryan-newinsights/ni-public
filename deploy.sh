#!/bin/bash
# Deployment script for ni-public on Google VM
# Deploys the newinsights.ai landing page
#
# Usage: ./deploy.sh [--skip-ssl]
#   --skip-ssl  Skip SSL certificate generation (if already exists)

set -e

# Configuration
DOMAIN="newinsights.ai"
WEB_ROOT="/var/www/newinsights"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

SKIP_SSL=false
if [[ "$1" == "--skip-ssl" ]]; then
    SKIP_SSL=true
fi

log_info "Starting deployment of $DOMAIN..."

# Step 1: Install required packages
log_info "Checking and installing required packages..."
apt-get update -qq
apt-get install -y -qq nginx certbot python3-certbot-nginx

# Step 2: Create web root directory
log_info "Setting up web root at $WEB_ROOT..."
mkdir -p "$WEB_ROOT"

# Step 3: Copy index.html
log_info "Copying website files..."
cp "$SCRIPT_DIR/index.html" "$WEB_ROOT/index.html"
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"

# Step 4: Set up SSL certificates (if not skipping)
if [[ "$SKIP_SSL" == false ]]; then
    if [[ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        log_info "Obtaining SSL certificate for $DOMAIN..."

        # Stop nginx temporarily for standalone certificate
        systemctl stop nginx || true

        # Get certificate for apex and www
        certbot certonly --standalone \
            -d "$DOMAIN" \
            -d "www.$DOMAIN" \
            --non-interactive \
            --agree-tos \
            --email "admin@$DOMAIN" \
            --expand

        # Generate DH params if not exists
        if [[ ! -f "/etc/letsencrypt/ssl-dhparams.pem" ]]; then
            log_info "Generating DH parameters (this may take a while)..."
            openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048
        fi

        # Create options-ssl-nginx.conf if not exists
        if [[ ! -f "/etc/letsencrypt/options-ssl-nginx.conf" ]]; then
            log_info "Creating SSL options file..."
            cat > /etc/letsencrypt/options-ssl-nginx.conf <<'EOF'
ssl_session_cache shared:le_nginx_SSL:10m;
ssl_session_timeout 1440m;
ssl_session_tickets off;
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
EOF
        fi
    else
        log_info "SSL certificate already exists, skipping..."
    fi
else
    log_warn "Skipping SSL certificate generation (--skip-ssl flag)"
fi

# Step 5: Install nginx configuration
log_info "Installing nginx configuration..."
cp "$SCRIPT_DIR/nginx.conf" "$NGINX_AVAILABLE/newinsights"

# Remove default site if it exists and points to default config
if [[ -L "$NGINX_ENABLED/default" ]]; then
    log_info "Removing default nginx site..."
    rm -f "$NGINX_ENABLED/default"
fi

# Create symlink if not exists
if [[ ! -L "$NGINX_ENABLED/newinsights" ]]; then
    ln -s "$NGINX_AVAILABLE/newinsights" "$NGINX_ENABLED/newinsights"
fi

# Step 6: Test and reload nginx
log_info "Testing nginx configuration..."
if nginx -t; then
    log_info "Nginx configuration is valid"
    systemctl enable nginx
    systemctl restart nginx
    log_info "Nginx restarted successfully"
else
    log_error "Nginx configuration test failed!"
    exit 1
fi

# Step 7: Set up automatic certificate renewal
log_info "Setting up automatic SSL renewal..."
if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    log_info "Added certbot renewal cron job"
fi

log_info "========================================"
log_info "Deployment complete!"
log_info "========================================"
log_info ""
log_info "Your site should now be available at:"
log_info "  https://$DOMAIN"
log_info ""
log_info "Notes:"
log_info "  - Static files are served from: $WEB_ROOT"
log_info "  - Nginx config is at: $NGINX_AVAILABLE/newinsights"
log_info "  - SSL certificates renew automatically"
log_info ""
log_info "If you have a Flask backend, make sure it's running on port 8000"
log_info "for the /login, /auth, and /static routes to work."
