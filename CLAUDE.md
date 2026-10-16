# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Personal website built with Zola static site generator using the Apollo theme. Content spans programming, music, philosophy, games, films, and personal updates.

## Key Commands

- `zola serve` - Development server with live reload (http://127.0.0.1:1111)
- `zola build` - Build static site to `public/`
- `zola check` - Validate site without building

## Fancy mode (`fancy/`)

A terminal version of the site, written in Swift and compiled to WebAssembly. It's served at fancy.junebash.com, and at `/fancy/` locally and on deploy previews.

- `just fancy` builds it into `static/fancy/build/<hash>/` and updates `manifest.toml`. Rerun it after any change in `fancy/Sources` or `fancy/web` (the CSS lives there), then commit the build output. New posts need no rebuild: `templates/fancy.html` embeds the content at Zola build time.
- `just fancy-test` runs the core tests (`FancyCore`) on macOS.
- The toolchain is swift.org Swift 6.3.3 plus its WASM SDK, run through `~/.swiftly/bin/swiftly`, which is not on PATH. Never `import Foundation` in `fancy/`: it adds about 10MB. The build fails above 3MB of compressed wasm.
- `zola serve` caches the manifest, so restart it after a build. Deep links under `/fancy/` only work where the Netlify rewrite applies.

## Architecture

### Content Structure (`content/`)

- **posts/** - Blog posts with TOML frontmatter and tag taxonomy
- **now/** - Timeline-style life updates
- **code/** - Code projects and app showcases
- **music.md** - Music landing page
- **band_music/**, **solo_music/**, **concert_music/** - Music project subsections
- **films/** - Film projects
- **games/** - Game projects
- **about/** - About page

### Templates (`templates/`)

Custom templates override the Apollo theme:
- `homepage.html`, `base.html` - Site-wide templates
- `code.html`, `app_showcase.html` - Code project templates
- `music.html`, `music_project.html`, `concert_piece.html` - Music templates
- `film_project.html`, `game_project.html` - Media project templates
- `now.html`, `now_page.html` - Now section templates
- `about.html` - About page template

### Configuration

- **config.toml** - Site config, navigation, socials, taxonomy
- **themes/apollo/** - Apollo theme (git submodule)
- **static/** - Images and assets
- **sass/** - Custom styles (compiled automatically)

### Content Frontmatter

All content uses TOML frontmatter between `+++` markers. Common fields:
- `title`, `date`, `description`
- `tags` - For taxonomy
- `template` - Override default template
- `extra` - Template-specific data

## Navigation

Menu: code → music → about → posts → now
