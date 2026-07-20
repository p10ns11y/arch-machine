//! archy — Ratatui **entry and loop controller** for arch-machine.
//!
//! - Main interface for operators (don't get lost: breadcrumbs + next actions)
//! - Runs shell scripts / Go `tinfoil` / `install.sh` as backends
//! - Renders stdio cleanly for decide → fix → re-run
//! - Grok dock: split or fullscreen launch (TUI suspends for interactive Grok)

mod actions;
mod app;
mod jobs;
mod nav;
mod root;
mod theme;
mod ui;

use app::App;
use clap::Parser;
use crossterm::event::{self, Event, KeyEventKind};
use crossterm::execute;
use crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;
use std::io::{self, stdout};
use std::path::PathBuf;
use std::process::Stdio;
use std::time::Duration;

#[derive(Parser, Debug)]
#[command(
    name = "archy",
    about = "arch-machine control plane (Ratatui) — inventory, audit, install dry-run, Grok dock"
)]
struct Cli {
    /// arch-machine / tinfoil root (default: auto-detect)
    #[arg(long, env = "TINFOIL_ROOT")]
    root: Option<PathBuf>,

    /// Start with Grok split dock visible
    #[arg(long)]
    grok_split: bool,

    /// Print root and exit (agent smoke)
    #[arg(long)]
    print_root: bool,
}

fn main() -> io::Result<()> {
    let cli = Cli::parse();
    if let Some(r) = cli.root {
        std::env::set_var("TINFOIL_ROOT", &r);
    }
    if cli.print_root {
        println!("{}", root::discover_root().display());
        return Ok(());
    }

    let mut app = App::new();
    if cli.grok_split {
        app.grok_mode = app::GrokMode::Split;
    }

    install_panic_hook();
    enable_raw_mode()?;
    let mut out = stdout();
    execute!(out, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(out);
    let mut terminal = Terminal::new(backend)?;

    let result = run_loop(&mut terminal, &mut app);

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    if let Err(e) = &result {
        eprintln!("archy error: {e}");
    }
    result
}

fn run_loop(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
    app: &mut App,
) -> io::Result<()> {
    loop {
        terminal.draw(|f| ui::draw(f, app))?;

        // Launch Grok: suspend alternate screen so interactive CLI works
        if app.pending_grok_launch {
            app.pending_grok_launch = false;
            suspend_and_run_grok(terminal, app)?;
        }

        app.tick();

        if event::poll(Duration::from_millis(80))? {
            if let Event::Key(key) = event::read()? {
                // crossterm 0.28: only Press
                if key.kind == KeyEventKind::Press {
                    app.on_key(key);
                }
            }
        }

        if app.should_quit {
            break;
        }
    }
    Ok(())
}

fn suspend_and_run_grok(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
    app: &mut App,
) -> io::Result<()> {
    // Leave TUI
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    println!();
    println!("══════════════════════════════════════════════════");
    println!("  archy → Grok  (interactive co-pilot)");
    println!("  root: {}", app.root.display());
    println!("  Exit Grok to return to the control plane.");
    println!("══════════════════════════════════════════════════");
    println!();
    // Write context file for operator / agent
    let ctx_path = app.root.join("logs/archy-grok-context.txt");
    if let Some(parent) = ctx_path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    let ask = app.suggested_grok_ask();
    let _ = std::fs::write(
        &ctx_path,
        format!(
            "{}\n\n--- suggested ask ---\n{}\n\n--- standing orders ---\n{}\n",
            app.grok_context, ask, app.grok_prompt
        ),
    );
    println!("Context written: {}", ctx_path.display());
    println!("Suggested ask: {ask}");
    println!();

    match app.grok_launch_command() {
        Some(mut cmd) => {
            cmd.stdin(Stdio::inherit());
            cmd.stdout(Stdio::inherit());
            cmd.stderr(Stdio::inherit());
            // Prefer starting in repo; pass path as soft arg if grok supports it later
            match cmd.status() {
                Ok(st) => {
                    app.push_line(format!(
                        "■ Grok session ended (exit={})",
                        st.code().unwrap_or(1)
                    ));
                    app.status = format!("returned from Grok exit={}", st.code().unwrap_or(1));
                }
                Err(e) => {
                    app.push_line(format!("✗ failed to launch Grok: {e}"));
                    app.status = "Grok launch failed".into();
                    eprintln!("failed to launch Grok: {e}");
                    eprintln!("Install/path: ensure `grok` is on PATH.");
                    wait_enter();
                }
            }
        }
        None => {
            eprintln!("`grok` not found on PATH.");
            eprintln!("Context still saved at {}", ctx_path.display());
            app.push_line("✗ grok binary not found".into());
            wait_enter();
        }
    }

    // Resume TUI
    enable_raw_mode()?;
    execute!(terminal.backend_mut(), EnterAlternateScreen)?;
    terminal.hide_cursor()?;
    terminal.clear()?;
    app.grok_mode = app::GrokMode::Split;
    app.focus = app::Focus::Main;
    Ok(())
}

fn wait_enter() {
    println!("Press Enter to return to archy…");
    let mut s = String::new();
    let _ = io::stdin().read_line(&mut s);
}

fn install_panic_hook() {
    let original = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        let _ = disable_raw_mode();
        let mut out = io::stdout();
        let _ = execute!(out, LeaveAlternateScreen);
        original(info);
    }));
}
