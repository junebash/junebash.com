#!/usr/bin/env python3
"""
Fix TOML escaping for embedded HTML in music files.
"""

import re
from pathlib import Path

def fix_embeds():
    """Fix TOML escaping for embedded HTML."""
    
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    # Find all music files
    music_dirs = [
        project_root / "content" / "solo_music",
        project_root / "content" / "band_music"
    ]
    
    for music_dir in music_dirs:
        for file_path in music_dir.glob("*.md"):
            if file_path.name == "_index.md":
                continue
                
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Fix bandcamp_embed and youtube_embed with triple quotes
            content = re.sub(
                r'(bandcamp_embed|youtube_embed) = "(<iframe.*?</iframe>)"',
                r"\1 = '''\2'''",
                content,
                flags=re.DOTALL
            )
            
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            print(f"✓ Fixed embeds in {file_path.name}")

if __name__ == "__main__":
    fix_embeds()