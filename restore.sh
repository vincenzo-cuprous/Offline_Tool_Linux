#!/bin/bash

# Import modules
source modules/utils.sh
source modules/restore_operations.sh

# Main function
main() {
    check_root

    while true; do
        clear
        print_info "Package Restore Manager"
        echo "1. List available backups"
        echo "2. Restore a backup"
        echo "3. Verify backup integrity"
        echo "4. Exit"
        echo -n "Select option (1-4): "
        read choice

        case $choice in
            1)
                list_available_backups
                echo -e "\nPress Enter to continue..."
                read
                ;;
            2)
                if list_available_backups; then
                    echo -e "\nEnter backup number to restore (or 'q' to return to menu): "
                    read selection

                    [ "$selection" = "q" ] && continue

                    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
                        print_error "Invalid selection"
                        sleep 2
                        continue
                    fi

                    backup_file=$(ls -1 "$HOME/package_backups"/*.tar.gz 2>/dev/null | sed -n "${selection}p")

                    if [ -z "$backup_file" ]; then
                        print_error "Invalid backup number"
                        sleep 2
                        continue
                    fi

                    echo -e "\nWarning: This will overwrite existing files. Continue? (y/N): "
                    read confirm
                    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                        perform_restore "$backup_file"
                    else
                        print_info "Restore cancelled"
                    fi
                    echo -e "\nPress Enter to continue..."
                    read
                fi
                ;;
            3)
                if list_available_backups; then
                    echo -e "\nEnter backup number to verify (or 'q' to return to menu): "
                    read selection

                    [ "$selection" = "q" ] && continue

                    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
                        print_error "Invalid selection"
                        sleep 2
                        continue
                    fi

                    backup_file=$(ls -1 "$HOME/package_backups"/*.tar.gz 2>/dev/null | sed -n "${selection}p")

                    if [ -z "$backup_file" ]; then
                        print_error "Invalid backup number"
                        sleep 2
                        continue
                    fi

                    if verify_backup "$backup_file" "/tmp"; then
                        print_info "Backup verification successful"
                    else
                        print_error "Backup verification failed"
                    fi
                    echo -e "\nPress Enter to continue..."
                    read
                fi
                ;;
            4)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                continue
                ;;
        esac
    done
}

# Run main function
main
