//! Sparse chrome: status-first header, primary next bar, brief co-pilot.
//! Long teaching text lives only on Help (`?`).

use crate::app::{App, Focus, GrokMode, Screen};
use crate::nav::JobState;
use crate::theme::Palette;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap};
use ratatui::Frame;

pub fn draw(f: &mut Frame, app: &App) {
    let p = app.palette();
    let area = f.area();
    f.render_widget(Clear, area);
    f.render_widget(
        Block::default().style(Style::default().bg(p.bg).fg(p.fg)),
        area,
    );

    let action_h = if app.next_actions.is_empty() {
        0
    } else {
        3 // one primary row + border
    };

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(6),
            Constraint::Length(action_h),
            Constraint::Length(1),
        ])
        .split(area);

    draw_header(f, chunks[0], app, p);

    match app.screen {
        Screen::Help => draw_help(f, chunks[1], app, p),
        Screen::Home | Screen::Output => draw_body(f, chunks[1], app, p),
    }

    if !app.next_actions.is_empty() {
        draw_actions(f, chunks[2], app, p);
    }
    draw_footer(f, chunks[3], app, p);
}

fn draw_header(f: &mut Frame, area: Rect, app: &App, p: Palette) {
    let crumb = app.breadcrumb.join(" › ");
    let state = JobState::from_runtime(app.job.is_some(), app.last_exit);
    let state_style = match state {
        JobState::Running => p.style_bold(p.amber),
        JobState::Ok => p.style_fg(p.sage),
        JobState::Fail => p.style_bold(p.warning),
        JobState::Idle => p.style_fg(p.fg_muted),
    };
    let copilot = match app.grok_mode {
        GrokMode::Hidden => "brief:off",
        GrokMode::Split => "brief:on",
        GrokMode::Full => "brief:full",
    };

    // One dense status line — no teaching prose.
    let title = Line::from(vec![
        Span::styled(" archy ", p.style_bold(p.sage)),
        Span::styled(crumb, p.style_fg(p.fg)),
        Span::raw("  "),
        Span::styled(state.label(), state_style),
        Span::raw("  "),
        Span::styled(copilot, p.style_fg(p.clay)),
        Span::raw("  "),
        Span::styled(app.phase.label(), p.style_fg(p.teal)),
        Span::raw("  "),
        Span::styled(app.theme.as_str(), p.style_fg(p.fg_muted)),
    ]);

    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(p.sage))
        .style(Style::default().bg(p.bg_panel))
        .title(Span::styled(" state ", p.style_fg(p.fg_muted)));
    f.render_widget(Paragraph::new(title).block(block), area);
}

fn draw_body(f: &mut Frame, area: Rect, app: &App, p: Palette) {
    match app.grok_mode {
        GrokMode::Hidden => draw_main_column(f, area, app, p),
        GrokMode::Split => {
            let cols = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([Constraint::Percentage(68), Constraint::Percentage(32)])
                .split(area);
            draw_main_column(f, cols[0], app, p);
            draw_grok_dock(f, cols[1], app, p);
        }
        GrokMode::Full => draw_grok_dock(f, area, app, p),
    }
}

fn draw_main_column(f: &mut Frame, area: Rect, app: &App, p: Palette) {
    // Height = all menu rows + top/bottom borders so items 9–12 are not clipped.
    // When the terminal is shorter, ListState keeps the selection in view.
    let menu_h = match app.screen {
        Screen::Home => Constraint::Length(menu_panel_height(App::menu_len())),
        Screen::Output => Constraint::Length(0),
        Screen::Help => Constraint::Min(1),
    };

    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([menu_h, Constraint::Min(3)])
        .split(area);

    if app.screen == Screen::Home {
        draw_menu(f, rows[0], app, p);
        draw_output(f, rows[1], app, p);
    } else {
        draw_output(f, area, app, p);
    }
}

/// Inner list rows + 2 for Borders::ALL. Pure so tests can lock the layout contract.
pub fn menu_panel_height(item_count: usize) -> u16 {
    (item_count as u16).saturating_add(2).max(3)
}

fn draw_menu(f: &mut Frame, area: Rect, app: &App, p: Palette) {
    let items: Vec<ListItem> = app
        .menu_items()
        .iter()
        .enumerate()
        .map(|(i, label)| {
            let selected = i == app.menu_idx && app.focus == Focus::Main;
            let prefix = if selected { "▸ " } else { "  " };
            let style = if selected {
                p.style_selected()
            } else {
                p.style_fg(p.fg)
            };
            ListItem::new(format!("{prefix}{}. {label}", i + 1)).style(style)
        })
        .collect();

    let list = List::new(items).block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(p.border_focus(app.focus == Focus::Main, p.sage))
            .title(Span::styled(" menu ", p.style_fg(p.fg_muted)))
            .style(p.panel()),
    );
    // Stateful list scrolls so selection (e.g. Quit #12) stays visible if height is tight.
    let mut state = ListState::default();
    state.select(Some(app.menu_idx));
    f.render_stateful_widget(list, area, &mut state);
}

/// Severity-aware line colors for eye-comfort light/dark (no neon ANSI dependency).
/// Prefers audit tags `[x]` fail, `[!]` warn, `[ok]` pass; SUMMARY block is amber.
pub fn style_stdio_line(line: &str, p: Palette) -> Style {
    let t = line.trim_start();
    if t.starts_with('▶') || t.starts_with('■') {
        return p.style_fg(p.amber);
    }
    if t.starts_with("[stderr]") {
        return p.style_fg(p.error_soft);
    }
    // Threat audit tags (security-audit.sh quiet format)
    if t.starts_with("[x]") || t.starts_with("x ") {
        return p.style_bold(p.error);
    }
    if t.starts_with("[!]") || t.starts_with("! ") {
        return p.style_bold(p.warning);
    }
    if t.starts_with("[ok]") {
        return p.style_fg(p.sage_lift);
    }
    if t.starts_with("[·]") {
        return p.style_fg(p.fg_muted);
    }
    // SUMMARY block *before* generic `## ` so the close-out stays highlighted.
    if t.starts_with("## SUMMARY")
        || t.starts_with("malware=")
        || t.starts_with("counts ")
        || t.starts_with("report=")
        || t.starts_with("next:")
    {
        return p.style_bold(p.amber);
    }
    // exit=N drives severity (not fail=0 inside counts — that matched clean runs as error).
    if let Some(rest) = t.strip_prefix("exit=") {
        let code: String = rest.chars().take_while(|c| c.is_ascii_digit()).collect();
        return match code.as_str() {
            "2" => p.style_bold(p.error),
            "1" => p.style_bold(p.warning),
            "0" => p.style_bold(p.sage_lift),
            _ => p.style_bold(p.amber),
        };
    }
    if t.starts_with("## ") {
        return p.style_fg(p.fg_muted);
    }
    if t.starts_with('✗')
        || t.contains(" ERROR")
        || t.contains("[ERROR]")
        || t.contains("error:")
    {
        return p.style_fg(p.error);
    }
    if t.starts_with('✓') || t.contains("success") {
        return p.style_fg(p.sage_lift);
    }
    // Strip legacy emoji-heavy progress as muted when present
    if t.contains("🚀") || t.contains("========") {
        return p.style_fg(p.fg_muted);
    }
    p.style_fg(p.fg)
}

fn draw_output(f: &mut Frame, area: Rect, app: &App, p: Palette) {
    let title = if app.job.is_some() {
        " stdio · live "
    } else {
        " stdio "
    };

    let height = area.height.saturating_sub(2) as usize;
    let total = app.lines.len();
    let scroll = app.scroll as usize;
    let start = if total > height {
        scroll
            .saturating_sub(height.saturating_sub(1))
            .min(total.saturating_sub(height))
    } else {
        0
    };
    let end = (start + height).min(total);
    let text: Vec<Line> = app.lines[start..end]
        .iter()
        .map(|l| Line::from(Span::styled(l.clone(), style_stdio_line(l, p))))
        .collect();

    let para = Paragraph::new(text)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(p.border_focus(app.focus == Focus::Output, p.teal))
                .title(Span::styled(title, p.style_fg(p.fg_muted)))
                .style(p.panel()),
        )
        .wrap(Wrap { trim: false });
    f.render_widget(para, area);
}

/// Sparse co-pilot: one purpose line, job, ask, keys — no multi-section essay.
fn draw_grok_dock(f: &mut Frame, area: Rect, app: &App, p: Palette) {
    let focused = app.focus == Focus::GrokDock;
    let last = app.last_kind.map(|k| k.label()).unwrap_or("—");
    let exit = app
        .last_exit
        .map(|c| c.to_string())
        .unwrap_or_else(|| if app.job.is_some() { "…".into() } else { "—".into() });

    let ask = app.suggested_grok_ask();
    let ask_short = if ask.len() > 56 {
        format!("{}…", &ask[..55])
    } else {
        ask
    };

    let mut lines = vec![
        Line::from(Span::styled(
            "brief · not chat",
            p.style_bold(p.amber),
        )),
        Line::from(Span::styled(
            format!("{last}  exit={exit}"),
            p.style_fg(p.fg),
        )),
        Line::from(Span::styled(
            format!("› {ask_short}"),
            p.style_fg(p.sage),
        )),
        Line::from(Span::styled(
            if focused {
                "Enter launch · g hide"
            } else {
                "Tab→brief · Enter launch · g hide"
            },
            p.style_fg(p.fg_muted),
        )),
    ];

    if focused {
        lines.push(Line::from(Span::styled(
            "▸ ENTER",
            Style::default()
                .fg(p.bg)
                .bg(p.amber)
                .add_modifier(Modifier::BOLD),
        )));
    }

    let title = if focused {
        " co-pilot "
    } else {
        " co-pilot "
    };

    let para = Paragraph::new(lines)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(p.border_focus(focused, p.amber))
                .title(Span::styled(title, p.style_fg(p.amber)))
                .style(Style::default().bg(p.bg_elevated).fg(p.fg)),
        )
        .wrap(Wrap { trim: false });
    f.render_widget(Clear, area);
    f.render_widget(para, area);
}

/// Primary next action dominates; secondaries are muted.
fn draw_actions(f: &mut Frame, area: Rect, app: &App, p: Palette) {
    let focused = app.focus == Focus::Actions;
    let mut spans: Vec<Span> = Vec::new();

    if let Some(primary) = crate::actions::primary(&app.next_actions) {
        let sel = app.action_idx == 0 && focused;
        let label = format!(" NEXT [{}] {} ", primary.key, primary.label);
        spans.push(Span::styled(
            label,
            if sel {
                p.style_primary_action()
            } else {
                Style::default()
                    .fg(p.bg)
                    .bg(p.amber)
                    .add_modifier(Modifier::BOLD)
            },
        ));
    }

    if app.next_actions.len() > 1 {
        spans.push(Span::styled("  ", p.style_fg(p.fg_muted)));
        for (i, a) in app.next_actions.iter().enumerate().skip(1) {
            let sel = i == app.action_idx && focused;
            let label = format!("[{}] {} ", a.key, a.label);
            spans.push(Span::styled(
                label,
                if sel {
                    p.style_action_selected()
                } else {
                    p.style_fg(p.fg_muted)
                },
            ));
        }
    }

    let para = Paragraph::new(Line::from(spans)).block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(p.border_focus(focused, p.amber))
            .title(Span::styled(" next ", p.style_fg(p.fg_muted)))
            .style(Style::default().bg(p.bg_panel)),
    );
    f.render_widget(para, area);
}

fn draw_footer(f: &mut Frame, area: Rect, app: &App, p: Palette) {
    let msg = crate::nav::footer_status(&app.status, app.focus, app.theme.as_str());
    f.render_widget(
        Paragraph::new(msg).style(Style::default().fg(p.fg_muted).bg(p.bg)),
        area,
    );
}

fn draw_help(f: &mut Frame, area: Rect, app: &App, p: Palette) {
    // Long form only here — not in default chrome.
    let text = vec![
        Line::from(Span::styled(
            "archy — entry + loop (shell backends do the work)",
            p.style_bold(p.sage),
        )),
        Line::from(""),
        Line::from(Span::styled("Flow", p.style_bold(p.amber))),
        Line::from(Span::styled(
            "  Home → run job → stdio → NEXT bar (primary first)",
            p.style_fg(p.fg),
        )),
        Line::from(""),
        Line::from(Span::styled("Keys", p.style_bold(p.amber))),
        Line::from(Span::styled(
            "  ↑↓/jk  menu or scroll   Enter  run / launch Grok in brief",
            p.style_fg(p.fg),
        )),
        Line::from(Span::styled(
            "  Tab    menu → stdio → brief → next",
            p.style_fg(p.fg),
        )),
        Line::from(Span::styled(
            "  g      toggle co-pilot brief (not a chat)",
            p.style_fg(p.fg),
        )),
        Line::from(Span::styled(
            "  G / p  launch Grok (suspend TUI; context file written)",
            p.style_fg(p.fg),
        )),
        Line::from(Span::styled(
            "  Esc    Home    Ctrl+C cancel/quit    q quit    ? help",
            p.style_fg(p.fg),
        )),
        Line::from(""),
        Line::from(Span::styled("Theme", p.style_bold(p.amber))),
        Line::from(Span::styled(
            format!("  mode={}  order:", app.theme.as_str()),
            p.style_fg(p.fg),
        )),
        Line::from(Span::styled(
            "  1 ARCHY_THEME  2 colors.toml bg  3 theme.name  4 COLORFGBG  5 dark",
            p.style_fg(p.fg),
        )),
        Line::from(Span::styled(
            "  Ratatui cannot auto-sync full OS chrome; light/dark only at startup.",
            p.style_fg(p.fg_muted),
        )),
        Line::from(Span::styled(
            "  eye-comfort night/midday locks; no live phase hot-reload.",
            p.style_fg(p.fg_muted),
        )),
        Line::from(""),
        Line::from(Span::styled(
            "Audit exit: 0 clean · 1 warn · 2 fail (malware/ports/config)",
            p.style_fg(p.fg_muted),
        )),
        Line::from(Span::styled("Esc / Enter → Home", p.style_fg(p.clay))),
    ];
    let para = Paragraph::new(text)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(p.teal))
                .title(Span::styled(" help ", p.style_fg(p.fg_muted)))
                .style(p.panel()),
        )
        .wrap(Wrap { trim: false });
    f.render_widget(para, area);
}

#[cfg(test)]
mod tests {
    use super::{menu_panel_height, style_stdio_line};
    use crate::app::App;
    use crate::theme::{self, ThemeMode};
    use ratatui::style::Color;

    #[test]
    fn stdio_styles_distinguish_audit_severity_on_light_and_dark() {
        for mode in [ThemeMode::Light, ThemeMode::Dark] {
            let p = theme::palette(mode);
            let fail = style_stdio_line("[x] malware rkhunter hit", p);
            let warn = style_stdio_line("[!] ports public high ports", p);
            let ok = style_stdio_line("[ok] malware clean", p);
            let muted = style_stdio_line("## ports", p);
            let plain = style_stdio_line("listen 127.0.0.1:22", p);
            // Distinct tokens: fail/warn not same as plain fg
            assert_ne!(fail.fg, plain.fg, "fail should differ from plain ({mode:?})");
            assert_ne!(warn.fg, plain.fg, "warn should differ from plain ({mode:?})");
            assert_ne!(ok.fg, Some(Color::Reset));
            assert_eq!(muted.fg, Some(p.fg_muted));
            // Fail uses error token
            assert_eq!(fail.fg, Some(p.error));
            assert_eq!(warn.fg, Some(p.warning));
            assert_eq!(ok.fg, Some(p.sage_lift));

            // SUMMARY highlight order: ## SUMMARY is amber, not muted generic ##
            let summary = style_stdio_line("## SUMMARY", p);
            assert_eq!(
                summary.fg,
                Some(p.amber),
                "## SUMMARY must be amber before generic ## mute ({mode:?})"
            );
            let section = style_stdio_line("## malware", p);
            assert_eq!(section.fg, Some(p.fg_muted));

            // counts with fail=0 must NOT be styled as error (false alarm on clean/warn)
            let counts_clean = style_stdio_line("counts ok=2 warn=0 fail=0 skip=4", p);
            assert_eq!(
                counts_clean.fg,
                Some(p.amber),
                "fail=0 must not force error color ({mode:?})"
            );
            let counts_warn = style_stdio_line("counts ok=2 warn=4 fail=0 skip=1", p);
            assert_eq!(counts_warn.fg, Some(p.amber));

            // exit= drives severity
            assert_eq!(style_stdio_line("exit=0  (0=clean 1=warn 2=fail)", p).fg, Some(p.sage_lift));
            assert_eq!(style_stdio_line("exit=1  (0=clean 1=warn 2=fail)", p).fg, Some(p.warning));
            assert_eq!(style_stdio_line("exit=2  (0=clean 1=warn 2=fail)", p).fg, Some(p.error));
        }
    }

    #[test]
    fn menu_height_fits_all_shipped_items_plus_borders() {
        let n = App::menu_len();
        assert!(n >= 12, "expected full Home menu, got {n}");
        let h = menu_panel_height(n);
        // items + top/bottom Borders::ALL
        assert_eq!(h, (n as u16) + 2);
        let content_rows = h.saturating_sub(2);
        assert!(
            content_rows >= n as u16,
            "content_rows={content_rows} must fit all {n} items (incl. Co-pilot…Quit)"
        );
        // Item indices 8–11 (9–12) must have a row in the content band.
        assert!(content_rows > 11, "last item index 11 must be in range");
    }

    #[test]
    fn menu_height_min_floor() {
        assert_eq!(menu_panel_height(0), 3);
        assert_eq!(menu_panel_height(1), 3);
    }
}
