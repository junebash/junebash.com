#!/usr/bin/env python3
"""
Migration script to convert solo and band music from Jekyll to Zola format.
Creates individual pages for each music project with embedded players.
"""

import os
from pathlib import Path

def create_solo_band_music():
    """Create individual music project files for solo and band work."""
    
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    # Create directories
    solo_dir = project_root / "content" / "solo_music"
    band_dir = project_root / "content" / "band_music"
    
    solo_dir.mkdir(exist_ok=True)
    band_dir.mkdir(exist_ok=True)
    
    # Solo music section index
    solo_index_content = """+++
title = "Solo Music"
sort_by = "weight"

[extra]
comment = false
+++

Personal musical projects and solo work.
"""
    
    with open(solo_dir / "_index.md", 'w', encoding='utf-8') as f:
        f.write(solo_index_content)
    
    # Band music section index
    band_index_content = """+++
title = "Band Music"
sort_by = "weight"

[extra]
comment = false
+++

Collaborative musical projects and band work.
"""
    
    with open(band_dir / "_index.md", 'w', encoding='utf-8') as f:
        f.write(band_index_content)
    
    # Solo music projects
    solo_projects = [
        {
            "filename": "two-others-songs",
            "title": "Two Others' Songs",
            "date": "2019-01-01",
            "weight": 2019,
            "type": "Single",
            "description": "Covers of \"Here Comes a Thought\" from Steven Universe and \"How to Disappear Completely\" by Radiohead.",
            "youtube_embed": '<iframe width="100%" height="315" src="https://www.youtube.com/embed/YUhj-Bdcyh4" frameborder="0" allow="accelerometer; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>',
            "streaming_links": {
                "Apple Music": "https://music.apple.com/us/album/two-others-songs-single/1480748181",
                "Spotify": "https://open.spotify.com/album/3VE0eBAM5jwfhKPnVwC3Tn?si=48VaUyafSj2savcBrRQU8w",
                "YouTube Music": "https://music.youtube.com/playlist?list=OLAK5uy_k3-jXczcn9BHCBDMIHjwPjabyLKftijGY",
                "Amazon Music": "https://www.amazon.com/Two-Others-Songs-Jon-Bash/dp/B07Y7D8V8S/ref=sr_1_1"
            },
            "content": "These covers were a fun exploration of two very different but equally meaningful songs. \"Here Comes a Thought\" from Steven Universe captures the beautiful complexity of mindfulness and emotional awareness, while Radiohead's \"How to Disappear Completely\" explores themes of dissociation and escape."
        },
        {
            "filename": "carnage-bash",
            "title": "Carnage & Bash",
            "date": "2016-01-01",
            "weight": 2016,
            "type": "Split EP",
            "description": "A split EP of battle themes with Megan Carnes.",
            "bandcamp_embed": '<iframe style="border: 0; width: 100%; height: 786px; max-width: 500px;" src="https://bandcamp.com/EmbeddedPlayer/album=1322625898/size=large/bgcol=ffffff/linkcol=0687f5/tracklist=true/transparent=true/" seamless><a href="http://friendsofsatan.bandcamp.com/album/carnage-bash">Carnage &amp; Bash by Megan Carnes and June Bash</a></iframe>',
            "collaboration": "Megan Carnes",
            "content": "A collaborative split EP exploring themes of conflict and resolution through electronic battle music. This project combined my electronic composition style with Megan's unique approach to create something entirely new."
        },
        {
            "filename": "curves-and-angles",
            "title": "Curves and Angles", 
            "date": "2015-01-01",
            "weight": 2015,
            "type": "Album",
            "description": "Instrumental electronic music for a non-existent game.",
            "bandcamp_embed": '<iframe style="border: 0; width: 100%; height: 786px; max-width: 500px;" src="https://bandcamp.com/EmbeddedPlayer/album=598309408/size=large/bgcol=ffffff/linkcol=0687f5/transparent=true/" seamless><a href="http://junebash.bandcamp.com/album/curves-and-angles">Curves and Angles by June Bash</a></iframe>',
            "content": "An imaginary video game soundtrack that explores the intersection of geometric forms and musical structure. Each track represents different aspects of a hypothetical game world, from exploration themes to boss battles."
        },
        {
            "filename": "born-again-shell",
            "title": "born-again shell",
            "date": "2014-01-01", 
            "weight": 2014,
            "type": "Album",
            "description": "Eclectic electronic/rock/pop/folk music with vocals.",
            "bandcamp_embed": '<iframe style="border: 0; width: 100%; height: 786px; max-width: 500px;" src="https://bandcamp.com/EmbeddedPlayer/album=4194073772/size=large/bgcol=ffffff/linkcol=0687f5/transparent=true/" seamless><a href="http://junebash.bandcamp.com/album/born-again-shell">born-again shell by June Bash</a></iframe>',
            "content": "A deeply personal album that combines electronic production with organic instruments and vocals. The title reflects themes of transformation and finding new identity through creative expression."
        },
        {
            "filename": "nonscapes",
            "title": "Nonscapes",
            "date": "2013-01-01",
            "weight": 2013,
            "type": "Album", 
            "description": "Electroacoustic music that tends towards the strange and unsavory.",
            "bandcamp_embed": '<iframe style="border: 0; width: 100%; height: 786px; max-width: 500px;" src="https://bandcamp.com/EmbeddedPlayer/album=1698769362/size=large/bgcol=ffffff/linkcol=0687f5/transparent=true/" seamless><a href="http://Junebash.bandcamp.com/album/nonscapes">Nonscapes by June Bash</a></iframe>',
            "content": "An experimental exploration of unconventional soundscapes and textures. This album deliberately ventures into uncomfortable sonic territory, challenging traditional notions of melody and harmony."
        },
        {
            "filename": "we-shall-overcome",
            "title": "We Shall Overcome",
            "date": "2012-01-01",
            "weight": 2012,
            "type": "Single",
            "description": "A folk cover for charity.",
            "bandcamp_embed": '<iframe style="border: 0; width: 100%; height: 442px; max-width: 370px;" src="https://bandcamp.com/EmbeddedPlayer/track=2511502892/size=large/bgcol=ffffff/linkcol=0687f5/tracklist=false/transparent=true/" seamless><a href="http://Junebash.bandcamp.com/track/we-shall-overcome">We Shall Overcome by June Bash</a></iframe>',
            "content": "A folk interpretation of the classic protest song, recorded to support charitable causes. This cover maintains the song's powerful message while bringing a personal acoustic approach to the timeless melody."
        }
    ]
    
    # Band music projects
    band_projects = [
        {
            "filename": "vr-trainers-thrillwave",
            "title": "Thrillwave",
            "date": "2017-01-01",
            "weight": 2017,
            "type": "Album",
            "band": "VR Trainers",
            "description": "Electronic rock-pop album with John Von Volkli.",
            "bandcamp_embed": '<iframe style="border: 0; width: 100%; height: 700px; max-width: 500px;" src="https://bandcamp.com/EmbeddedPlayer/album=3540732731/size=large/bgcol=ffffff/linkcol=0687f5/transparent=true/" seamless><a href="http://vrtrainers.bandcamp.com/album/thrillwave">Thrillwave by VR Trainers</a></iframe>',
            "content": "The culminating album from VR Trainers, blending electronic production with rock and pop sensibilities. Created in collaboration with John Von Volkli, this album represents the peak of our creative partnership."
        },
        {
            "filename": "vr-trainers-image", 
            "title": "Image",
            "date": "2016-01-01",
            "weight": 2016,
            "type": "Album",
            "band": "VR Trainers",
            "description": "Electronic rock-pop album with John Von Volkli.",
            "bandcamp_embed": '<iframe style="border: 0; width: 100%; height: 700px; max-width: 500px;" src="https://bandcamp.com/EmbeddedPlayer/album=4184207669/size=large/bgcol=ffffff/linkcol=0687f5/transparent=true/" seamless><a href="http://vrtrainers.bandcamp.com/album/image">Image by VR Trainers</a></iframe>',
            "content": "An exploration of identity and perception through electronic rock. This album delved into themes of self-image and reality, combining introspective lyrics with energetic electronic production."
        }
    ]
    
    # Create solo music files
    for project in solo_projects:
        frontmatter = {
            'title': project['title'],
            'date': project['date'],
            'weight': project['weight'],
            'template': 'music_project.html'
        }
        
        extra = {
            'type': project['type'],
            'description': project['description']
        }
        
        if 'youtube_embed' in project:
            extra['youtube_embed'] = project['youtube_embed']
        if 'bandcamp_embed' in project:
            extra['bandcamp_embed'] = project['bandcamp_embed']
        if 'collaboration' in project:
            extra['collaboration'] = project['collaboration']
        if 'streaming_links' in project:
            extra['streaming_links'] = project['streaming_links']
            
        frontmatter['extra'] = extra
        
        filename = f"{project['filename']}.md"
        filepath = solo_dir / filename
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write('+++\n')
            f.write(f'title = "{frontmatter["title"]}"\n')
            f.write(f'date = "{frontmatter["date"]}"\n')
            f.write(f'weight = {frontmatter["weight"]}\n')
            f.write(f'template = "{frontmatter["template"]}"\n\n')
            f.write('[extra]\n')
            for key, value in extra.items():
                if key == 'streaming_links':
                    f.write('streaming_links = {\n')
                    for service, url in value.items():
                        f.write(f'  "{service}" = "{url}",\n')
                    f.write('}\n')
                else:
                    f.write(f'{key} = "{value}"\n')
            f.write('+++\n\n')
            f.write(project['content'] + '\n')
        
        print(f"✓ Created solo music: {filename}")
    
    # Create band music files
    for project in band_projects:
        frontmatter = {
            'title': project['title'],
            'date': project['date'],
            'weight': project['weight'],
            'template': 'music_project.html'
        }
        
        extra = {
            'type': project['type'],
            'band': project['band'],
            'description': project['description'],
            'bandcamp_embed': project['bandcamp_embed']
        }
            
        frontmatter['extra'] = extra
        
        filename = f"{project['filename']}.md"
        filepath = band_dir / filename
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write('+++\n')
            f.write(f'title = "{frontmatter["title"]}"\n')
            f.write(f'date = "{frontmatter["date"]}"\n')
            f.write(f'weight = {frontmatter["weight"]}\n')
            f.write(f'template = "{frontmatter["template"]}"\n\n')
            f.write('[extra]\n')
            for key, value in extra.items():
                f.write(f'{key} = "{value}"\n')
            f.write('+++\n\n')
            f.write(project['content'] + '\n')
        
        print(f"✓ Created band music: {filename}")
    
    print(f"\nMigration complete!")
    print(f"Solo music: {len(solo_projects)} projects in {solo_dir}")
    print(f"Band music: {len(band_projects)} projects in {band_dir}")
    
    return True

if __name__ == "__main__":
    create_solo_band_music()