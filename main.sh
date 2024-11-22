#!/bin/bash

# Import modules
source modules/utils.sh
source modules/package_operations.sh
source modules/backup_operations.sh

# Main function
main() {
    check_root

    # Check if expac is installed
    if ! command -v expac >/dev/null 2>&1; then
        print_warning "Installing expac for faster package listing..."
        pacman -S --noconfirm expac
    fi

    while true; do
        clear
        print_info "Package Backup Manager"
        echo "1. List all packages"
        echo "2. Search package"
        echo "3. List existing backups"
        echo "4. Clean old backups"
        echo "5. Quit"
        echo -n "Select option (1-5): "
        read choice

        case $choice in
            1)
                # Get and display all packages
                display_packages
                ;;
            2)
                # Search for specific package
                echo -n "Enter search term: "
                read search_term
                if [ -z "$search_term" ]; then
                    print_error "Search term cannot be empty"
                    sleep 1
                    continue
                fi

                # Create temporary file for search results
                search_results="/tmp/package_search_results"
                print_info "Searching for packages matching: $search_term"

                get_installed_packages | grep -i "$search_term" | \
                awk 'BEGIN {count=1} {printf "%-4d %-30s %-20s\n", count++, $1, $2}' > "$search_results"

                if [ ! -s "$search_results" ]; then
                    print_error "No packages found matching: $search_term"
                    sleep 1
                    continue
                fi

                echo "Search results:"
                cat "$search_results"
                rm "$search_results"
                ;;
            3)
                # List existing backups
                list_backups
                echo "Press Enter to continue..."
                read
                ;;
            4)
                # Clean old backups
                echo -n "Enter number of days (backups older than this will be removed): "
                read days
                if [[ "$days" =~ ^[0-9]+$ ]]; then
                    cleanup_old_backups "$days"
                else
                    print_error "Invalid number of days"
                fi
                echo "Press Enter to continue..."
                read
                ;;
            5)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                continue
                ;;
        esac

        # Only show package selection for options 1 and 2
        if [[ "$choice" =~ ^[12]$ ]]; then
            # Get package selection
            echo -e "\nEnter the package number to backup (or 'q' to return to menu): "
            read selection

            [ "$selection" = "q" ] && continue

            # Validate selection
            if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
                print_error "Invalid selection"
                sleep 1
                continue
            fi

            # Get selected package
            selected_package=$(get_installed_packages | sed -n "${selection}p" | awk '{print $1}')

            if [ -z "$selected_package" ]; then
                print_error "Invalid package number"
                sleep 1
                continue
            fi

            # Create temporary backup directory
            backup_dir="/tmp/${selected_package}_backup"
            create_directories "$backup_dir"

            print_info "Starting backup of $selected_package..."

            # Perform backup operations
            backup_binaries "$selected_package" "$backup_dir"
            backup_configs "$selected_package" "$backup_dir"
            backup_user_settings "$selected_package" "$backup_dir"

            # Create final archive
            create_backup_archive "$selected_package" "$backup_dir"

            echo "Press Enter to continue..."
            read
        fi
    done
}

# Run main function
main
