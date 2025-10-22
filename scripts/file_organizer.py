import argparse
import os
import shutil
from pathlib import Path
from datetime import datetime

def organize_by_extension(source_folder):
    """Organize files by their extension"""
    source = Path(source_folder)

    if not source.exists():
        print(f"Error: Source folder '{source_folder}' does not exist")
        return False

    files_moved = 0

    for item in source.iterdir():
        if item.is_file():
            # Get file extension (without the dot)
            ext = item.suffix[1:] if item.suffix else 'no_extension'

            # Create folder for this extension
            dest_folder = source / ext
            dest_folder.mkdir(exist_ok=True)

            # Move file
            dest_path = dest_folder / item.name

            # Handle duplicates
            counter = 1
            while dest_path.exists():
                name_without_ext = item.stem
                dest_path = dest_folder / f"{name_without_ext}_{counter}{item.suffix}"
                counter += 1

            shutil.move(str(item), str(dest_path))
            files_moved += 1
            print(f"Moved: {item.name} -> {ext}/")

    print(f"\n✓ Successfully organized {files_moved} files by extension")
    return True

def organize_by_date(source_folder):
    """Organize files by modification date"""
    source = Path(source_folder)

    if not source.exists():
        print(f"Error: Source folder '{source_folder}' does not exist")
        return False

    files_moved = 0

    for item in source.iterdir():
        if item.is_file():
            # Get modification date
            mod_time = datetime.fromtimestamp(item.stat().st_mtime)
            year_month = mod_time.strftime('%Y-%m')

            # Create folder for this date
            dest_folder = source / year_month
            dest_folder.mkdir(exist_ok=True)

            # Move file
            dest_path = dest_folder / item.name

            # Handle duplicates
            counter = 1
            while dest_path.exists():
                name_without_ext = item.stem
                dest_path = dest_folder / f"{name_without_ext}_{counter}{item.suffix}"
                counter += 1

            shutil.move(str(item), str(dest_path))
            files_moved += 1
            print(f"Moved: {item.name} -> {year_month}/")

    print(f"\n✓ Successfully organized {files_moved} files by date")
    return True

def organize_by_size(source_folder):
    """Organize files by size categories"""
    source = Path(source_folder)

    if not source.exists():
        print(f"Error: Source folder '{source_folder}' does not exist")
        return False

    files_moved = 0

    # Size categories in bytes
    size_categories = [
        (1024 * 1024, 'small'),           # < 1MB
        (10 * 1024 * 1024, 'medium'),     # < 10MB
        (100 * 1024 * 1024, 'large'),     # < 100MB
        (float('inf'), 'very_large')       # >= 100MB
    ]

    for item in source.iterdir():
        if item.is_file():
            file_size = item.stat().st_size

            # Determine size category
            category = 'very_large'
            for size_limit, cat_name in size_categories:
                if file_size < size_limit:
                    category = cat_name
                    break

            # Create folder for this category
            dest_folder = source / category
            dest_folder.mkdir(exist_ok=True)

            # Move file
            dest_path = dest_folder / item.name

            # Handle duplicates
            counter = 1
            while dest_path.exists():
                name_without_ext = item.stem
                dest_path = dest_folder / f"{name_without_ext}_{counter}{item.suffix}"
                counter += 1

            shutil.move(str(item), str(dest_path))
            files_moved += 1
            print(f"Moved: {item.name} -> {category}/")

    print(f"\n✓ Successfully organized {files_moved} files by size")
    return True

def main():
    parser = argparse.ArgumentParser(description='Organize files in a directory')
    parser.add_argument('--source_folder', required=True, help='Source folder to organize')
    parser.add_argument('--organize_by', required=True, choices=['extension', 'date', 'size'],
                       help='Organization method')

    args = parser.parse_args()

    print(f"Starting file organization...")
    print(f"Source: {args.source_folder}")
    print(f"Method: {args.organize_by}\n")

    if args.organize_by == 'extension':
        success = organize_by_extension(args.source_folder)
    elif args.organize_by == 'date':
        success = organize_by_date(args.source_folder)
    else:
        success = organize_by_size(args.source_folder)

    if success:
        print("\n✓ File organization completed successfully!")
        return 0
    else:
        print("\n✗ File organization failed!")
        return 1

if __name__ == '__main__':
    exit(main())
