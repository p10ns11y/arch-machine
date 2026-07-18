//! Layout: header breadcrumb · body (main | split Grok) · output · next-actions · footer.
//! Goal: operator always knows where they are and what to do next.

use crate::app::{App, Focus, GrokMode, Screen};
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Clear, List, ListItem, Paragraph, Wrap};
use ratatui::Frame;

const GREEN: Color = Color::Rgb(80, 200, 120);
const CYAN: Color = Color::Rgb(100, 200, 220);
const AMBER: Color = Color::Rgb(230, 180, 80);
const DIM: Color = Color::Rgb(120, 120, 130);
const BG_PANEL: Color = Color::Rgb(20, 22, 28);

pub fn draw(f: &mut Frame, app: &App) {
    let area = f.area();
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // header
            Constraint::Min(8),    // body
            Constraint::Length(if app.next_actions.is_empty() { 0 } else { 3 }),
            Constraint::Length(1), // footer
        ])
        .split(area);

    draw_header(f, chunks[0], app);

    match app.screen {
        Screen::Help => draw_help(f, chunks[1], app),
        Screen::Home | Screen::Output => draw_body(f, chunks[1], app),
    }

    if !app.next_actions.is_empty() {
        draw_actions(f, chunks[2], app);
    }
    draw_footer(f, chunks[3], app);
}

fn draw_header(f: &mut Frame, area: Rect, app: &App) {
    let crumb = app.breadcrumb.join(" › ");
    let grok = match app.grok_mode {
        GrokMode::Hidden => "Grok:off",
        GrokMode::Split => "Grok:split",
        GrokMode::Full => "Grok:full",
    };
    let job = if app.job.is_some() {
        "● RUNNING"
    } else if let Some(c) = app.last_exit {
        if c == 0 {
            "○ idle"
        } else {
            "○ last≠0"
        }
    } else {
        "○ idle"
    };

    let title = Line::from(vec![
        Span::styled(
            " 🛡 tinfoil ",
            Style::default()
                .fg(GREEN)
                .add_modifier(Modifier::BOLD),
        ),
        Span::styled("control plane  ", Style::default().fg(CYAN)),
        Span::styled(crumb, Style::default().fg(Color::White)),
        Span::raw("  "),
        Span::styled(job, Style::default().fg(AMBER)),
        Span::raw("  "),
        Span::styled(grok, Style::default().fg(DIM)),
    ]);

    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(GREEN))
        .title(" entry · loop · backends ");
    let p = Paragraph::new(title).block(block);
    f.render_widget(p, area);
}

fn draw_body(f: &mut Frame, area: Rect, app: &App) {
    match app.grok_mode {
        GrokMode::Hidden => draw_main_column(f, area, app),
        GrokMode::Split => {
            let cols = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([Constraint::Percentage(62), Constraint::Percentage(38)])
                .split(area);
            draw_main_column(f, cols[0], app);
            draw_grok_dock(f, cols[1], app);
        }
        GrokMode::Full => {
            draw_grok_dock(f, area, app);
        }
    }
}

fn draw_main_column(f: &mut Frame, area: Rect, app: &App) {
    // Menu on top third when Home; output fills rest (or all on Output)
    let (menu_h, out_h) = match app.screen {
        Screen::Home => (Constraint::Length(12), Constraint::Min(4)),
        Screen::Output => (Constraint::Length(0), Constraint::Min(4)),
        Screen::Help => (Constraint::Min(1), Constraint::Min(1)),
    };

    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([menu_h, out_h])
        .split(area);

    if app.screen == Screen::Home {
        draw_menu(f, rows[0], app);
        draw_output(f, rows[1], app);
    } else {
        draw_output(f, area, app);
    }
}

fn draw_menu(f: &mut Frame, area: Rect, app: &App) {
    let items: Vec<ListItem> = app
        .menu_items()
        .iter()
        .enumerate()
        .map(|(i, label)| {
            let selected = i == app.menu_idx && app.focus == Focus::Main;
            let prefix = if selected { "▸ " } else { "  " };
            let style = if selected {
                Style::default()
                    .fg(Color::Black)
                    .bg(GREEN)
                    .add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(Color::White)
            };
            ListItem::new(format!("{prefix}{}. {label}", i + 1)).style(style)
        })
        .collect();

    let border = if app.focus == Focus::Main {
        Style::default().fg(GREEN)
    } else {
        Style::default().fg(DIM)
    };

    let list = List::new(items).block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(border)
            .title(" commands (Enter) ")
            .style(Style::default().bg(BG_PANEL)),
    );
    f.render_widget(list, area);
}

fn draw_output(f: &mut Frame, area: Rect, app: &App) {
    let border = if app.focus == Focus::Output {
        Style::default().fg(CYAN)
    } else {
        Style::default().fg(DIM)
    };

    let title = if app.job.is_some() {
        " stdio · live "
    } else {
        " stdio · scroll j/k · space=tail "
    };

    let height = area.height.saturating_sub(2) as usize;
    let total = app.lines.len();
    let scroll = app.scroll as usize;
    // show window ending near scroll
    let start = if total > height {
        scroll.saturating_sub(height.saturating_sub(1)).min(total.saturating_sub(height))
    } else {
        0
    };
    let end = (start + height).min(total);
    let text: Vec<Line> = app.lines[start..end]
        .iter()
        .map(|l| {
            let style = if l.starts_with('▶') || l.starts_with('■') {
                Style::default().fg(AMBER)
            } else if l.starts_with("✗") || l.contains("error") || l.contains("ERROR") {
                Style::default().fg(Color::Red)
            } else if l.starts_with('✓') || l.contains("success") {
                Style::default().fg(GREEN)
            } else if l.starts_with("[stderr]") {
                Style::default().fg(Color::Rgb(220, 140, 140))
            } else {
                Style::default().fg(Color::Rgb(200, 200, 205))
            };
            Line::from(Span::styled(l.clone(), style))
        })
        .collect();

    let p = Paragraph::new(text)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(border)
                .title(title)
                .style(Style::default().bg(BG_PANEL)),
        )
        .wrap(Wrap { trim: false });
    f.render_widget(p, area);
}

fn draw_grok_dock(f: &mut Frame, area: Rect, app: &App) {
    let border = if app.focus == Focus::GrokDock {
        Style::default().fg(AMBER)
    } else {
        Style::default().fg(DIM)
    };

    let body = format!(
        "Grok dock\n\
         ─────────\n\
         Mode: {:?}  ·  Launch: G or menu\n\
         (TUI suspends; returns here after)\n\
         \n\
         Prompt hint:\n{}\n\
         \n\
         Context tail (auto):\n{}",
        app.grok_mode,
        app.grok_prompt,
        truncate(&app.grok_context, 1200)
    );

    let p = Paragraph::new(body)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(border)
                .title(" 🤖 Grok · split/full ")
                .style(Style::default().bg(Color::Rgb(28, 24, 18))),
        )
        .wrap(Wrap { trim: false });
    f.render_widget(Clear, area);
    f.render_widget(p, area);
}

fn draw_actions(f: &mut Frame, area: Rect, app: &App) {
    let mut spans = vec![Span::styled(
        " next: ",
        Style::default().fg(AMBER).add_modifier(Modifier::BOLD),
    )];
    for (i, a) in app.next_actions.iter().enumerate() {
        let selected = i == app.action_idx && app.focus == Focus::Actions;
        let label = format!("[{}] {}  ", a.key, a.label);
        let style = if selected {
            Style::default()
                .fg(Color::Black)
                .bg(AMBER)
                .add_modifier(Modifier::BOLD)
        } else {
            Style::default().fg(Color::White)
        };
        spans.push(Span::styled(label, style));
    }
    let border = if app.focus == Focus::Actions {
        Style::default().fg(AMBER)
    } else {
        Style::default().fg(DIM)
    };
    let p = Paragraph::new(Line::from(spans)).block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(border)
            .title(" take action / fix "),
    );
    f.render_widget(p, area);
}

fn draw_footer(f: &mut Frame, area: Rect, app: &App) {
    let focus = format!("{:?}", app.focus);
    let msg = format!(
        " {}  │  Tab focus ({focus})  │  g split Grok  │  G launch Grok  │  Esc home  │  {}",
        app.status,
        short_root(&app.root)
    );
    f.render_widget(
        Paragraph::new(msg).style(Style::default().fg(DIM)),
        area,
    );
}

fn draw_help(f: &mut Frame, area: Rect, _app: &App) {
    let text = "\
tinfoil-tui — main entry & loop controller\n\
\n\
You always stand on:  Home › Job › Output → Next actions\n\
Shell/Go do the work; this UI only steers and shows stdio cleanly.\n\
\n\
Keys\n\
  ↑↓ / j k     menu or scroll\n\
  Enter        run command\n\
  Tab          focus: menu → output → grok → actions\n\
  g            toggle Grok split dock\n\
  G            launch Grok fullscreen (suspend TUI)\n\
  Esc          back to Home\n\
  Ctrl+C       cancel running job (or quit if idle)\n\
  q            quit from Home\n\
  1–9          jump menu item\n\
\n\
Backends (no logic reimplemented here)\n\
  maintenance/inventory.sh\n\
  tinfoil audit | maintenance/security-audit.sh\n\
  install.sh --profile … --dry-run\n\
  maintenance/extract-evidence.sh\n\
\n\
After every job: use the amber action bar for the next fix step.\n\
Esc / Enter  →  Home";
    let p = Paragraph::new(text)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(CYAN))
                .title(" help "),
        )
        .wrap(Wrap { trim: false });
    f.render_widget(p, area);
}

fn truncate(s: &str, max: usize) -> String {
    if s.len() <= max {
        s.to_string()
    } else {
        format!("…{}", &s[s.len() - max..])
    }
}

fn short_root(p: &std::path::Path) -> String {
    let s = p.display().to_string();
    if s.len() > 48 {
        format!("…{}", &s[s.len() - 46..])
    } else {
        s
    }
}
