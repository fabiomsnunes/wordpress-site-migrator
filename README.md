# WordPress Site Migrator

A bash script for automated WordPress site migration with complete backup functionality. This tool simplifies the process of replacing a live WordPress site with a new one while preserving the original domain and creating comprehensive backups.

## Overview

This script was originally created for personal use to streamline WordPress site deployments, but it may be useful for others who need to frequently migrate or update WordPress sites. It provides an interactive installer-like experience for selecting and deploying WordPress site archives.

## Features

- **Interactive Archive Selection**: Lists all available site archives and lets you choose which one to deploy
- **Automatic Backup**: Creates complete backups of your current site before migration
- **Domain Preservation**: Automatically maintains your current domain configuration
- **Multiple Archive Formats**: Supports ZIP, TAR, TAR.GZ, and TGZ files
- **Safe File Handling**: Preserves important files during the migration process
- **Configuration Backup**: Keeps a copy of your original wp-config.php for safety

## Requirements

Before using this script, ensure you have the following installed and configured:

- **WP-CLI**: WordPress command-line interface
- **unzip**: For extracting ZIP archives
- **tar**: For extracting TAR archives
- **zip**: For creating backups
- **A working WordPress installation** with proper database access

## Installation

1. Download the script to your WordPress site directory:
```bash
wget https://raw.githubusercontent.com/fabiomsnunes/wordpress-site-migrator/main/wordpress-site-migrator.sh
chmod +x wordpress-site-migrator.sh
```

## Usage

1. **Prepare your site archive**: Place your WordPress site archive (ZIP, TAR, TAR.GZ, or TGZ) in your WordPress directory alongside the script.

2. **Run the script**: Execute the migration script from your WordPress site directory:
```bash
./wordpress-site-migrator.sh
```

3. **Follow the interactive prompts**:
   - The script will list all available archives
   - Select the number corresponding to your desired archive
   - Confirm the migration when prompted
   - Optionally create a migrated.html file
   - Choose whether to clean up temporary files

## What the Script Does

1. **Pre-Migration Checks**: Verifies all required tools are installed and you're in a WordPress directory
2. **Domain Detection**: Captures your current site's domain configuration
3. **Complete Backup**: 
   - Exports the current database
   - Creates a timestamped ZIP backup of all site files
   - Preserves the original wp-config.php
4. **Site Migration**:
   - Extracts the selected archive
   - Updates database configuration
   - Imports the new database
   - Adjusts domain settings to match your current setup
5. **Cleanup**: Optionally removes temporary files while preserving backups

## File Structure After Migration

After running the script, you'll have:
- Your new WordPress site files
- `wp-config-local.php` - Backup of your original configuration
- `.backup-pre-live-YYYYMMDD-HHMMSS.zip` - Complete site backup
- Database export file(s) from the backup process
- Optionally: `migrated.html` - Simple confirmation file

## Supported Archive Formats

- `.zip` - ZIP archives
- `.tar` - TAR archives  
- `.tar.gz` - Gzipped TAR archives
- `.tgz` - Gzipped TAR archives (alternative extension)

## Safety Features

- Creates complete backups before making any changes
- Preserves all existing ZIP/TAR files during extraction
- Keeps original wp-config.php as wp-config-local.php
- Protects the migration script from being deleted
- Maintains database exports for recovery purposes

## Troubleshooting

**"Required command not found" error:**
- Install the missing command using your system's package manager

**"wp-config.php not found" error:**
- Run the script from your WordPress root directory

**"No SQL file found for import" error:**
- Ensure your site archive contains a database export (.sql file)

**Database connection issues:**
- Verify your wp-config.php has correct database credentials
- Ensure your database server is running and accessible

## Important Notes

- **Always test on a staging environment first**
- This script will replace your current WordPress installation
- Backups are created but recovery is manual if needed
- The script assumes standard WordPress directory structure
- Database credentials are taken from your existing wp-config.php

## Contributing

This project was created for personal use, but contributions are welcome! Please feel free to:
- Report issues
- Suggest improvements
- Submit pull requests

## License

This project is open source and available under the [MIT License](LICENSE).

## Disclaimer

This script modifies and replaces WordPress installations. While it creates backups, always ensure you have additional backups before running any migration script. Use at your own risk and always test in a staging environment first.