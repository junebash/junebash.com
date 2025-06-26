#!/usr/bin/env python3
"""
Migrate Jekyll now updates to Zola format
Simple conversion for status update posts
"""

import os
import yaml
import toml
from pathlib import Path
from datetime import datetime

def convert_now_update(input_file, output_dir):
    """Convert a Jekyll now update to Zola format"""
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract YAML frontmatter
    if content.startswith('---\n'):
        parts = content.split('---\n', 2)
        if len(parts) >= 3:
            yaml_frontmatter = parts[1]
            post_content = parts[2].strip()
        else:
            print(f"Invalid frontmatter in {input_file}")
            return False
    else:
        print(f"No frontmatter found in {input_file}")
        return False
    
    try:
        yaml_data = yaml.safe_load(yaml_frontmatter)
    except yaml.YAMLError as e:
        print(f"YAML parsing error in {input_file}: {e}")
        return False
    
    # Convert to Zola TOML format
    toml_data = {}
    
    # Date is the primary identifier for now updates
    if 'date' in yaml_data:
        date_str = str(yaml_data['date'])
        # Convert to ISO format
        if 'T' not in date_str:
            toml_data['date'] = f"{date_str}T00:00:00Z"
        else:
            toml_data['date'] = date_str
        
        # Generate title from date
        try:
            date_obj = datetime.fromisoformat(date_str.replace('Z', ''))
            toml_data['title'] = f"Now Update - {date_obj.strftime('%B %d, %Y')}"
        except:
            toml_data['title'] = f"Now Update - {date_str}"
    else:
        print(f"No date found in {input_file}")
        return False
    
    # Add tags for now updates
    toml_data['taxonomies'] = {'tags': ['now', 'personal', 'updates']}
    
    # Extra section
    toml_data['extra'] = {
        'comment': False  # Now updates typically don't need comments
    }
    
    # Generate TOML frontmatter
    toml_frontmatter = toml.dumps(toml_data)
    
    # Create new content
    new_content = f"+++\n{toml_frontmatter}+++\n{post_content}"
    
    # Generate output filename from date
    date_str = toml_data['date'][:10]  # YYYY-MM-DD
    output_file = os.path.join(output_dir, f"{date_str}.md")
    
    # Write converted file
    os.makedirs(output_dir, exist_ok=True)
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"Converted: {os.path.basename(input_file)} → {os.path.basename(output_file)}")
    return True

def migrate_now_updates(jekyll_dir, zola_dir):
    """Migrate all Jekyll now updates to Zola format"""
    now_updates = sorted(Path(jekyll_dir).glob('*.md'))
    
    success_count = 0
    for update_file in now_updates:
        if convert_now_update(update_file, zola_dir):
            success_count += 1
    
    print(f"\nNow updates migration complete: {success_count}/{len(now_updates)} updates converted")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 3:
        print("Usage: python migrate_now_updates.py <jekyll_now_dir> <zola_now_dir>")
        print("Example: python migrate_now_updates.py ../junebash.com/_now-updates ./content/now")
        sys.exit(1)
    
    jekyll_dir = sys.argv[1]
    zola_dir = sys.argv[2]
    
    migrate_now_updates(jekyll_dir, zola_dir)