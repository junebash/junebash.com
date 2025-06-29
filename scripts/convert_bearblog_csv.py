#!/usr/bin/env python3
"""
Convert BearBlog CSV export to Zola markdown posts.
"""

import csv
import re
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional


def parse_tags(tags_str: str) -> List[str]:
    """Parse tags from BearBlog format like '["Swift", "programming"]' to list."""
    if not tags_str or tags_str == "[]":
        return []
    
    # Remove brackets and split by comma
    tags_str = tags_str.strip("[]")
    if not tags_str:
        return []
    
    # Parse individual tags, handling quotes
    tags = []
    for tag in tags_str.split(","):
        tag = tag.strip().strip('"\'')
        if tag:
            tags.append(tag.lower())
    
    return tags


def classify_tags(title: str, content: str, existing_tags: List[str]) -> List[str]:
    """Classify content and add appropriate tags based on content analysis."""
    tags = existing_tags.copy()
    
    # Programming-related keywords
    programming_keywords = [
        "swift", "ios", "code", "programming", "task", "async", "await",
        "xcode", "swiftui", "combine", "framework", "api", "function",
        "class", "struct", "enum", "protocol", "property", "wrapper"
    ]
    
    # Personal/life keywords
    personal_keywords = [
        "life", "personal", "transition", "transgender", "gender", "identity",
        "meditation", "dharma", "spirituality", "philosophy"
    ]
    
    # AI/tech keywords
    ai_keywords = ["ai", "llm", "artificial intelligence", "claude", "gpt", "machine learning"]
    
    # Review/media keywords
    review_keywords = ["review", "season", "episode", "game", "movie", "film", "tv", "show"]
    
    # Convert to lowercase for checking
    title_lower = title.lower()
    content_lower = content.lower()
    combined_text = f"{title_lower} {content_lower}"
    
    # Add programming tag if Swift-related
    if any(keyword in combined_text for keyword in programming_keywords):
        if "programming" not in tags:
            tags.append("programming")
        if "swift" in combined_text and "swift" not in tags:
            tags.append("swift")
    
    # Add personal tag for personal content
    if any(keyword in combined_text for keyword in personal_keywords):
        if "personal" not in tags:
            tags.append("personal")
    
    # Add AI tag for AI-related content
    if any(keyword in combined_text for keyword in ai_keywords):
        if "ai" not in tags:
            tags.append("ai")
    
    # Add review tag for review content
    if any(keyword in combined_text for keyword in review_keywords):
        if "review" not in tags:
            tags.append("review")
    
    # Add meta tag for meta posts
    if "meta" in existing_tags or "hello" in title_lower or "writing" in title_lower:
        if "meta" not in tags:
            tags.append("meta")
    
    return tags


def convert_date(date_str: str) -> str:
    """Convert BearBlog date format to Zola format."""
    # Parse the ISO format date
    dt = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
    # Format for Zola with proper timezone format
    formatted = dt.strftime("%Y-%m-%d %H:%M:%S%z")
    # Insert colon in timezone (TOML requires +00:00 not +0000)
    if formatted.endswith('+0000') or formatted.endswith('-0000'):
        formatted = formatted[:-2] + ':' + formatted[-2:]
    return formatted


def sanitize_filename(title: str, date: str) -> str:
    """Create a safe filename from title and date."""
    # Extract date part
    date_part = date[:10]  # YYYY-MM-DD
    
    # Sanitize title
    title_part = re.sub(r'[^\w\s-]', '', title.lower())
    title_part = re.sub(r'[-\s]+', '-', title_part)
    title_part = title_part.strip('-')
    
    # Limit length
    if len(title_part) > 50:
        title_part = title_part[:50].rsplit('-', 1)[0]
    
    return f"{date_part}-{title_part}.md"


def convert_post(row: Dict[str, str]) -> tuple[str, str]:
    """Convert a single BearBlog post to Zola format."""
    title = row['title']
    slug = row['slug']
    published_date = row['published date']
    all_tags = row['all tags']
    content = row['content']
    
    # Parse tags
    tags = parse_tags(all_tags)
    
    # Classify and add more tags
    tags = classify_tags(title, content, tags)
    
    # Convert date
    zola_date = convert_date(published_date)
    
    # Create filename
    filename = sanitize_filename(title, zola_date)
    
    # Build frontmatter - escape quotes in title
    escaped_title = title.replace('"', '\\"')
    frontmatter = f"""+++
title = "{escaped_title}"
date = "{zola_date}"

[taxonomies]
tags = {tags}

[extra]
comment = true
+++

{content}
"""
    
    return filename, frontmatter


def main():
    """Main conversion function."""
    # Paths
    csv_path = Path("/Users/junebash/Downloads/post_export.csv")
    posts_dir = Path("/Users/junebash/repos/junebash_com_zola/content/posts")
    
    if not csv_path.exists():
        print(f"Error: CSV file not found at {csv_path}")
        return
    
    if not posts_dir.exists():
        print(f"Error: Posts directory not found at {posts_dir}")
        return
    
    # Read and convert posts
    converted_posts = []
    
    with open(csv_path, 'r', encoding='utf-8-sig') as csvfile:
        reader = csv.DictReader(csvfile)
        
        for row in reader:
            try:
                filename, content = convert_post(row)
                converted_posts.append((filename, content, row['title']))
                print(f"Converted: {row['title']} -> {filename}")
            except Exception as e:
                print(f"Error converting post '{row['title']}': {e}")
    
    # Preview what will be created
    print(f"\nReady to create {len(converted_posts)} posts:")
    for filename, _, title in converted_posts:
        print(f"  - {filename} ({title})")
    
    # Proceed with conversion
    print(f"\nProceeding with creating {len(converted_posts)} posts...")
    
    # Write posts
    created_count = 0
    for filename, content, title in converted_posts:
        post_path = posts_dir / filename
        
        # Check if file already exists
        if post_path.exists():
            print(f"Warning: {filename} already exists, skipping...")
            continue
        
        try:
            with open(post_path, 'w', encoding='utf-8') as f:
                f.write(content)
            created_count += 1
            print(f"Created: {filename}")
        except Exception as e:
            print(f"Error writing {filename}: {e}")
    
    print(f"\nConversion complete! Created {created_count} new posts.")
    print("You can now run 'zola build' to test the site.")


if __name__ == "__main__":
    main()