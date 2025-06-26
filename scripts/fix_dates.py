#!/usr/bin/env python3
"""
Fix date format issues in converted posts
Ensure all dates have proper timezone information for Zola TOML parsing
"""

import os
import re
from pathlib import Path

def fix_date_format(content):
    """Fix date formats to be Zola TOML compatible"""
    # Pattern: date = "YYYY-MM-DD HH:MM" (missing timezone)
    pattern = r'date = "(\d{4}-\d{2}-\d{2} \d{2}:\d{2})"'
    replacement = r'date = "\1:00+00:00"'
    content = re.sub(pattern, replacement, content)
    
    # Pattern: date = "YYYY-MM-DD HH:MM:SS" (missing timezone)
    pattern2 = r'date = "(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"'
    replacement2 = r'date = "\1+00:00"'
    content = re.sub(pattern2, replacement2, content)
    
    # Pattern: date = "YYYY-MM-DD HH:MM:SS -HHMM" (old timezone format)
    pattern3 = r'date = "(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) ([-+])(\d{2})(\d{2})"'
    replacement3 = r'date = "\1\2\3:\4"'
    content = re.sub(pattern3, replacement3, content)
    
    # Pattern: date = "YYYY-MM-DDTHH:MM:SS -HHMM" (T separator with old timezone)
    pattern4 = r'date = "(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}) ([-+])(\d{2})(\d{2})"'
    replacement4 = r'date = "\1\2\3:\4"'
    content = re.sub(pattern4, replacement4, content)
    
    return content

def fix_dates_in_file(file_path):
    """Fix date formats in a single file"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    fixed_content = fix_date_format(content)
    
    if fixed_content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        print(f"Fixed date format in: {os.path.basename(file_path)}")
        return True
    
    return False

def fix_all_dates(content_dir):
    """Fix date formats in all markdown files"""
    content_path = Path(content_dir)
    updated_count = 0
    
    # Find all markdown files
    for md_file in content_path.rglob('*.md'):
        if fix_dates_in_file(md_file):
            updated_count += 1
    
    print(f"\nDate format fix complete: {updated_count} files updated")

if __name__ == "__main__":
    import sys
    
    content_dir = sys.argv[1] if len(sys.argv) > 1 else "./content"
    fix_all_dates(content_dir)