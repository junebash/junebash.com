# Website Migration Plan

Migration from Jekyll-based site (`../junebash.com`) to Zola + Apollo theme.

## Current State Analysis

### Old Site (Jekyll - ../junebash.com)
- **Framework**: Jekyll with custom layouts and Bootstrap styling
- **Content**: 73+ blog posts (2014-2025), multiple content collections
- **Structure**:
  - `_posts/` - Blog posts with YAML frontmatter
  - `_games/` - 7 game music projects
  - `_films/` - 6 film music projects  
  - `_concert-music/` - 10 concert works
  - `_now-updates/` - 12 status updates (2020-2023)
  - `_data/code-projects.yml` - 7 software projects
  - About page with bio, skills, acknowledgments
- **Navigation**: Complex menu with music subcategories
- **Assets**: Extensive image collection in `assets/images/`

### New Site (Zola + Apollo)
- **Framework**: Zola static site generator with Apollo theme
- **Current State**: Basic setup with sample content
- **Structure**: Simple posts/projects/about organization
- **Frontmatter**: TOML format (vs YAML in old site)

## Migration Strategy

### Phase 1: Content Structure Setup
**Goal**: Prepare new site structure to accommodate all content types

#### Tasks:
1. **Configure taxonomy system**
   - Add categories/tags to `config.toml` for content organization
   - Categories: Code, Music, Personal, Reviews, etc.

2. **Reorganize projects structure**
   - Decide: unified projects vs. separate music/code sections
   - Update Apollo theme navigation if needed

3. **Plan content categorization**
   - Map Jekyll collections to Zola taxonomy
   - Decide on "now updates" handling (posts vs. separate section)

### Phase 2: Content Migration
**Goal**: Transfer all content with proper format conversion

#### Blog Posts (73+ posts)
- **Format conversion**: YAML frontmatter → TOML
- **Date handling**: Ensure proper sorting by publication date
- **Content review**: Check for Jekyll-specific syntax that needs updating
- **Categories**: Apply appropriate tags based on content analysis

#### Projects Migration
- **Code projects**: Convert from `_data/code-projects.yml` to individual markdown files
- **Creative projects**: Migrate game/film/concert music from collections
- **Asset migration**: Copy and update image references

#### About Page
- **Bio content**: Migrate from `_includes/about/bio.md`
- **Skills/acknowledgments**: Integrate additional about content
- **Contact info**: Update social links and contact methods

#### Static Assets
- **Images**: Copy from `assets/images/` and update paths
- **Other files**: Resume, app store assets, etc.

### Phase 3: Content Enhancement
**Goal**: Improve content organization and discoverability

#### Tagging & Organization
- **Apply consistent tagging**: Code, Music, Personal, Reviews, Lambda School, iOS, etc.
- **Cross-references**: Update internal links between posts
- **Archive organization**: Ensure chronological browsing works well

#### Navigation & UX
- **Menu structure**: Simplify from complex old navigation
- **Social links**: Update to current platforms (Bluesky, GitHub, Bandcamp)
- **Search**: Configure if Apollo theme supports it

### Phase 4: Styling & Polish
**Goal**: Customize appearance and final refinements

#### Theme Customization
- **Apollo modifications**: Any needed styling changes
- **Brand consistency**: Ensure visual identity carries over
- **Mobile optimization**: Verify responsive design

#### Final Review
- **Link checking**: Ensure all internal/external links work
- **Content review**: Final proofreading and formatting check
- **Performance**: Optimize images and build process

## Key Decisions Needed

### Content Organization
1. **Now Updates**: 
   - Option A: Convert to regular blog posts with "now" tag
   - Option B: Maintain as separate section
   - **Recommendation**: Convert to posts - fits better with chronological blog structure

2. **Projects Organization**:
   - Option A: Single unified projects section
   - Option B: Separate music/code project sections  
   - **Recommendation**: Unified section with tags for filtering

3. **Music Content**:
   - **Games/Films**: Could become project entries or blog posts about the work
   - **Concert Music**: Likely project entries with embedded audio/scores if available

### Technical Considerations
- **URL structure**: Maintain existing permalinks where possible for SEO
- **Asset optimization**: Compress images during migration
- **RSS/Feed**: Ensure feed continues working for existing subscribers

## Migration Timeline

### Immediate (Phase 1)
- [ ] Configure taxonomy in `config.toml`
- [ ] Set up project structure decisions
- [ ] Plan content categorization scheme

### Near-term (Phase 2)  
- [ ] Convert blog posts (can be automated partially)
- [ ] Migrate about page content
- [ ] Transfer and organize assets

### Medium-term (Phases 3-4)
- [ ] Apply tagging and enhance content
- [ ] Theme customization and styling
- [ ] Final review and launch

## Notes
- **Backup**: Ensure old site remains accessible during migration
- **SEO**: Consider redirect mapping for changed URLs
- **Testing**: Verify site builds and serves correctly throughout process
- **Content gaps**: Some very old posts may need additional review/updating