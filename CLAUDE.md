# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Migration Status: Phase 2 Complete ✅** - All core content successfully migrated from Jekyll. Only creative content consolidation remains.

## Repository Overview

This is a personal website built with Zola static site generator, using the Apollo theme. The site successfully migrated from Jekyll and includes:

- **67 blog posts** (2014-2025) covering programming, music, philosophy, and personal topics
- **12 now updates** (2020-2023) with timeline-style presentation  
- **Project showcases** for code projects
- **Unified music page** ready for creative content consolidation
- **Enhanced navigation** with dedicated sections for different content types

**Migration**: Major migration from Jekyll completed. See `MIGRATION.md` for historical analysis. All blog posts, now updates, and assets successfully converted.

## Key Commands

### Development
- `zola serve` - Start development server with live reload (typically runs on http://127.0.0.1:1111)
- `zola build` - Build the static site for production (outputs to `public/` directory)
- `zola check` - Validate the site without building (checks links and structure)

### Content Management
- Content files are Markdown with TOML frontmatter in the `content/` directory
- Posts go in `content/posts/` with pagination configured for 7 posts per page
- Now updates go in `content/now/` with chronological timeline presentation
- Projects go in `content/projects/`
- Music page at `content/music.md` with custom template for creative content
- Static assets go in `static/images/` directory (migrated from Jekyll)

## Architecture

### File Structure
- **config.toml** - Main site configuration with enhanced navigation and taxonomy mapping
- **content/** - All Markdown content organized by section
  - **posts/** - 67 migrated blog posts with TOML frontmatter and tag taxonomy
  - **now/** - 12 migrated now updates with timeline template
  - **projects/** - Project pages using Apollo card layout
  - **music.md** - Unified music page with custom template
  - **about.md** - About page
- **themes/apollo/** - Apollo theme as git submodule
- **static/images/** - Migrated assets from Jekyll site (~11MB)
- **templates/** - Custom templates for music and now sections
- **scripts/** - Python migration utilities with UV environment
- **.venv/** - Python virtual environment for migration tools

### Apollo Theme Integration
- Theme installed as git submodule in `themes/apollo/`
- Site uses Apollo's templates, SCSS, and JavaScript from the theme directory
- Theme provides dark/light/auto mode switching, social links, project cards, and MathJax support
- Configuration done through `[extra]` section in `config.toml`

### Content Structure & Taxonomy
- All content uses TOML frontmatter (between `+++` markers) migrated from Jekyll YAML
- Enhanced tag taxonomy system mapped from Jekyll categories:
  - `programming`, `swift`, `ios`, `combine`, `swiftui` (Code posts)
  - `music`, `composition` (Music posts)  
  - `meditation`, `philosophy`, `spirituality` (Dharma posts)
  - `personal`, `life`, `updates` (Personal posts)
  - `gamedev`, `film`, `review` (Games & Films posts)
  - `productivity`, `workflow` (Productivity posts)
- Posts support automatic tag assignment, comments, and date-based sorting
- Now updates use timeline-style presentation with `now`, `personal`, `updates` tags
- Projects use card-based layout from theme

### Theme Features
- Responsive design with dark/light theme toggle
- Social media integration (currently configured for Bluesky, GitHub, Bandcamp)
- Tag-based taxonomy system
- MathJax for mathematical expressions
- Syntax highlighting for code blocks
- Comments support (configurable per page/section)

## Migration Tools & Status

### Completed Migration (Phase 2)
- ✅ All 67 blog posts migrated from Jekyll with YAML→TOML conversion
- ✅ All 12 now updates migrated with proper timeline structure  
- ✅ All assets (~11MB) migrated from `/assets/images/` to `/static/images/`
- ✅ Category→tag mapping with intelligent content analysis
- ✅ Custom templates for music and now sections
- ✅ Site builds successfully: 90 pages, 126 HTML files, 20MB total

### Migration Scripts (in scripts/)
- **migrate_content.py** - YAML→TOML blog post conversion with smart tagging
- **migrate_now_updates.py** - Now updates conversion with timeline structure
- **fix_asset_paths.py** - Update asset references from Jekyll to Zola paths
- **fix_dates.py** - Normalize date formats for TOML compatibility

### Python Environment
- Uses UV for dependency management (`uv venv`, `uv pip install`)
- Dependencies: `pyyaml`, `toml`
- Activate with: `source .venv/bin/activate`

### Remaining Tasks
- Music page population with creative projects (games, films, concert music)
- Optional: Further content organization and SEO optimization