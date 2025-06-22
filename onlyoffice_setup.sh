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

# Check if required variables exist
if [ -z "$OFFICE_DOMAIN" ]; then
    log_error "OFFICE_DOMAIN not found in .env file!"
    exit 1
fi

if [ -z "$ONLYOFFICE_JWT_SECRET" ]; then
    log_error "ONLYOFFICE_JWT_SECRET not found in .env file!"
    exit 1
fi

log_info "Configuring OnlyOffice integration..."
log_info "Office domain: https://$OFFICE_DOMAIN"

# Check if Nextcloud container is running
if ! docker compose ps | grep -q "cloud.*Up"; then
    log_error "Nextcloud container is not running! Please start with: docker compose up -d"
    exit 1
fi

# Enable OnlyOffice app
log_info "Enabling OnlyOffice app..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ app:enable onlyoffice" || {
    log_warn "OnlyOffice app might not be installed. Please install it from Nextcloud app store first."
}

# Configure system settings for self-signed certificates
log_info "Configuring system settings..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:set allow_local_remote_servers --value=true"

# Configure OnlyOffice settings
log_info "Setting OnlyOffice Document Server URL..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:app:set onlyoffice DocumentServerUrl --value='https://$OFFICE_DOMAIN/'"

# Remove internal URL if exists (for separate deployments)
log_info "Removing internal URL (using external URL only)..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:app:delete onlyoffice DocumentServerInternalUrl" 2>/dev/null || true

# Configure JWT settings
log_info "Setting JWT secret..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:app:set onlyoffice jwt_secret --value='$ONLYOFFICE_JWT_SECRET'"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:app:set onlyoffice jwt_header --value='Authorization'"

# Configure SSL settings for self-signed certificates
log_info "Configuring SSL settings..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:app:set onlyoffice verify_peer_off --value=true"

# Configure storage URL (for file access)
log_info "Setting storage URL..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:app:set onlyoffice StorageUrl --value='https://$NEXTCLOUD_DOMAIN/'"

# Add OnlyOffice domain to trusted domains
log_info "Adding OnlyOffice domain to trusted domains..."
DOMAIN_COUNT=$(docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:get trusted_domains | wc -l" 2>/dev/null || echo "0")
NEXT_INDEX=$((DOMAIN_COUNT))
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:set trusted_domains $NEXT_INDEX --value='$OFFICE_DOMAIN'"

# Test connection
log_info "Testing OnlyOffice connection..."
CONNECTION_TEST=$(docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ onlyoffice:documentserver --check" 2>&1)

if echo "$CONNECTION_TEST" | grep -q "successfully"; then
    log_info "OnlyOffice connection test: SUCCESS"
else
    log_warn "OnlyOffice connection test failed. Check the output:"
    echo "$CONNECTION_TEST"
fi

# Display current configuration
log_info "Current OnlyOffice configuration:"
echo "Document Server URL:"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:app:get onlyoffice DocumentServerUrl"
echo "JWT Secret configured: $([ -n "$(docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:app:get onlyoffice jwt_secret" 2>/dev/null)" ] && echo "Yes" || echo "No")"
echo "SSL verification: $(docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:app:get onlyoffice verify_peer_off" 2>/dev/null || echo "default")"

log_info "OnlyOffice configuration completed!"
log_warn "If you're using self-signed certificates, make sure to accept them in your browser first:"
log_warn "Visit https://$OFFICE_DOMAIN and accept the certificate"
