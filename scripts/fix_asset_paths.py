#!/usr/bin/env python3
"""
Fix asset path references in migrated content
Convert Jekyll /assets/images/ paths to Zola /images/ paths
"""

import os
import re
from pathlib import Path

def fix_asset_paths_in_file(file_path):
    """Fix asset paths in a single file"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Fix image paths in frontmatter (TOML extra.image)
    content = re.sub(
        r'image = "/assets/images/([^"]+)"',
        r'image = "/images/\1"',
        content
    )
    
    # Fix image paths in markdown content
    content = re.sub(
        r'/assets/images/',
        '/images/',
        content
    )
    
    # Fix any remaining absolute asset references
    content = re.sub(
        r'https?://[^/]+/assets/images/',
        '/images/',
        content
    )
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated asset paths in: {os.path.basename(file_path)}")
        return True
    
    return False

def fix_all_asset_paths(content_dir):
    """Fix asset paths in all markdown files"""
    content_path = Path(content_dir)
    updated_count = 0
    
    # Find all markdown files
    for md_file in content_path.rglob('*.md'):
        if fix_asset_paths_in_file(md_file):
            updated_count += 1
    
    print(f"\nAsset path update complete: {updated_count} files updated")

if __name__ == "__main__":
    import sys
    
    content_dir = sys.argv[1] if len(sys.argv) > 1 else "./content"
    fix_all_asset_paths(content_dir)