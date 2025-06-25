# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Note: This project is in early development stages and evolving rapidly. Architecture decisions, theme choices, and content structure may change frequently. Always verify current implementation details rather than assuming based on this documentation alone.**

## Repository Overview

This is a personal website built with Zola static site generator, using the Apollo theme. The site includes blog posts, project pages, and an about section. The goal is to migrate existing content from the old website while modernizing and improving maintainability.

**Migration**: See `MIGRATION.md` for detailed analysis and step-by-step plan for migrating content from the existing Jekyll-based site (`../junebash.com`).

## Key Commands

### Development
- `zola serve` - Start development server with live reload (typically runs on http://127.0.0.1:1111)
- `zola build` - Build the static site for production (outputs to `public/` directory)
- `zola check` - Validate the site without building (checks links and structure)

### Content Management
- Content files are Markdown with TOML frontmatter in the `content/` directory
- Posts go in `content/posts/` with pagination configured for 7 posts per page
- Projects go in `content/projects/`
- Static assets go in `static/` directory

## Architecture

### File Structure
- **config.toml** - Main site configuration with theme settings, menu, and social links
- **content/** - All Markdown content organized by section
  - **posts/** - Blog posts with `_index.md` configuring pagination and sorting by date
  - **projects/** - Project pages 
  - **about.md** - About page
- **themes/apollo/** - Apollo theme as git submodule, contains templates, styles, and JavaScript
- **sass/** - Custom SCSS overrides (currently empty, theme uses its own styles)
- **static/** - Static assets served directly 
- **templates/** - Custom template overrides (currently empty, using theme templates)

### Apollo Theme Integration
- Theme installed as git submodule in `themes/apollo/`
- Site uses Apollo's templates, SCSS, and JavaScript from the theme directory
- Theme provides dark/light/auto mode switching, social links, project cards, and MathJax support
- Configuration done through `[extra]` section in `config.toml`

### Content Structure
- All content uses TOML frontmatter (between `+++` markers)
- Posts support tags taxonomy, comments, and date-based sorting
- Projects use card-based layout from theme
- Custom homepage template configured via `template = "homepage.html"`

### Theme Features
- Responsive design with dark/light theme toggle
- Social media integration (currently configured for Bluesky, GitHub, Bandcamp)
- Tag-based taxonomy system
- MathJax for mathematical expressions
- Syntax highlighting for code blocks
- Comments support (configurable per page/section)

## Content Migration Notes

When migrating content from the old website:
- Ensure frontmatter uses TOML format (between `+++` markers)
- Posts need `title`, `date`, and optionally `updated` fields
- Use `[taxonomies]` section for tags: `tags=["tag1", "tag2"]`
- Enable comments with `[extra]` section: `comment = true`
- Place images in `static/` and reference with absolute paths
- Code blocks support syntax highlighting automatically