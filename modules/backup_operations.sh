#!/bin/bash

source modules/utils.sh

# Backup binary files
backup_binaries() {
    local package="$1"
    local backup_dir="$2"
    local files=($(pacman -Qlq "$package" | grep -E '/bin/|/sbin/|/lib/|/lib64/'))

    if [ ${#files[@]} -eq 0 ]; then
        print_warning "No binary files found for $package"
        return
    fi

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            local dest="$backup_dir/binaries/${file#/}"
            mkdir -p "$(dirname "$dest")"
            cp -a "$file" "$dest"
        fi
    done
    print_info "Binary files backed up successfully"
}

# Backup configuration files
backup_configs() {
    local package="$1"
    local backup_dir="$2"

    # System configs
    local etc_files=($(find /etc -name "*$package*" 2>/dev/null))
    for file in "${etc_files[@]}"; do
        if [ -f "$file" ]; then
            local dest="$backup_dir/configs/${file#/}"
            mkdir -p "$(dirname "$dest")"
            cp -a "$file" "$dest"
        fi
    done

    print_info "Configuration files backed up successfully"
}

# Backup user settings
backup_user_settings() {
    local package="$1"
    local backup_dir="$2"

    # Get all user home directories
    local user_homes=($(awk -F: '$7 != "/sbin/nologin" && $7 != "/bin/false" {print $6}' /etc/passwd))

    for home in "${user_homes[@]}"; do
        if [ -d "$home" ]; then
            # Backup .config directory settings
            local config_files=($(find "$home/.config" -name "*$package*" 2>/dev/null))
            for file in "${config_files[@]}"; do
                if [ -f "$file" ]; then
                    local dest="$backup_dir/user_settings/${file#/}"
                    mkdir -p "$(dirname "$dest")"
                    cp -a "$file" "$dest"
                fi
            done

            # Backup dot files
            local dot_files=($(find "$home" -maxdepth 1 -name ".$package*" 2>/dev/null))
            for file in "${dot_files[@]}"; do
                if [ -f "$file" ]; then
                    local dest="$backup_dir/user_settings/${file#/}"
                    mkdir -p "$(dirname "$dest")"
                    cp -a "$file" "$dest"
                fi
            done
        fi
    done

    print_info "User settings backed up successfully"
}

# Create backup archive
# Create backup archive
create_backup_archive() {
    local package="$1"
    local backup_dir="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    # Create backups directory in user's home
    local backup_storage="$HOME/package_backups"
    mkdir -p "$backup_storage"

    local archive_name="$backup_storage/${package}_backup_${timestamp}.tar.gz"

    tar -czf "$archive_name" -C "$backup_dir" .
    print_info "Backup archive created: $archive_name"

    # Cleanup temporary backup directory
    rm -rf "$backup_dir"

    # Print backup size
    local size=$(du -h "$archive_name" | cut -f1)
    print_info "Backup size: $size"
    print_info "Backup location: $archive_name"
}
# Added functions for backup management
list_backups() {
    local backup_storage="$HOME/package_backups"
    if [ -d "$backup_storage" ]; then
        echo "Available backups in $backup_storage:"
        ls -lh "$backup_storage"
    else
        print_warning "No backups found"
    fi
}

cleanup_old_backups() {
    local backup_storage="$HOME/package_backups"
    local days="$1"

    if [ -d "$backup_storage" ]; then
        find "$backup_storage" -name "*.tar.gz" -mtime +"$days" -delete
        print_info "Cleaned up backups older than $days days"
    fi
}
