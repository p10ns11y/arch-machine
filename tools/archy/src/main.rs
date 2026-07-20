//! archy — Ratatui **entry and loop controller** for arch-machine.
//!
//! - Main interface for operators (don't get lost: breadcrumbs + next actions)
//! - Runs shell scripts / Go `tinfoil` / `install.sh` as backends
//! - Renders stdio cleanly for decide → fix → re-run
//! - Grok dock: split or fullscreen launch (TUI suspends for interactive Grok)

mod actions;
mod app;
mod cmd;
mod eagle;
mod fsm;
mod grok_launch;
mod jobs;
mod msg;
mod nav;
mod root;
mod satellites;
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
                    app.dispatch_key(key);
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
    // Leave TUI — interactive Grok needs the real terminal.
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    let fullscreen = matches!(app.grok_mode, app::GrokMode::Full);
    let ask = app.suggested_grok_ask();

    println!();
    println!("══════════════════════════════════════════════════");
    println!("  archy → Grok  (interactive co-pilot, prompt preloaded)");
    println!("  root: {}", app.root.display());
    println!("  Exit Grok to return to the control plane.");
    println!("══════════════════════════════════════════════════");
    println!();

    let (ctx_path, prompt_path, composed) = match grok_launch::write_launch_files(
        &app.root,
        &app.grok_context,
        &ask,
        &app.grok_prompt,
    ) {
        Ok(t) => t,
        Err(e) => {
            eprintln!("failed to write Grok context/prompt files: {e}");
            app.push_line(format!("✗ grok context write failed: {e}"));
            wait_enter();
            enable_raw_mode()?;
            execute!(terminal.backend_mut(), EnterAlternateScreen)?;
            terminal.hide_cursor()?;
            terminal.clear()?;
            return Ok(());
        }
    };

    println!("Context: {}", ctx_path.display());
    println!("Prompt file: {}", prompt_path.display());
    println!("Suggested ask: {ask}");
    println!();
    // Show a short head of the composed prompt so operator sees it is not empty.
    let preview: String = composed.chars().take(200).collect();
    println!("Preload preview: {preview}…");
    println!();

    match app.grok_launch_command(fullscreen) {
        Some(mut cmd) => {
            // Sanity: must not be bare `grok` (env-only).
            if let Some(plan) = app.grok_launch_plan(fullscreen) {
                if !plan.has_preload_prompt() {
                    eprintln!("internal error: launch plan missing preload prompt");
                    app.push_line("✗ grok launch missing preload".into());
                    wait_enter();
                } else {
                    println!(
                        "Launch: grok {} …",
                        plan.args
                            .iter()
                            .take(4)
                            .cloned()
                            .collect::<Vec<_>>()
                            .join(" ")
                    );
                    println!();
                    cmd.stdin(Stdio::inherit());
                    cmd.stdout(Stdio::inherit());
                    cmd.stderr(Stdio::inherit());
                    match cmd.status() {
                        Ok(st) => {
                            app.push_line(format!(
                                "■ Grok session ended (exit={})",
                                st.code().unwrap_or(1)
                            ));
                            app.status =
                                format!("returned from Grok exit={}", st.code().unwrap_or(1));
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
