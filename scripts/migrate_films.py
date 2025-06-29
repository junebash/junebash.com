#!/usr/bin/env python3

import os
import yaml
import toml
from pathlib import Path

def convert_yaml_to_toml(yaml_content):
    """Convert YAML frontmatter to TOML frontmatter"""
    # Load YAML data
    data = yaml.safe_load(yaml_content)
    
    # Convert to TOML-compatible structure
    toml_data = {
        'title': data.get('title', ''),
        'date': '2010-01-01',  # Default date, will update based on released field
        'weight': 2010,  # Default weight
        'template': 'film_project.html'
    }
    
    # Handle release date
    if 'released' in data:
        released = str(data['released'])
        # Extract year from various date formats
        if '-' in released:
            year = released.split('-')[0]
        else:
            year = released
        
        try:
            year_int = int(year)
            toml_data['date'] = f"{year}-01-01"
            toml_data['weight'] = year_int
        except ValueError:
            # Fallback if year parsing fails
            toml_data['date'] = "2010-01-01"
            toml_data['weight'] = 2010
    
    # Extra section for film-specific data
    extra = {}
    
    if 'company' in data:
        extra['company'] = data['company']
    
    if 'video' in data:
        # Handle embedded video iframe
        extra['video_embed'] = data['video']
    
    # Handle various film metadata
    if 'feature' in data:
        extra['feature'] = data['feature']
    
    if 'promo' in data:
        extra['promo'] = data['promo']
    
    # Handle links
    links = {}
    link_fields = ['imdb', 'amazon', 'itunes', 'play', 'film-site', 'co-site']
    for field in link_fields:
        if field in data:
            # Convert film-site and co-site to valid field names
            if field == 'film-site':
                links['film_site'] = data[field]
            elif field == 'co-site':
                links['co_site'] = data[field]
            else:
                links[field] = data[field]
    
    if links:
        extra['links'] = links
    
    if extra:
        toml_data['extra'] = extra
    
    return toml_data

def migrate_film(input_file, output_dir):
    """Migrate a single film file from Jekyll to Zola format"""
    with open(input_file, 'r') as f:
        content = f.read()
    
    # Split frontmatter and content
    if content.startswith('---\n'):
        parts = content.split('---\n', 2)
        if len(parts) >= 3:
            yaml_frontmatter = parts[1]
            body_content = parts[2].strip()
        else:
            yaml_frontmatter = parts[1] if len(parts) > 1 else ""
            body_content = ""
    else:
        yaml_frontmatter = ""
        body_content = content
    
    # Convert frontmatter
    toml_data = convert_yaml_to_toml(yaml_frontmatter)
    
    # Generate TOML frontmatter
    toml_frontmatter = toml.dumps(toml_data)
    
    # Create output file
    input_filename = Path(input_file).stem
    output_file = output_dir / f"{input_filename}.md"
    
    with open(output_file, 'w') as f:
        f.write("+++\n")
        f.write(toml_frontmatter)
        f.write("+++\n")
        if body_content:
            f.write("\n")
            f.write(body_content)
        f.write("\n")
    
    print(f"Migrated {input_filename} -> {output_file}")

def main():
    # Paths
    jekyll_films_dir = Path("/Users/junebash/repos/junebash.com/_films")
    zola_films_dir = Path("/Users/junebash/repos/junebash_com_zola/content/films")
    
    # Create output directory
    zola_films_dir.mkdir(parents=True, exist_ok=True)
    
    # Create section index
    index_content = """+++
title = "Films"
sort_by = "weight"
template = "section.html"
+++
"""
    
    with open(zola_films_dir / "_index.md", 'w') as f:
        f.write(index_content)
    
    print(f"Created section index: {zola_films_dir}/_index.md")
    
    # Migrate all film files
    if jekyll_films_dir.exists():
        for md_file in jekyll_films_dir.glob("*.md"):
            migrate_film(md_file, zola_films_dir)
    else:
        print(f"Jekyll films directory not found: {jekyll_films_dir}")

if __name__ == "__main__":
    main()