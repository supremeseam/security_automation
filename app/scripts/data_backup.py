#!/usr/bin/env python3
"""
Data Backup Script
Backs up files from source to destination with optional compression
"""

import argparse
import os
import shutil
import zipfile
from pathlib import Path
from datetime import datetime

def backup_with_compression(source, destination):
    """Create a compressed backup"""
    source_path = Path(source)
    dest_path = Path(destination)

    if not source_path.exists():
        print(f"Error: Source path '{source}' does not exist")
        return False

    # Create destination directory if it doesn't exist
    dest_path.mkdir(parents=True, exist_ok=True)

    # Create backup filename with timestamp
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    source_name = source_path.name if source_path.name else 'backup'
    zip_filename = f"{source_name}_backup_{timestamp}.zip"
    zip_path = dest_path / zip_filename

    print(f"Creating compressed backup: {zip_filename}")
    print(f"Source: {source}")
    print(f"Destination: {zip_path}\n")

    file_count = 0
    total_size = 0

    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        if source_path.is_file():
            zipf.write(source_path, source_path.name)
            file_count = 1
            total_size = source_path.stat().st_size
            print(f"Added: {source_path.name}")
        else:
            for item in source_path.rglob('*'):
                if item.is_file():
                    arc_name = item.relative_to(source_path.parent)
                    zipf.write(item, arc_name)
                    file_count += 1
                    total_size += item.stat().st_size
                    print(f"Added: {arc_name}")

    zip_size = zip_path.stat().st_size
    compression_ratio = (1 - zip_size / total_size) * 100 if total_size > 0 else 0

    print(f"\n✓ Backup completed successfully!")
    print(f"Files backed up: {file_count}")
    print(f"Original size: {total_size / (1024*1024):.2f} MB")
    print(f"Compressed size: {zip_size / (1024*1024):.2f} MB")
    print(f"Compression ratio: {compression_ratio:.1f}%")
    print(f"Backup saved to: {zip_path}")

    return True

def backup_without_compression(source, destination):
    """Create a regular backup without compression"""
    source_path = Path(source)
    dest_path = Path(destination)

    if not source_path.exists():
        print(f"Error: Source path '{source}' does not exist")
        return False

    # Create backup folder with timestamp
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    source_name = source_path.name if source_path.name else 'backup'
    backup_folder = dest_path / f"{source_name}_backup_{timestamp}"

    print(f"Creating uncompressed backup: {backup_folder.name}")
    print(f"Source: {source}")
    print(f"Destination: {backup_folder}\n")

    file_count = 0
    total_size = 0

    if source_path.is_file():
        backup_folder.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_path, backup_folder / source_path.name)
        file_count = 1
        total_size = source_path.stat().st_size
        print(f"Copied: {source_path.name}")
    else:
        shutil.copytree(source_path, backup_folder)
        for item in backup_folder.rglob('*'):
            if item.is_file():
                file_count += 1
                total_size += item.stat().st_size
                rel_path = item.relative_to(backup_folder)
                print(f"Copied: {rel_path}")

    print(f"\n✓ Backup completed successfully!")
    print(f"Files backed up: {file_count}")
    print(f"Total size: {total_size / (1024*1024):.2f} MB")
    print(f"Backup saved to: {backup_folder}")

    return True

def main():
    parser = argparse.ArgumentParser(description='Backup files to a destination')
    parser.add_argument('--source', required=True, help='Source path to backup')
    parser.add_argument('--destination', required=True, help='Destination path for backup')
    parser.add_argument('--compress', action='store_true', help='Compress the backup')

    args = parser.parse_args()

    print("Starting backup process...\n")

    if args.compress:
        success = backup_with_compression(args.source, args.destination)
    else:
        success = backup_without_compression(args.source, args.destination)

    return 0 if success else 1

if __name__ == '__main__':
    exit(main())
