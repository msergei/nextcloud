#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions for output
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if .env file exists
if [ ! -f .env ]; then
    log_error ".env file not found!"
    exit 1
fi

# Load variables from .env
set -a
source .env
set +a

# Check if NEXTCLOUD_DOMAIN variable exists
if [ -z "$NEXTCLOUD_DOMAIN" ]; then
    log_error "NEXTCLOUD_DOMAIN not found in .env file!"
    exit 1
fi

log_info "Using domain: $NEXTCLOUD_DOMAIN"

# Check if containers are running
if ! docker compose ps | grep -q "cloud.*Up"; then
    log_error "Nextcloud container is not running! Please start with: docker compose up -d"
    exit 1
fi

log_info "Starting Nextcloud configuration..."

# Maintenance tasks
log_info "Running maintenance repair..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ maintenance:repair --include-expensive"

log_info "Adding missing database indices..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ db:add-missing-indices"

# Protocol and domain settings
log_info "Setting up HTTPS protocol..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:set overwriteprotocol --value='https'"

log_info "Setting up CLI URL..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:set overwrite.cli.url --value='https://$NEXTCLOUD_DOMAIN'"

log_info "Setting up overwrite host..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:set overwritehost --value='$NEXTCLOUD_DOMAIN'"

# Trusted proxies configuration (as JSON array)
log_info "Configuring trusted proxies..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:set trusted_proxies --type json --value='[\"10.20.0.0/16\", \"nginx\"]'"

# Forwarded headers configuration (as JSON array)
log_info "Configuring forwarded headers..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:set forwarded_for_headers --type json --value='[\"HTTP_X_FORWARDED_FOR\", \"HTTP_X_FORWARDED_PROTO\", \"HTTP_X_REAL_IP\"]'"

# Additional system settings
log_info "Setting default phone region..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:set default_phone_region --value='US'"

log_info "Setting maintenance window..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:set maintenance_window_start --type integer --value=1"

# WOPI allowlist for Collabora
log_info "Configuring WOPI allowlist for Collabora..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:app:set richdocuments wopi_allowlist --value='$NEXTCLOUD_DOMAIN'"

# Configuration verification
log_info "Checking configuration..."
echo "Current overwrite settings:"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:get overwriteprotocol"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:get overwritehost"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:get overwrite.cli.url"

echo "Current trusted proxies:"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:get trusted_proxies"

echo "Current forwarded headers:"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:get forwarded_for_headers"

log_info "Nextcloud configuration completed successfully!"
docker compose restart
log_warn "Don't forget to configure email settings in Admin panel -> Basic settings"
