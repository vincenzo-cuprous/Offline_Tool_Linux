#!/bin/bash

source modules/utils.sh

# Cache directory
CACHE_DIR="/tmp/package_backup_cache"
CACHE_FILE="${CACHE_DIR}/package_list"
CACHE_TIMEOUT=3600  # 1 hour in seconds

# Initialize cache
init_cache() {
    mkdir -p "$CACHE_DIR"
}

# Check if cache is valid
is_cache_valid() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 1
    fi

    local cache_time=$(stat -c %Y "$CACHE_FILE")
    local current_time=$(date +%s)
    local age=$((current_time - cache_time))

    if [ $age -gt $CACHE_TIMEOUT ]; then
        return 1
    fi
    return 0
}

# Get list of installed packages (optimized)
get_installed_packages() {
    init_cache

    if is_cache_valid; then
        cat "$CACHE_FILE"
        return
    fi

    # Use expac for faster package listing
    if command -v expac >/dev/null 2>&1; then
        expac -Q '%n %v' > "$CACHE_FILE"
    else
        # Fallback to pacman with optimization
        pacman -Q --color never > "$CACHE_FILE"
    fi

    cat "$CACHE_FILE"
}

# Display packages with numbers (optimized)
display_packages() {
    local tempfile="/tmp/package_list_formatted"
    print_info "Loading installed packages..."

    # Create header
    printf "%-4s %-30s %-20s\n" "No." "Package Name" "Version" > "$tempfile"
    echo "------------------------------------------------" >> "$tempfile"

    # Process packages in batches using awk for faster processing
    get_installed_packages | awk '
    BEGIN { count = 1 }
    {
        printf "%-4d %-30s %-20s\n", count++, $1, $2
    }' >> "$tempfile"

    # Display using less for better navigation
    less -R "$tempfile"
    rm "$tempfile"
}

# Get package files and their locations (optimized)
get_package_files() {
    local package="$1"
    pacman -Qlq "$package" 2>/dev/null
}

# Verify package exists (optimized with cache)
verify_package() {
    local package="$1"
    grep -q "^$package " "$CACHE_FILE"
    return $?
}
