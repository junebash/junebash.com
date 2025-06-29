#!/usr/bin/env python3
"""
Migration script to convert Jekyll concert music collection to Zola format.
Converts 10 concert music pieces with proper TOML frontmatter and metadata.
"""

import os
import yaml
import toml
from pathlib import Path

def convert_instrumentation(instrumentation_list):
    """Convert Jekyll instrumentation list to formatted string."""
    if not instrumentation_list:
        return ""
    
    # Filter out separator dashes and format as bulleted list
    instruments = [inst for inst in instrumentation_list if inst != "-"]
    if len(instruments) <= 3:
        return ", ".join(instruments)
    else:
        return "\n".join(f"• {inst}" for inst in instruments)

def migrate_concert_music_file(source_path, target_dir):
    """Migrate a single concert music file from Jekyll to Zola format."""
    
    with open(source_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Split frontmatter and content
    if content.startswith('---\n'):
        try:
            _, frontmatter_str, body = content.split('---\n', 2)
            frontmatter = yaml.safe_load(frontmatter_str)
        except ValueError:
            print(f"Warning: Could not parse frontmatter in {source_path}")
            return False
    else:
        print(f"Warning: No frontmatter found in {source_path}")
        return False
    
    # Extract filename for output
    filename = Path(source_path).stem
    
    # Build Zola TOML frontmatter
    zola_frontmatter = {
        'title': frontmatter.get('title', 'Untitled'),
        'date': f"{frontmatter.get('completed', 2015)}-01-01",  # Default to Jan 1 of completion year
        'template': 'concert_piece.html',
        'weight': frontmatter.get('completed', 2015),  # Use completion year for sorting
    }
    
    # Add extra metadata
    extra = {}
    if frontmatter.get('ensemble-type'):
        extra['ensemble_type'] = frontmatter['ensemble-type']
    if frontmatter.get('length'):
        extra['length'] = frontmatter['length']
    if frontmatter.get('completed'):
        extra['completed'] = frontmatter['completed']
    if frontmatter.get('premiered'):
        extra['premiered'] = frontmatter['premiered']
    if frontmatter.get('instrumentation'):
        extra['instrumentation'] = convert_instrumentation(frontmatter['instrumentation'])
    if frontmatter.get('bandcamp'):
        extra['bandcamp_embed'] = frontmatter['bandcamp']
    if frontmatter.get('youtube'):
        extra['youtube_embed'] = frontmatter['youtube']
    
    if extra:
        zola_frontmatter['extra'] = extra
    
    # Write the migrated file
    target_path = target_dir / f"{filename}.md"
    
    with open(target_path, 'w', encoding='utf-8') as f:
        f.write('+++\n')
        f.write(toml.dumps(zola_frontmatter))
        f.write('+++\n\n')
        f.write(body.strip() + '\n')
    
    print(f"✓ Migrated: {filename}.md")
    return True

def main():
    # Set up paths
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    source_dir = Path("/Users/junebash/repos/junebash.com/_concert-music")
    target_dir = project_root / "content" / "concert_music"
    
    # Create target directory
    target_dir.mkdir(exist_ok=True)
    
    # Create section index file
    index_content = """+++
title = "Concert Music"
sort_by = "weight"
template = "section.html"
page_template = "concert_piece.html"

[extra]
comment = false
+++

Concert music collection - classical and contemporary compositions for acoustic instruments and ensembles.
"""
    
    with open(target_dir / "_index.md", 'w', encoding='utf-8') as f:
        f.write(index_content)
    
    print(f"Created section index: {target_dir}/_index.md")
    
    # Check source directory
    if not source_dir.exists():
        print(f"Error: Source directory not found: {source_dir}")
        return False
    
    # Migrate all concert music files
    success_count = 0
    total_files = 0
    
    for file_path in source_dir.glob("*.md"):
        total_files += 1
        if migrate_concert_music_file(file_path, target_dir):
            success_count += 1
    
    print(f"\nMigration complete: {success_count}/{total_files} files migrated successfully")
    print(f"Concert music files created in: {target_dir}")
    
    return success_count == total_files

if __name__ == "__main__":
    main()