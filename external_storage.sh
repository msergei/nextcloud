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

# Check if NEXTCLOUD_ADMIN_USER is set
if [ -z "$NEXTCLOUD_ADMIN_USER" ]; then
    log_error "NEXTCLOUD_ADMIN_USER not set in .env file!"
    exit 1
fi

log_info "Target admin user: $NEXTCLOUD_ADMIN_USER"

# Check if Nextcloud container is running
if ! docker compose ps | grep -q "cloud.*Up"; then
    log_error "Nextcloud container is not running! Please start with: docker compose up -d"
    exit 1
fi

log_info "Setting up Books external storage..."

# Enable External Storage app
log_info "Enabling External Storage app..."
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ app:enable files_external"

# Wait a moment for app to be fully enabled
sleep 2

# Get list of existing users
log_info "Getting list of Nextcloud users..."
USERS_OUTPUT=$(docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ user:list --output=json" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$USERS_OUTPUT" ]; then
    log_error "Failed to get user list. Trying alternative method..."
    USERS_LIST=$(docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ user:list" 2>/dev/null | grep -o '^[^:]*')
    log_info "Available users: $USERS_LIST"
    
    # Use first available user if NEXTCLOUD_ADMIN_USER not found
    FIRST_USER=$(echo "$USERS_LIST" | head -n1 | tr -d ' ')
    if [ -n "$FIRST_USER" ]; then
        TARGET_USER="$FIRST_USER"
        log_warn "Using first available user: $TARGET_USER"
    else
        log_error "No users found in Nextcloud!"
        exit 1
    fi
else
    # Check if target user exists in JSON output
    if echo "$USERS_OUTPUT" | grep -q "\"$NEXTCLOUD_ADMIN_USER\""; then
        TARGET_USER="$NEXTCLOUD_ADMIN_USER"
        log_info "Found target user: $TARGET_USER"
    else
        # Get first user from JSON
        TARGET_USER=$(echo "$USERS_OUTPUT" | grep -o '"[^"]*"' | head -n1 | tr -d '"')
        log_warn "User '$NEXTCLOUD_ADMIN_USER' not found. Using: $TARGET_USER"
    fi
fi

if [ -z "$TARGET_USER" ]; then
    log_error "No valid user found!"
    exit 1
fi

# Create Books external storage
log_info "Creating Books external storage..."
CREATE_OUTPUT=$(docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files_external:create 'Books' local null::null -c datadir=/mnt/shared_books/Books" 2>/dev/null)

# Extract storage ID from output
BOOKS_ID=$(echo "$CREATE_OUTPUT" | grep -o 'Storage created with id [0-9]*' | grep -o '[0-9]*')

if [ -z "$BOOKS_ID" ]; then
    # Try alternative extraction method
    BOOKS_ID=$(echo "$CREATE_OUTPUT" | tail -n1 | grep -o '[0-9]*' | head -n1)
fi

if [ -n "$BOOKS_ID" ]; then
    log_info "Books storage created with ID: $BOOKS_ID"
    
    # Make it available to target user
    log_info "Making Books available to user: $TARGET_USER"
    docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files_external:applicable $BOOKS_ID --add-user=$TARGET_USER"
    
    if [ $? -eq 0 ]; then
        log_info "Successfully assigned Books storage to user: $TARGET_USER"
    else
        log_error "Failed to assign storage to user"
    fi
    
    # Set as read-only (remove this section if you want write access)
    log_warn "Setting Books storage as read-only..."
    docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files_external:option $BOOKS_ID readonly true"
    
else
    log_error "Failed to create Books storage"
    log_error "Output: $CREATE_OUTPUT"
    exit 1
fi

# List all external storages
log_info "Current external storages:"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ files_external:list"

log_info "Books storage setup completed!"
log_info "Books folder will appear in Nextcloud as 'Books' external storage for user: $TARGET_USER"
log_warn "Files remain owned by your original user, so other containers keep access"
