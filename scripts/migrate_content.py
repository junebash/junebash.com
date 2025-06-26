#!/usr/bin/env python3
"""
Content migration script for Jekyll → Zola conversion
Handles YAML → TOML frontmatter conversion and category → tag mapping
"""

import os
import re
import yaml
import toml
from pathlib import Path
from datetime import datetime

# Category → Tag mapping based on analysis
CATEGORY_TAG_MAPPING = {
    'Code': ['programming'],
    'Music': ['music'],
    'Dharma': ['meditation', 'philosophy'],
    'Personal': ['personal'],
    'Games & Films': ['gamedev', 'film'],
    'Productivity': ['productivity'],
    'News': ['updates'],
    'Micro': ['microblog'],
    'Quotes': ['quotes']
}

# Additional specific tag mappings for Code posts
CODE_SPECIFIC_TAGS = {
    'swift': ['swift', 'ios'],
    'property wrapper': ['swift', 'ios'],
    'combine': ['swift', 'combine'],
    'swiftui': ['swift', 'swiftui'],
    'testing': ['programming', 'testing'],
    'architecture': ['programming', 'architecture']
}

def extract_frontmatter(content):
    """Extract YAML frontmatter from Jekyll post"""
    if content.startswith('---\n'):
        parts = content.split('---\n', 2)
        if len(parts) >= 3:
            return parts[1], parts[2]
    return None, content

def convert_categories_to_tags(categories, title, content):
    """Convert Jekyll categories to Zola tags with smart mapping"""
    if not categories:
        return []
    
    tags = set()
    
    # Map categories to base tags
    for category in categories:
        if category in CATEGORY_TAG_MAPPING:
            tags.update(CATEGORY_TAG_MAPPING[category])
        else:
            # Fallback: convert category to lowercase, replace spaces with hyphens
            tags.add(category.lower().replace(' ', '-').replace('&', 'and'))
    
    # Add specific tags based on content analysis
    title_lower = title.lower() if title else ''
    content_lower = content.lower()
    
    if 'Code' in categories:
        # Add Swift/iOS specific tags
        if any(keyword in title_lower or keyword in content_lower[:500] 
               for keyword in ['swift', 'ios', 'property wrapper', 'swiftui']):
            tags.update(['swift', 'ios'])
        
        if any(keyword in title_lower or keyword in content_lower[:500] 
               for keyword in ['combine', 'publisher', 'subscriber']):
            tags.add('combine')
            
        if any(keyword in title_lower or keyword in content_lower[:500] 
               for keyword in ['swiftui', 'view', 'modifier']):
            tags.add('swiftui')
            
        if any(keyword in title_lower or keyword in content_lower[:500] 
               for keyword in ['test', 'testing', 'unit test']):
            tags.add('testing')
    
    return sorted(list(tags))

def convert_frontmatter(yaml_frontmatter, title, content):
    """Convert YAML frontmatter to TOML format"""
    try:
        data = yaml.safe_load(yaml_frontmatter)
    except yaml.YAMLError as e:
        print(f"YAML parsing error: {e}")
        return None
    
    # Convert to Zola format
    toml_data = {}
    
    # Title
    if 'title' in data:
        toml_data['title'] = data['title']
    
    # Date - convert to ISO format if needed
    if 'date' in data:
        date_str = str(data['date'])
        # Handle various date formats
        if 'T' not in date_str and len(date_str.split()) == 1:
            # Date only, add default time
            toml_data['date'] = f"{date_str}T00:00:00Z"
        else:
            toml_data['date'] = date_str
    
    # Updated date if present
    if 'updated' in data:
        toml_data['updated'] = str(data['updated'])
    
    # Convert categories to tags
    categories = data.get('categories', [])
    tags = convert_categories_to_tags(categories, title, content)
    
    # Add taxonomies section
    if tags:
        toml_data['taxonomies'] = {'tags': tags}
    
    # Extra section for additional metadata
    extra = {}
    
    # Image
    if 'image' in data:
        extra['image'] = data['image']
    
    # Comments (default to true for blog posts)
    extra['comment'] = True
    
    if extra:
        toml_data['extra'] = extra
    
    return toml_data

def convert_post(input_file, output_dir):
    """Convert a single Jekyll post to Zola format"""
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    yaml_frontmatter, post_content = extract_frontmatter(content)
    
    if not yaml_frontmatter:
        print(f"No frontmatter found in {input_file}")
        return False
    
    # Get title for tag analysis
    try:
        yaml_data = yaml.safe_load(yaml_frontmatter)
        title = yaml_data.get('title', '')
    except:
        title = ''
    
    toml_data = convert_frontmatter(yaml_frontmatter, title, post_content)
    
    if not toml_data:
        print(f"Failed to convert frontmatter for {input_file}")
        return False
    
    # Generate TOML frontmatter
    toml_frontmatter = toml.dumps(toml_data)
    
    # Replace <!--more--> with proper Zola excerpt
    post_content = post_content.replace('<!--more-->', '<!-- more -->')
    
    # Create new content
    new_content = f"+++\n{toml_frontmatter}+++\n{post_content}"
    
    # Generate output filename
    filename = os.path.basename(input_file)
    output_file = os.path.join(output_dir, filename)
    
    # Write converted file
    os.makedirs(output_dir, exist_ok=True)
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"Converted: {filename}")
    return True

def migrate_posts(jekyll_posts_dir, zola_posts_dir, limit=None):
    """Migrate Jekyll posts to Zola format"""
    posts = sorted(Path(jekyll_posts_dir).glob('*.md'))
    
    if limit:
        posts = posts[:limit]
    
    success_count = 0
    for post_file in posts:
        if convert_post(post_file, zola_posts_dir):
            success_count += 1
    
    print(f"\nMigration complete: {success_count}/{len(posts)} posts converted successfully")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 3:
        print("Usage: python migrate_content.py <jekyll_posts_dir> <zola_posts_dir> [limit]")
        print("Example: python migrate_content.py ../junebash.com/_posts ./content/posts 10")
        sys.exit(1)
    
    jekyll_dir = sys.argv[1]
    zola_dir = sys.argv[2]
    limit = int(sys.argv[3]) if len(sys.argv) > 3 else None
    
    migrate_posts(jekyll_dir, zola_dir, limit)