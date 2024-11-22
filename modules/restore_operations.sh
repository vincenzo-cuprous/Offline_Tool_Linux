#!/bin/bash

source modules/utils.sh

list_available_backups() {
    # Existing implementation remains the same
    local backup_dir="$HOME/package_backups"
    if [ ! -d "$backup_dir" ]; then
        print_error "No backup directory found at $backup_dir"
        return 1
    fi

    local count=1
    echo "Available backups:"
    printf "%-4s %-40s %-20s %-10s\n" "No." "Package" "Date" "Size"
    echo "----------------------------------------------------------------"

    for backup in "$backup_dir"/*.tar.gz; do
        if [ -f "$backup" ]; then
            local filename=$(basename "$backup")
            local package=${filename%%_backup_*}
            local date_part=${filename#*_backup_}
            local date=${date_part%.tar.gz}
            local formatted_date=$(date -d "${date:0:8} ${date:9:6}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown date")
            local size=$(du -h "$backup" | cut -f1)
            printf "%-4s %-40s %-20s %-10s\n" "$count" "$package" "$formatted_date" "$size"
            ((count++))
        fi
    done

    if [ "$count" -eq 1 ]; then
        print_error "No backup archives found"
        return 1
    fi
    return 0
}

verify_backup() {
    # Existing implementation remains the same
    local backup_file="$1"
    local temp_dir="$2"

    if [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi

    print_info "Verifying backup integrity..."
    if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
        print_error "Backup archive is corrupted or invalid"
        return 1
    fi
    return 0
}

restore_package_dependencies() {
    local temp_dir="$1"
    local package_name="$2"

    if [ -f "$temp_dir/package_info/dependencies.txt" ]; then
        print_info "Installing package dependencies..."
        while IFS= read -r dep; do
            if ! pacman -Q "$dep" >/dev/null 2>&1; then
                print_info "Installing dependency: $dep"
                if ! sudo pacman -S --noconfirm "$dep"; then
                    print_warning "Failed to install dependency: $dep"
                fi
            fi
        done < "$temp_dir/package_info/dependencies.txt"
    fi
}

restore_binaries() {
    local temp_dir="$1"
    local binary_dir="$temp_dir/binaries"

    if [ -d "$binary_dir" ]; then
        print_info "Restoring binary files..."

        # Create a list of files to restore
        find "$binary_dir" -type f > "$temp_dir/files_to_restore.txt"

        # Restore files with proper permissions
        while IFS= read -r file; do
            local target_file="/${file#$binary_dir/}"
            local target_dir=$(dirname "$target_file")

            # Create directory if it doesn't exist
            sudo mkdir -p "$target_dir"

            # Backup existing file
            if [ -f "$target_file" ]; then
                sudo cp -a "$target_file" "$target_file.bak" 2>/dev/null
            fi

            # Copy file with preserved attributes
            if ! sudo cp -a --preserve=all "$file" "$target_file" 2>/dev/null; then
                print_warning "Failed to restore: $target_file"
            else
                # Set proper permissions
                if [[ "$target_file" == "/usr/bin/"* ]]; then
                    sudo chmod 755 "$target_file"
                fi
            fi
        done < "$temp_dir/files_to_restore.txt"

        # Update library cache
        if [ -d "$binary_dir/usr/lib" ]; then
            print_info "Updating library cache..."
            sudo ldconfig
        fi

        print_info "Binary files restored successfully"
    fi
}

register_package() {
    local temp_dir="$1"
    local package_name="$2"

    if [ -f "$temp_dir/package_info/package.info" ]; then
        print_info "Registering package in package manager..."

        # Extract package version
        local version=$(grep "^version=" "$temp_dir/package_info/package.info" | cut -d'=' -f2)

        # Register in pacman database
        if [ -n "$version" ]; then
            sudo pacman -D --asexplicit "$package_name"
            print_info "Package registered: $package_name $version"
        fi
    fi
}

perform_restore() {
    local backup_file="$1"
    local temp_dir="/tmp/package_restore_$$"
    local package_name=$(basename "$backup_file" | cut -d'_' -f1)

    mkdir -p "$temp_dir"

    if [ ! -d "$temp_dir" ]; then
        print_error "Failed to create temporary directory"
        return 1
    fi

    print_info "Verifying backup archive..."
    if ! verify_backup "$backup_file" "$temp_dir"; then
        rm -rf "$temp_dir"
        return 1
    fi

    print_info "Extracting backup archive..."
    if ! tar -xzf "$backup_file" -C "$temp_dir"; then
        print_error "Failed to extract backup archive"
        rm -rf "$temp_dir"
        return 1
    fi

    # Create a manifest of restored files
    local manifest_file="$HOME/package_backups/restore_manifest_$(date +%Y%m%d_%H%M%S).txt"

    # Restore dependencies first
    restore_package_dependencies "$temp_dir" "$package_name"

    # Perform restore operations
    restore_binaries "$temp_dir" 2>&1 | tee -a "$manifest_file"
    restore_configs() {
        local temp_dir="$1"
        local config_dir="$temp_dir/configs"

        if [ -d "$config_dir" ]; then
            print_info "Restoring configuration files..."

            # Create a list of files to restore
            find "$config_dir" -type f > "$temp_dir/config_files_to_restore.txt"

            # Restore config files with proper permissions
            while IFS= read -r file; do
                local target_file="/${file#$config_dir/}"
                local target_dir=$(dirname "$target_file")

                # Create directory if it doesn't exist
                sudo mkdir -p "$target_dir"

                # Backup existing file
                if [ -f "$target_file" ]; then
                    sudo cp -a "$target_file" "$target_file.bak" 2>/dev/null
                fi

                # Copy file with preserved attributes
                if ! sudo cp -a --preserve=all "$file" "$target_file" 2>/dev/null; then
                    print_warning "Failed to restore config: $target_file"
                fi
            done < "$temp_dir/config_files_to_restore.txt"

            print_info "Configuration files restored successfully"
        fi
    }

    restore_user_settings() {
        local temp_dir="$1"
        local settings_dir="$temp_dir/user_settings"

        if [ -d "$settings_dir" ]; then
            print_info "Restoring user settings..."

            # Create a list of files to restore
            find "$settings_dir" -type f > "$temp_dir/settings_to_restore.txt"

            # Restore user settings files
            while IFS= read -r file; do
                local target_file="$HOME/${file#$settings_dir/}"
                local target_dir=$(dirname "$target_file")

                # Create directory if it doesn't exist
                mkdir -p "$target_dir"

                # Backup existing file
                if [ -f "$target_file" ]; then
                    cp -a "$target_file" "$target_file.bak" 2>/dev/null
                fi

                # Copy file with preserved attributes
                if ! cp -a --preserve=all "$file" "$target_file" 2>/dev/null; then
                    print_warning "Failed to restore setting: $target_file"
                fi
            done < "$temp_dir/settings_to_restore.txt"

            print_info "User settings restored successfully"
        fi
    }
    restore_user_settings() {
        local temp_dir="$1"
        local settings_dir="$temp_dir/user_settings"

        if [ -d "$settings_dir" ]; then
            print_info "Restoring user settings..."

            # Create a list of files to restore
            find "$settings_dir" -type f > "$temp_dir/settings_to_restore.txt"

            # Restore user settings files
            while IFS= read -r file; do
                local target_file="$HOME/${file#$settings_dir/}"
                local target_dir=$(dirname "$target_file")

                # Create directory if it doesn't exist
                mkdir -p "$target_dir"

                # Backup existing file
                if [ -f "$target_file" ]; then
                    cp -a "$target_file" "$target_file.bak" 2>/dev/null
                fi

                # Copy file with preserved attributes
                if ! cp -a --preserve=all "$file" "$target_file" 2>/dev/null; then
                    print_warning "Failed to restore setting: $target_file"
                fi
            done < "$temp_dir/settings_to_restore.txt"

            print_info "User settings restored successfully"
        fi
    }

    # Register the package
    register_package "$temp_dir" "$package_name"

    # Run post-install scripts if they exist
    if [ -f "$temp_dir/package_info/post_install.sh" ]; then
        print_info "Running post-installation script..."
        sudo bash "$temp_dir/package_info/post_install.sh"
    fi

    # Clean up
    rm -rf "$temp_dir"
    print_info "Restore completed. Manifest saved to: $manifest_file"
    print_info "Backup files are preserved with .bak extension"

    # Verify installation
    if command -v "$package_name" >/dev/null 2>&1; then
        print_info "Package '$package_name' successfully installed and available in PATH"
    else
        print_warning "Package '$package_name' restored but may require additional setup"
    fi

    return 0
}
