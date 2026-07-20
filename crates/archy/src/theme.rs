//! Eye-comfort dual palettes (night + midday) for archy.
//!
//! Ratatui cannot inherit a full OS “system theme.” We best-effort detect
//! light vs dark at startup from (in order):
//! 1. `ARCHY_THEME=light|dark`
//! 2. Omarchy `colors.toml` background luminance (`#RRGGBB`)
//! 3. Omarchy/eye-comfort `theme.name` heuristics
//! 4. `COLORFGBG` (terminal bg index)
//! 5. default **dark**
//!
//! Live hot-reload of every host template is out of scope.

use ratatui::style::{Color, Modifier, Style};

const fn hex(rgb: u32) -> Color {
    Color::Rgb(
        ((rgb >> 16) & 0xff) as u8,
        ((rgb >> 8) & 0xff) as u8,
        (rgb & 0xff) as u8,
    )
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ThemeMode {
    Light,
    Dark,
}

impl ThemeMode {
    pub fn as_str(self) -> &'static str {
        match self {
            ThemeMode::Light => "light",
            ThemeMode::Dark => "dark",
        }
    }
}

/// Resolved color tokens for one mode (restrained product palette).
#[derive(Debug, Clone, Copy)]
pub struct Palette {
    pub bg: Color,
    pub bg_panel: Color,
    pub bg_elevated: Color,
    pub fg: Color,
    pub fg_muted: Color,
    pub sage: Color,
    pub sage_lift: Color,
    pub amber: Color,
    pub warning: Color,
    pub clay: Color,
    pub teal: Color,
    pub error: Color,
    pub error_soft: Color,
}

/// Night locks — `eye-comfort-dark` / DESIGN.md dark-*.
pub const DARK: Palette = Palette {
    bg: hex(0x18_16_14),
    bg_panel: hex(0x1F_1C_19),
    bg_elevated: hex(0x2F_29_24),
    fg: hex(0xE6_DF_D3),
    fg_muted: hex(0x8A_82_78),
    sage: hex(0x7D_9A_8C),
    sage_lift: hex(0x89_A7_92),
    amber: hex(0xC9_A6_6B),
    warning: hex(0xD4_A0_5A),
    clay: hex(0xA8_8B_6E),
    teal: hex(0x70_8C_8F),
    error: hex(0xC4_70_64),
    error_soft: hex(0xD6_7B_6F),
};

/// Midday locks — `eye-comfort-light` / DESIGN.md light-*.
pub const LIGHT: Palette = Palette {
    bg: hex(0xF5_F0_E8),
    bg_panel: hex(0xEB_E4_D8),
    bg_elevated: hex(0xE0_D9_CE),
    fg: hex(0x2A_26_22),
    fg_muted: hex(0x6E_66_5C),
    sage: hex(0x4A_6B_5C),
    sage_lift: hex(0x3D_5C_4E),
    amber: hex(0x8A_60_30),
    warning: hex(0x8B_60_20),
    clay: hex(0x8B_6B_4E),
    teal: hex(0x4A_6A_6E),
    error: hex(0xB5_4A_40),
    error_soft: hex(0xC4_5A_50),
};

pub fn palette(mode: ThemeMode) -> Palette {
    match mode {
        ThemeMode::Light => LIGHT,
        ThemeMode::Dark => DARK,
    }
}

/// Pure theme resolution for tests and startup.
///
/// Inputs are pre-read strings so unit tests need no filesystem.
/// `bg_hex` is optional `#RRGGBB` from Omarchy `colors.toml` (most accurate).
pub fn resolve_theme_mode(
    archy_theme_env: Option<&str>,
    colorfgbg: Option<&str>,
    omarchy_theme_name: Option<&str>,
    bg_hex: Option<&str>,
) -> ThemeMode {
    if let Some(raw) = archy_theme_env {
        let t = raw.trim().to_ascii_lowercase();
        if t == "light" || t == "day" || t == "midday" {
            return ThemeMode::Light;
        }
        if t == "dark" || t == "night" || t == "dusk" {
            return ThemeMode::Dark;
        }
    }

    // Background luminance from active theme package beats name heuristics.
    if let Some(hex) = bg_hex {
        if let Some(m) = mode_from_bg_hex(hex) {
            return m;
        }
    }

    if let Some(name) = omarchy_theme_name {
        if let Some(m) = mode_from_theme_name(name) {
            return m;
        }
    }

    if let Some(cfg) = colorfgbg {
        if let Some(m) = mode_from_colorfgbg(cfg) {
            return m;
        }
    }

    ThemeMode::Dark
}

/// Relative luminance of `#RRGGBB` → light if bright paper, dark if umber.
pub fn mode_from_bg_hex(hex: &str) -> Option<ThemeMode> {
    let h = hex.trim().trim_start_matches('#');
    if h.len() != 6 {
        return None;
    }
    let r = u8::from_str_radix(&h[0..2], 16).ok()? as f32;
    let g = u8::from_str_radix(&h[2..4], 16).ok()? as f32;
    let b = u8::from_str_radix(&h[4..6], 16).ok()? as f32;
    // Rec. 709 relative luminance
    let y = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
    if y >= 0.45 {
        Some(ThemeMode::Light)
    } else {
        Some(ThemeMode::Dark)
    }
}

/// Map Omarchy / eye-comfort package names → light|dark.
pub fn mode_from_theme_name(name: &str) -> Option<ThemeMode> {
    let n = name.trim().to_ascii_lowercase();
    if n.is_empty() {
        return None;
    }
    // Light family + TN paper packages (marutham/neythal/palai are dawn paper)
    if n.contains("light")
        || n.contains("dawn")
        || n.contains("morning")
        || n.contains("midday")
        || n.contains("marutham")
        || n.contains("neythal")
        || n.contains("palai")
    {
        return Some(ThemeMode::Light);
    }
    // Dark family (dusk/evening/night + TN deep packages)
    if n.contains("dark")
        || n.contains("dusk")
        || n.contains("evening")
        || n.contains("night")
        || n.contains("lantern")
        || n.contains("kurinji")
        || n.contains("mullai")
    {
        return Some(ThemeMode::Dark);
    }
    None
}

/// COLORFGBG is `fg;bg` where bg 0–7 ≈ dark terminal, 8–15 ≈ light.
pub fn mode_from_colorfgbg(s: &str) -> Option<ThemeMode> {
    let bg = s.trim().split(';').nth(1)?.trim().parse::<u8>().ok()?;
    if bg >= 8 {
        Some(ThemeMode::Light)
    } else {
        Some(ThemeMode::Dark)
    }
}

/// Read host hints and resolve mode (startup only).
pub fn detect_theme_mode() -> ThemeMode {
    let archy = std::env::var("ARCHY_THEME").ok();
    let colorfgbg = std::env::var("COLORFGBG").ok();
    let omarchy = read_omarchy_theme_name();
    let bg = read_omarchy_bg_hex();
    resolve_theme_mode(
        archy.as_deref(),
        colorfgbg.as_deref(),
        omarchy.as_deref(),
        bg.as_deref(),
    )
}

fn read_omarchy_theme_name() -> Option<String> {
    let home = std::env::var_os("HOME")?;
    let path = std::path::Path::new(&home).join(".config/omarchy/current/theme.name");
    let raw = std::fs::read_to_string(path).ok()?;
    let name = raw.lines().next()?.trim().to_string();
    if name.is_empty() {
        None
    } else {
        Some(name)
    }
}

/// Parse `background = "#RRGGBB"` from Omarchy current theme colors.toml.
fn read_omarchy_bg_hex() -> Option<String> {
    let home = std::env::var_os("HOME")?;
    let path = std::path::Path::new(&home).join(".config/omarchy/current/theme/colors.toml");
    let raw = std::fs::read_to_string(path).ok()?;
    for line in raw.lines() {
        let line = line.trim();
        if let Some(rest) = line.strip_prefix("background") {
            let rest = rest.trim().trim_start_matches('=').trim();
            let hex = rest.trim_matches('"').trim_matches('\'').trim();
            if hex.starts_with('#') && hex.len() == 7 {
                return Some(hex.to_string());
            }
        }
    }
    None
}

impl Palette {
    pub fn style_fg(self, c: Color) -> Style {
        Style::default().fg(c)
    }

    pub fn style_bold(self, c: Color) -> Style {
        Style::default().fg(c).add_modifier(Modifier::BOLD)
    }

    pub fn style_selected(self) -> Style {
        Style::default()
            .fg(self.bg)
            .bg(self.sage)
            .add_modifier(Modifier::BOLD)
    }

    pub fn style_primary_action(self) -> Style {
        Style::default()
            .fg(self.bg)
            .bg(self.amber)
            .add_modifier(Modifier::BOLD)
    }

    pub fn style_action_selected(self) -> Style {
        Style::default()
            .fg(self.bg)
            .bg(self.clay)
            .add_modifier(Modifier::BOLD)
    }

    pub fn border_focus(self, active: bool, accent: Color) -> Style {
        if active {
            Style::default().fg(accent)
        } else {
            Style::default().fg(self.fg_muted)
        }
    }

    pub fn panel(self) -> Style {
        Style::default().bg(self.bg_panel).fg(self.fg)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn archy_theme_env_wins() {
        assert_eq!(
            resolve_theme_mode(Some("light"), Some("15;0"), Some("eye-comfort-dark"), None),
            ThemeMode::Light
        );
        assert_eq!(
            resolve_theme_mode(Some("dark"), Some("0;15"), Some("eye-comfort-light"), None),
            ThemeMode::Dark
        );
    }

    #[test]
    fn bg_hex_beats_name() {
        // Dark name but light paper bg → light
        assert_eq!(
            resolve_theme_mode(None, None, Some("eye-comfort-dark"), Some("#F5F0E8")),
            ThemeMode::Light
        );
        assert_eq!(
            resolve_theme_mode(None, None, Some("eye-comfort-light"), Some("#181614")),
            ThemeMode::Dark
        );
    }

    #[test]
    fn omarchy_name_before_colorfgbg() {
        assert_eq!(
            resolve_theme_mode(None, Some("15;0"), Some("eye-comfort-light"), None),
            ThemeMode::Light
        );
        assert_eq!(
            resolve_theme_mode(None, Some("0;15"), Some("eye-comfort-dark"), None),
            ThemeMode::Dark
        );
        assert_eq!(
            resolve_theme_mode(None, None, Some("eye-comfort-dawn"), None),
            ThemeMode::Light
        );
        assert_eq!(
            resolve_theme_mode(None, None, Some("eye-comfort-dusk"), None),
            ThemeMode::Dark
        );
        assert_eq!(
            resolve_theme_mode(None, None, Some("eye-comfort-tn-marutham"), None),
            ThemeMode::Light
        );
        assert_eq!(
            resolve_theme_mode(None, None, Some("eye-comfort-tn-kurinji"), None),
            ThemeMode::Dark
        );
    }

    #[test]
    fn colorfgbg_bg_index() {
        assert_eq!(mode_from_colorfgbg("15;0"), Some(ThemeMode::Dark));
        assert_eq!(mode_from_colorfgbg("0;15"), Some(ThemeMode::Light));
        assert_eq!(mode_from_colorfgbg("7;8"), Some(ThemeMode::Light));
    }

    #[test]
    fn bg_hex_luminance() {
        assert_eq!(mode_from_bg_hex("#F9E7DA"), Some(ThemeMode::Light)); // marutham
        assert_eq!(mode_from_bg_hex("#181614"), Some(ThemeMode::Dark));
        assert_eq!(mode_from_bg_hex("#1A1612"), Some(ThemeMode::Dark)); // kurinji
    }

    #[test]
    fn default_dark_when_no_hints() {
        assert_eq!(resolve_theme_mode(None, None, None, None), ThemeMode::Dark);
    }

    #[test]
    fn dual_palettes_differ() {
        assert_ne!(format!("{:?}", DARK.bg), format!("{:?}", LIGHT.bg));
        assert_ne!(format!("{:?}", DARK.fg), format!("{:?}", LIGHT.fg));
    }
}
