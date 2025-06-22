#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Nextcloud container is running
if ! docker compose ps | grep -q "cloud.*Up"; then
    log_error "Nextcloud container is not running! Please start with: docker compose up -d"
    exit 1
fi

log_info "Setting up Books external storage..."

# Enable External Storage app
log_info "Enabling External Storage app..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ app:enable files_external"

# Create Books external storage
log_info "Creating Books external storage..."
BOOKS_ID=$(docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files_external:create 'Books' local null::null -c datadir=/mnt/shared_books/Books" | tail -n1 | grep -o '[0-9]*')

if [ -n "$BOOKS_ID" ]; then
    log_info "Books storage created with ID: $BOOKS_ID"
    
    # Make it available to admin user
    log_info "Making Books available to admin user..."
    docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files_external:applicable $BOOKS_ID --add-user=${NEXTCLOUD_ADMIN_USER:-admin}"
    
    # Set as read-only (optional, remove this line if you want write access)
    log_warn "Setting Books storage as read-only..."
    docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files_external:option $BOOKS_ID readonly true"
    
else
    log_error "Failed to create Books storage"
    exit 1
fi

# List all external storages
log_info "Current external storages:"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files_external:list"

log_info "Books storage setup completed!"
log_info "Books folder will appear in Nextcloud as 'Books' external storage"
log_warn "Files remain owned by your original user, so other containers keep access"
