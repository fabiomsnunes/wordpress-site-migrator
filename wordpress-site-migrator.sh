#!/usr/bin/env bash

set -euo pipefail

# Constants
SCRIPT_NAME=$(basename "$0")
REQUIRED_COMMANDS=("wp" "unzip" "tar" "zip")
SUPPORTED_EXTENSIONS=(".zip" ".tar" ".tar.gz" ".tgz")

# Function to display usage information
usage() {
    echo "Usage: $SCRIPT_NAME"
    echo "This script will:"
    echo "1. List available project archives"
    echo "2. Create a complete backup of the current site"
    echo "3. Extract and install the selected project"
    echo "4. Update the domain based on current WordPress configuration"
    echo
    echo "Supported archive formats: ${SUPPORTED_EXTENSIONS[*]}"
}

# Function to check if required commands are available
check_requirements() {
    # Check if required commands are available
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: Required command '$cmd' not found. Please install it and try again."
            exit 1
        fi
    done

    # Check if we're in a WordPress directory
    if [[ ! -f "wp-config.php" ]]; then
        echo "Error: wp-config.php not found. Please run this script from a WordPress directory."
        exit 1
    fi
}

# Function to list and select archive files
select_archive_file() {
    local archives=()
    local counter=1
    
    echo "Available project archives:"
    echo
    
    # Find all supported archive files
    for ext in "${SUPPORTED_EXTENSIONS[@]}"; do
        for file in *"$ext"; do
            if [[ -f "$file" ]]; then
                archives+=("$file")
                echo "$counter) $file"
                ((counter++))
            fi
        done
    done
    
    if [[ ${#archives[@]} -eq 0 ]]; then
        echo "Error: No supported archive files found in current directory."
        echo "Supported formats: ${SUPPORTED_EXTENSIONS[*]}"
        exit 1
    fi
    
    echo
    while true; do
        read -p "Select the number of the archive to install (1-${#archives[@]}): " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#archives[@]} ]]; then
            selected_archive="${archives[$((selection-1))]}"
            echo "Selected: $selected_archive"
            break
        else
            echo "Invalid selection. Please enter a number between 1 and ${#archives[@]}."
        fi
    done
    
    echo "$selected_archive"
}

# Function to get current domain
get_current_domain() {
    echo "Getting current site domain..."
    local current_domain=$(wp option get siteurl 2>/dev/null || wp option get home 2>/dev/null || echo "")
    
    if [[ -z "$current_domain" ]]; then
        echo "Warning: Could not retrieve current domain from WordPress. Please verify manually later."
        echo ""
    else
        echo "Current domain: $current_domain"
        echo "$current_domain"
    fi
}

# Function to create complete backup
create_backup() {
    echo "Creating complete backup of current site..."
    
    # Export database (wp-cli automatically adds timestamp)
    echo "Exporting database..."
    wp db export || { echo "Error: Failed to export database"; exit 1; }
    
    # Create zip backup excluding script, archives, and existing backups
    echo "Creating file backup..."
    local archive_file="$1"
    zip -r ".backup-pre-live-$(date +%Y%m%d-%H%M%S).zip" . -x "$SCRIPT_NAME" "$archive_file" "*.zip" "*.tar" "*.tar.gz" "*.tgz" "*.backup-pre-live*.zip" || { echo "Error: Failed to create backup"; exit 1; }
    
    # Remove all SQL files after backup (they're now safely stored in the backup)
    echo "Cleaning up SQL files (now safely backed up)..."
    rm -f *.sql
    
    echo "Backup completed successfully!"
}

# Function to extract project files
extract_files() {
    local archive_file="$1"

    echo "Creating backup of wp-config.php..."
    cp wp-config.php wp-config-local.php || { echo "Error: Failed to backup wp-config.php"; exit 1; }

    echo "Removing old files (keeping backups, configs, scripts, and archives)..."
    find . -maxdepth 1 ! -name '.' ! -name '..' ! -name 'wp-config-local.php' ! -name "$SCRIPT_NAME" ! -name "*.zip" ! -name "*.tar" ! -name "*.tar.gz" ! -name "*.tgz" ! -name "*.sql" -exec rm -rf {} +

    echo "Extracting $archive_file..."
    case "$archive_file" in
        *.zip)
            unzip -q "$archive_file" || { echo "Error: Failed to unzip $archive_file"; exit 1; }
            ;;
        *.tar)
            tar -xf "$archive_file" || { echo "Error: Failed to extract $archive_file"; exit 1; }
            ;;
        *.tar.gz|*.tgz)
            tar -xzf "$archive_file" || { echo "Error: Failed to extract $archive_file"; exit 1; }
            ;;
        *)
            echo "Error: Unsupported archive format for $archive_file"
            exit 1
            ;;
    esac

    # Check if extracted content is inside a single directory
    local extracted_dirs=()
    for dir in */; do
        if [[ -d "$dir" && "$dir" != "__MACOSX/" ]]; then
            extracted_dirs+=("$dir")
        fi
    done
    
    if [ ${#extracted_dirs[@]} -eq 1 ]; then
        local main_dir="${extracted_dirs[0]}"
        echo "Extracted content is inside '$main_dir'. Moving files to current directory..."
        mv "$main_dir"* "$main_dir".[!.]* . 2>/dev/null || true
        rmdir "$main_dir"
    fi

    # Remove __MACOSX if it exists
    if [ -d "__MACOSX" ]; then
        echo "Removing __MACOSX directory..."
        rm -rf __MACOSX
    fi
}

# Function to update WordPress configuration
update_wp_config() {
    local config_file="wp-config-local.php"

    echo "Updating WordPress configuration..."
    local db_params=("DB_NAME" "DB_USER" "DB_PASSWORD")
    for param in "${db_params[@]}"; do
        local value=$(grep "$param" "$config_file" | cut -d \' -f 4)
        wp config set "$param" "$value" || { echo "Error: Failed to set $param"; exit 1; }
    done
}

# Function to import database
import_database() {
    echo "Resetting database..."
    wp db reset --yes || { echo "Error: Failed to reset database"; exit 1; }

    echo "Importing database..."
    local database_file=$(ls *.sql 2>/dev/null | grep -v "backup-" | sort -V | tail -n1)
    if [[ -z "$database_file" ]]; then
        echo "Error: No SQL file found for import."
        exit 1
    fi
    wp db import "$database_file" --allow-root || { echo "Error: Failed to import database"; exit 1; }
}

# Function to change domain
change_domain() {
    local current_domain="$1"
    
    if [[ -z "$current_domain" ]]; then
        echo "Current domain not available. Skipping domain change."
        return
    fi

    echo "Updating domain configuration..."
    local new_site_url=$(wp option get siteurl 2>/dev/null || echo "")
    
    if [[ -n "$new_site_url" && "$new_site_url" != "$current_domain" ]]; then
        echo "Replacing '$new_site_url' with '$current_domain'"
        wp search-replace "$new_site_url" "$current_domain" --all-tables --report-changed-only || { echo "Error: Failed to change domain"; exit 1; }
    else
        echo "Domain already matches or could not determine new site URL."
    fi
    
    wp cache flush || { echo "Error: Failed to flush cache"; exit 1; }
}

# Function to create migrated.html (optional)
create_migrated_file() {
    read -p "Do you want to create a migrated.html file? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "<h1>Migrated!</h1>" > migrated.html
        echo "Created migrated.html file."
    else
        echo "Skipped creating migrated.html file."
    fi
}

# Function to clean up temporary files
clean_up() {
    echo "Cleaning up temporary files..."
    local archive_file="$1"

    # Remove temporary files but keep wp-config-local.php as backup
    local files_to_remove=("*.sql" "table.prefix" "migrate_into_rc.sh")
    for file in "${files_to_remove[@]}"; do
        if [[ "$file" == "*.sql" ]]; then
            rm -f *.sql
            echo "Removed temporary SQL files"
        else
            rm -f "$file"
        fi
    done

    # Ask about removing the archive file
    read -p "Do you want to remove the archive file ($archive_file)? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$archive_file"
        echo "Archive file removed."
    else
        echo "Archive file kept."
    fi
    
    echo "Note: wp-config-local.php has been kept as a backup of your original configuration."
}

# Main function
main() {
    echo "WordPress Site Migration Tool"
    echo "============================="
    echo

    check_requirements
    
    # Get current domain before making any changes
    local current_domain=$(get_current_domain)
    echo
    
    # Select archive file
    local archive_file=$(select_archive_file)
    echo
    
    # Create backup before proceeding
    create_backup "$archive_file"
    echo
    
    # Confirm before proceeding
    read -p "Ready to proceed with migration? This will replace the current site. (y/Y to continue) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Migration cancelled."
        exit 0
    fi
    
    extract_files "$archive_file"
    update_wp_config
    import_database
    change_domain "$current_domain"
    create_migrated_file

    echo
    echo "***************************************"
    echo "*******   Migration completed   *******"
    echo "***************************************"
    echo

    # Ask if files should be cleaned
    read -p "Do you want to clean up temporary files? (y/Y to proceed) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        clean_up "$archive_file"
    else
        echo "Cleanup skipped."
    fi
    
    echo
    echo "Migration completed successfully!"
    echo "Your original wp-config.php has been preserved as wp-config-local.php"
    echo "Site backups are available as .backup-pre-live-*.zip and database export files"
}

# Check if help is requested
if [[ $# -gt 0 && ("$1" == "-h" || "$1" == "--help") ]]; then
    usage
    exit 0
fi

# Run the main function
main "$@"