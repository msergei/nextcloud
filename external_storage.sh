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

# Load .env file
if [ -f .env ]; then
    set -a
    source .env
    set +a
    log_info "Loaded .env file"
else
    log_error ".env file not found!"
    exit 1
fi

# Check if Nextcloud container is running
if ! docker compose ps | grep -q "cloud.*Up"; then
    log_error "Nextcloud container is not running! Please start with: docker compose up -d"
    exit 1
fi

log_info "Cleaning up existing Books external storages..."

# Get list of existing external storages
EXISTING_STORAGES=$(docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files_external:list --output=json" 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$EXISTING_STORAGES" ]; then
    # Extract IDs of Books storages
    BOOKS_IDS=$(echo "$EXISTING_STORAGES" | grep -B5 -A5 "Books" | grep -o '"[0-9]*"' | tr -d '"' | sort -u)
    
    if [ -n "$BOOKS_IDS" ]; then
        log_warn "Found existing Books storages with IDs: $BOOKS_IDS"
        for ID in $BOOKS_IDS; do
            log_info "Removing Books storage with ID: $ID"
            docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files_external:delete $ID" 2>/dev/null
        done
    fi
else
    log_warn "Could not get existing storages list, proceeding anyway..."
fi

# Enable External Storage app
log_info "Ensuring External Storage app is enabled..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ app:enable files_external"

# Wait a moment
sleep 2

# Create new Books external storage for ALL users
log_info "Creating Books external storage for ALL users..."
CREATE_OUTPUT=$(docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files_external:create 'Books' local null::null -c datadir=/mnt/shared_books/Books" 2>/dev/null)

# Extract storage ID
BOOKS_ID=$(echo "$CREATE_OUTPUT" | grep -o 'Storage created with id [0-9]*' | grep -o '[0-9]*')

if [ -z "$BOOKS_ID" ]; then
    BOOKS_ID=$(echo "$CREATE_OUTPUT" | tail -n1 | grep -o '[0-9]*' | head -n1)
fi

if [ -n "$BOOKS_ID" ]; then
    log_info "Books storage created with ID: $BOOKS_ID"
    
    # Make it available to ALL users (don't specify any user)
    log_info "Making Books available to ALL users..."
    # По умолчанию external storage доступен всем, если не указать конкретных пользователей
    
    # Set permissions - remove read-only if you want write access
    log_warn "Setting Books storage as read-only..."
    docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files_external:option $BOOKS_ID readonly true"
    
    # Optional: Set priority (higher number = higher priority)
    docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files_external:option $BOOKS_ID priority 100"
    
else
    log_error "Failed to create Books storage"
    log_error "Output: $CREATE_OUTPUT"
    exit 1
fi

# List all external storages
log_info "Current external storages:"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files_external:list"

log_info "Books storage setup completed!"
log_info "Books folder will appear in Nextcloud as 'Books' external storage for ALL users"
log_warn "Files remain owned by your original user, so other containers keep access"

# Optional: Trigger files scan for all users
log_info "Triggering files scan for all users..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files:scan --all"

log_info "Setup complete! All users should now see Books in their file manager."
