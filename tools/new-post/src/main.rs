use anyhow::Result;
use chrono::Local;
use clap::{Parser, Subcommand};
use inquire::{Confirm, MultiSelect, Text, required};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Parser)]
#[command(name = "new-post", about = "Scaffold new content for junebash.com")]
struct Cli {
    #[command(subcommand)]
    command: Cmd,

    /// Path to the site root (default: current directory)
    #[arg(long, default_value = ".")]
    root: PathBuf,
}

#[derive(Subcommand)]
enum Cmd {
    /// Create a new blog post interactively
    Post,
    /// Create a new "now" entry for today
    Now,
}

const KNOWN_TAGS: &[&str] = &[
    "ai",
    "announcements",
    "combine",
    "entertainment",
    "fiction",
    "film",
    "gamedev",
    "games",
    "habits",
    "ios",
    "life",
    "meditation",
    "microblog",
    "mindfulness",
    "music",
    "music-theory",
    "news",
    "personal",
    "philosophy",
    "poetry",
    "productivity",
    "programming",
    "quotes",
    "review",
    "short",
    "silly",
    "sound-design",
    "spirituality",
    "swift",
    "swiftui",
    "testing",
    "tutorial",
    "tv",
    "updates",
    "workflow",
];

fn slugify(title: &str) -> String {
    title
        .to_lowercase()
        .chars()
        .map(|c| if c.is_alphanumeric() { c } else { '-' })
        .collect::<String>()
        .split('-')
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>()
        .join("-")
}

fn open_in_editor(path: &Path) {
    let editor = std::env::var("EDITOR").unwrap_or_default();
    if editor.is_empty() {
        eprintln!("$EDITOR is not set. File created at: {}", path.display());
        return;
    }
    let status = Command::new(&editor).arg(path).status();
    match status {
        Ok(s) if s.success() => {}
        Ok(s) => eprintln!("{editor} exited with status {s}"),
        Err(e) => eprintln!("Failed to launch {editor}: {e}"),
    }
}

fn cmd_post(root: &Path) -> Result<()> {
    let title = Text::new("Post title:")
        .with_validator(required!("Title cannot be empty"))
        .prompt()?;

    let auto_slug = slugify(&title);
    let slug = Text::new("Slug:")
        .with_initial_value(&auto_slug)
        .with_validator(required!("Slug cannot be empty"))
        .prompt()?;

    let tags = MultiSelect::new("Tags (space to toggle, type to filter):", KNOWN_TAGS.to_vec())
        .with_vim_mode(true)
        .prompt()?;

    let comments = Confirm::new("Enable comments?")
        .with_default(true)
        .prompt()?;

    let now = Local::now();
    let date_str = now.format("%Y-%m-%d %H:%M:%S%:z").to_string();
    let file_date = now.format("%Y-%m-%d").to_string();
    let filename = format!("{file_date}-{slug}.md");
    let posts_dir = root.join("content/posts");
    let path = posts_dir.join(&filename);

    if path.exists() {
        let overwrite = Confirm::new(&format!(
            "{filename} already exists. Overwrite?"
        ))
        .with_default(false)
        .prompt()?;
        if !overwrite {
            println!("Aborted.");
            return Ok(());
        }
    }

    let tags_toml = tags
        .iter()
        .map(|t| format!("'{t}'"))
        .collect::<Vec<_>>()
        .join(", ");

    let mut frontmatter = format!(
        "+++\ntitle = \"{title}\"\ndate = \"{date_str}\"\n\n[taxonomies]\ntags = [{tags_toml}]\n"
    );
    if comments {
        frontmatter.push_str("\n[extra]\ncomment = true\n");
    }
    frontmatter.push_str("+++\n");

    fs::write(&path, frontmatter)?;
    println!("Created: {}", path.display());
    open_in_editor(&path);

    Ok(())
}

fn cmd_now(root: &Path) -> Result<()> {
    let today = Local::now().format("%Y-%m-%d").to_string();
    let filename = format!("{today}.md");
    let now_dir = root.join("content/now");
    let path = now_dir.join(&filename);

    if path.exists() {
        let open = Confirm::new(&format!(
            "{filename} already exists. Open it anyway?"
        ))
        .with_default(true)
        .prompt()?;
        if open {
            open_in_editor(&path);
        }
        return Ok(());
    }

    let frontmatter = format!("+++\ndate = {today}\n+++\n");
    fs::write(&path, frontmatter)?;
    println!("Created: {}", path.display());
    open_in_editor(&path);

    Ok(())
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Cmd::Post => cmd_post(&cli.root),
        Cmd::Now => cmd_now(&cli.root),
    }
}
