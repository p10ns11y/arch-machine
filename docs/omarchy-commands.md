# Omarchy command reference

Full CLI surface for [Omarchy](https://omarchy.org) (DHH’s Arch + Hyprland stack).  
**Host source of truth:** `~/.local/share/omarchy/bin/omarchy-*` (or `$OMARCHY_PATH/bin`).

arch-machine does **not** reimplement these. Use them as backends when present:

| arch-machine flow | Prefer Omarchy command | Notes |
|-------------------|------------------------|--------|
| Package add (taste) | `omarchy pkg add …` | After catalog/search consent |
| Package drop | `omarchy pkg drop …` | Never for refuse-list critical pkgs |
| Fuzzy install TUI | `omarchy pkg install` | Interactive; not for agents |
| Presence probe | `omarchy pkg present …` | Exit 0 = all installed |
| System update | `omarchy update` / `omarchy update available` | Full Omarchy pipeline |
| Theme apply | `omarchy theme set …` | eye-comfort packages too |
| Theme list/current | `omarchy theme list` / `current` | Read-only status |
| Desktop menu | `omarchy menu` | Walker-powered; desktop only |
| Status snapshot | `tinfoil omarchy` → `maintenance/omarchy-status.sh` | Read-only bundle |

Day-1 playbook: [omarchy.md](./omarchy.md).  
Eye-comfort themes: [eye-comfort.md](./eye-comfort.md).  
Baselines used by inventory ownership: `config/baselines/omarchy.yaml`.

---

| Command | Binary | Summary |
| --- | --- | --- |
| `omarchy ac present` | `omarchy-ac-present` | Returns true if AC power is connected. |
| `omarchy audio input mute` | `omarchy-audio-input-mute` | Toggle microphone mute. Drives the hardware mic-mute LED on laptops that expose one. |
| `omarchy audio output switch` | `omarchy-audio-output-switch` | Switch between audio outputs while preserving the mute status. By default mapped to Super + Mute. |
| `omarchy battery capacity` | `omarchy-battery-capacity` | Returns the battery full capacity in Wh (rounded to whole number). |
| `omarchy battery present` | `omarchy-battery-present` | Returns true if a battery is present on the system. |
| `omarchy battery remaining` | `omarchy-battery-remaining` | Returns the battery percentage remaining as an integer. |
| `omarchy battery remaining time` | `omarchy-battery-remaining-time` | Returns the battery time remaining (to empty or full) in a compact format. |
| `omarchy battery status` | `omarchy-battery-status` | Returns a formatted battery status string with percentage and power draw/charge. |
| `omarchy branch set <master\|rc\|dev>` | `omarchy-branch-set` | Set the branch for Omarchy's git repository. |
| `omarchy branding about <image\|text\|reset>` | `omarchy-branding-about` | Edit, set, or reset About branding |
| `omarchy branding screensaver <image\|text\|reset>` | `omarchy-branding-screensaver` | Edit, set, or reset screensaver branding |
| `omarchy brightness display apple <+N%\|N%-\|N%>` | `omarchy-brightness-display-apple` | Adjust the brightness on Apple Studio Displays and Apple XDR Displays using asdcontrol. |
| `omarchy brightness display <+N%\|N%-\|N%\|off\|on>` | `omarchy-brightness-display` | Adjust brightness on the most likely display device. |
| `omarchy brightness keyboard mute <on\|off>` | `omarchy-brightness-keyboard-mute` | Set the mic-mute indicator LED on laptops that expose a platform::micmute LED node. |
| `omarchy brightness keyboard <up\|down\|cycle\|off\|restore>` | `omarchy-brightness-keyboard` | Adjust keyboard backlight brightness using available steps. |
| `omarchy capture screenrecording [--with-desktop-audio] [--with-microphone-audio] [--with-webcam] [--webcam-device=<device>] [--resolution=<size>] [--stop-recording]` | `omarchy-capture-screenrecording` | Start or stop screen recording |
| `omarchy capture screenshot [smart\|region\|windows\|fullscreen] [slurp\|copy\|save] [--editor=<name>]` | `omarchy-capture-screenshot` | Take a screenshot |
| `omarchy capture text extraction` | `omarchy-capture-text-extraction` | Extract text from a screenshot region with OCR |
| `omarchy channel set <stable\|rc\|edge\|dev>` | `omarchy-channel-set` | Set the Omarchy channel, which dictates what git branch and package repository is used. |
| `omarchy cmd missing` | `omarchy-cmd-missing` | Check whether any required commands are missing |
| `omarchy cmd present` | `omarchy-cmd-present` | Check whether all required commands are available |
| `omarchy config direct boot` | `omarchy-config-direct-boot` | Add or remove an EFI boot entry for the Omarchy UKI, allowing the system to boot directly |
| `omarchy debug [--no-sudo] [--print]` | `omarchy-debug` | Print debugging information |
| `omarchy default browser [chromium\|chrome\|brave\|brave-origin\|edge\|firefox\|zen]` | `omarchy-default-browser` | Set the default browser for Omarchy and XDG handlers |
| `omarchy default editor [code\|cursor\|zed\|sublime_text\|helix\|vim\|emacs\|nvim]` | `omarchy-default-editor` | Set the default editor for $EDITOR |
| `omarchy default terminal [alacritty\|foot\|ghostty\|kitty]` | `omarchy-default-terminal` | Set the default terminal used by xdg-terminal-exec |
| `omarchy dev add migration` | `omarchy-dev-add-migration` | Creates a new Omarchy migration named after the unix timestamp of the last commit. |
| `omarchy dev benchmark [--repeat=<count>]` | `omarchy-dev-benchmark` | Measure Omarchy CLI response times |
| `omarchy dev bin metadata [--json]` | `omarchy-dev-bin-metadata` | Show Omarchy bin metadata fields and defaults |
| `omarchy drive info <drive>` | `omarchy-drive-info` | Print drive information such as size, model, and mount details |
| `omarchy drive password` | `omarchy-drive-password` | Set a new encryption password for a drive selected. |
| `omarchy drive select` | `omarchy-drive-select` | Select a drive from a list with info that includes space and brand. Used by omarchy-drive-password. |
| `omarchy first run` | `omarchy-first-run` | Finish the installation of Omarchy with items that can only be done after logging in. |
| `omarchy font current` | `omarchy-font-current` | Show current monospace font |
| `omarchy font list` | `omarchy-font-list` | List available monospace fonts |
| `omarchy font set <font-name>` | `omarchy-font-set` | Set the system monospace font |
| `omarchy hibernation available` | `omarchy-hibernation-available` | Check if hibernation is supported |
| `omarchy hibernation remove` | `omarchy-hibernation-remove` | Remove hibernation setup including swap and boot resume settings |
| `omarchy hibernation setup [--force] [--no-rebuild]` | `omarchy-hibernation-setup` | Set up hibernation with swap and boot resume configuration |
| `omarchy hook install <type> <file>` | `omarchy-hook-install` | Install a hook into ~/.config/omarchy/hooks/<type>.d/ |
| `omarchy hook [name] [args...]` | `omarchy-hook` | Run a named hook from ~/.config/omarchy/hooks/<name> and ~/.config/omarchy/hooks/<name>.d/. |
| `omarchy hw asus expertbook b9406` | `omarchy-hw-asus-expertbook-b9406` | Detect ASUS ExpertBook B9406 series laptops on Intel Panther Lake. |
| `omarchy hw asus rog` | `omarchy-hw-asus-rog` | Detect whether the computer is an Asus ROG machine. |
| `omarchy hw asus zenbook ux5406aa` | `omarchy-hw-asus-zenbook-ux5406aa` | Detect ASUS Zenbook UX5406AA series laptops on Intel Panther Lake. |
| `omarchy hw dell xps haptic touchpad` | `omarchy-hw-dell-xps-haptic-touchpad` | Match Dell XPS systems with the Synaptics haptic touchpad. |
| `omarchy hw dell xps oled` | `omarchy-hw-dell-xps-oled` | Match Dell XPS systems with LG OLED panel on Intel Panther Lake (Xe3) GPU. |
| `omarchy hw external monitors` | `omarchy-hw-external-monitors` | Returns true when an external monitor is physically connected. |
| `omarchy hw framework16` | `omarchy-hw-framework16` | Detect whether the computer is a Framework Laptop 16. |
| `omarchy hw hybrid gpu` | `omarchy-hw-hybrid-gpu` | Detect whether the system has an active hybrid GPU configuration |
| `omarchy hw intel` | `omarchy-hw-intel` | Detect whether the computer has an Intel CPU. |
| `omarchy hw intel ptl` | `omarchy-hw-intel-ptl` | Detect whether the computer has an Intel Panther Lake GPU. |
| `omarchy hw intel sof` | `omarchy-hw-intel-sof` | Detect whether the computer has an Intel SOF-capable audio DSP. |
| `omarchy hw match <pattern>` | `omarchy-hw-match` | Match against the computer's DMI product name or product family (case-insensitive). |
| `omarchy hw nvidia gsp` | `omarchy-hw-nvidia-gsp` | Detect whether the computer has an NVIDIA GPU with GSP firmware (Turing or newer). |
| `omarchy hw nvidia without gsp` | `omarchy-hw-nvidia-without-gsp` | Detect whether the computer has an NVIDIA GPU without GSP firmware (Maxwell/Pascal/Volta). |
| `omarchy hw recover internal monitor` | `omarchy-hw-recover-internal-monitor` | Clear the internal-monitor-disable toggle if no external display is connected. |
| `omarchy hw surface` | `omarchy-hw-surface` | Detect whether the computer is a Microsoft Surface device. |
| `omarchy hw touchpad` | `omarchy-hw-touchpad` | Print the detected Hyprland touchpad or trackpad device name |
| `omarchy hw touchscreen` | `omarchy-hw-touchscreen` | Print the detected Hyprland touchscreen or tablet device name |
| `omarchy hw vulkan` | `omarchy-hw-vulkan` | Detect whether Vulkan is available. |
| `omarchy hyprland monitor focused apple` | `omarchy-hyprland-monitor-focused-apple` | Return success if the focused Hyprland monitor is an Apple display. |
| `omarchy hyprland monitor focused` | `omarchy-hyprland-monitor-focused` | Print the name of the currently focused Hyprland monitor. |
| `omarchy hyprland monitor internal mirror <on\|off\|toggle\|recover>` | `omarchy-hyprland-monitor-internal-mirror` | Enable, disable, toggle, or recover mirroring the internal display to an external monitor |
| `omarchy hyprland monitor internal <on\|off\|toggle\|recover>` | `omarchy-hyprland-monitor-internal` | Enable, disable, toggle, or recover the internal laptop display |
| `omarchy hyprland monitor scaling cycle` | `omarchy-hyprland-monitor-scaling-cycle` | Cycle focused Hyprland monitor scaling through 1x, 1.25x, 1.6x, 2x, 3x, and 4x |
| `omarchy hyprland monitor watch` | `omarchy-hyprland-monitor-watch` | Watch Hyprland monitor events and recover monitor toggles when a monitor is removed |
| `omarchy hyprland toggle disabled <flag-name>` | `omarchy-hyprland-toggle-disabled` | Check if a Hyprland toggle is currently disabled (missing). |
| `omarchy hyprland toggle enabled <flag-name>` | `omarchy-hyprland-toggle-enabled` | Check if a Hyprland toggle is currently enabled. |
| `omarchy hyprland toggle [--enabled-notification <text>] [--disabled-notification <text>] <flag-name>` | `omarchy-hyprland-toggle` | Toggle permanent Hyprland flags by copying them into a directory that's sourced entirely. |
| `omarchy hyprland window close all` | `omarchy-hyprland-window-close-all` | Close all open windows |
| `omarchy hyprland window gaps toggle` | `omarchy-hyprland-window-gaps-toggle` | Toggles the window gaps globally between no gaps and the default. |
| `omarchy hyprland window pop [width height x y]` | `omarchy-hyprland-window-pop` | Toggle to pop-out a tile to stay fixed on a display basis. |
| `omarchy hyprland window single square aspect toggle` | `omarchy-hyprland-window-single-square-aspect-toggle` | Toggle single-window square aspect ratio. |
| `omarchy hyprland window transparency toggle` | `omarchy-hyprland-window-transparency-toggle` | Toggles transparency for the currently focused window. |
| `omarchy hyprland workspace layout toggle` | `omarchy-hyprland-workspace-layout-toggle` | Toggle the layout on the current active workspace between dwindle and scrolling |
| `omarchy install browser <chrome\|brave\|brave-origin\|edge\|firefox\|zen>` | `omarchy-install-browser` | Install a supported browser |
| `omarchy install chromium google account` | `omarchy-install-chromium-google-account` | Allow Chromium to sign in to Google accounts by adding the required OAuth credentials |
| `omarchy install dev-env <ruby\|node\|bun\|deno\|go\|laravel\|symfony\|php\|python\|elixir\|phoenix\|rust\|java\|zig\|ocaml\|dotnet\|clojure\|scala>` | `omarchy-install-dev-env` | Install a supported development environment |
| `omarchy install docker dbs` | `omarchy-install-docker-dbs` | Install one of the supported databases in a Docker container with the suitable development options. |
| `omarchy install dropbox` | `omarchy-install-dropbox` | Install and start the Dropbox service. Must then be authenticated via the web. |
| `omarchy install gaming geforce now` | `omarchy-install-gaming-geforce-now` | Install and launch Geforce Now. |
| `omarchy install gaming gpu lib32` | `omarchy-install-gaming-gpu-lib32` | Install lib32 graphics drivers (Vulkan + NVIDIA) for any detected GPUs. |
| `omarchy install gaming heroic` | `omarchy-install-gaming-heroic` | Install Heroic Games Launcher (Epic, GOG, Amazon Prime Gaming) with graphics drivers. |
| `omarchy install gaming lutris` | `omarchy-install-gaming-lutris` | Install Lutris with Wine + DXVK for running Windows games (Battle.net, EA, Ubisoft Connect, etc.) |
| `omarchy install gaming moonlight` | `omarchy-install-gaming-moonlight` | Install Moonlight (NVIDIA GameStream / Sunshine client) for streaming games to this PC. |
| `omarchy install gaming retroarch` | `omarchy-install-gaming-retroarch` | Install RetroArch with the full libretro core set plus FBNeo and a ~/Games ROM directory. |
| `omarchy install gaming steam` | `omarchy-install-gaming-steam` | Install Steam and graphics drivers selected for this system |
| `omarchy install gaming xbox cloud` | `omarchy-install-gaming-xbox-cloud` | Install Xbox Cloud Gaming as a web app and launch it. |
| `omarchy install gaming xbox controllers` | `omarchy-install-gaming-xbox-controllers` | Install support for using Xbox controllers with Steam/RetroArch/etc. |
| `omarchy install helix` | `omarchy-install-helix` | Install Helix and configure it to use the current Omarchy theme |
| `omarchy install nordvpn` | `omarchy-install-nordvpn` | Install the NordVPN service with optional GUI. |
| `omarchy install once` | `omarchy-install-once` | Install the ONCE service, enable its background service, and launch the TUI. |
| `omarchy install tailscale` | `omarchy-install-tailscale` | Install the Tailscale mesh VPN service and a web app for the Tailscale Admin Console. |
| `omarchy install terminal <alacritty\|foot\|ghostty\|kitty>` | `omarchy-install-terminal` | Install one of the approved terminals and set it as the default for Omarchy (Super + Return etc). |
| `omarchy install vscode` | `omarchy-install-vscode` | Install VS Code and configure Omarchy defaults for secrets, updates, and theme |
| `omarchy install zed` | `omarchy-install-zed` | Install Zed Editor and configure it with the current Omarchy theme |
| `omarchy launch about` | `omarchy-launch-about` | Launch the fastfetch TUI that gives information about the current system. |
| `omarchy launch audio` | `omarchy-launch-audio` | Launch the Omarchy audio controls TUI (provided by wiremix). |
| `omarchy launch bluetooth` | `omarchy-launch-bluetooth` | Launch the Omarchy bluetooth controls TUI (provided by bluetui). |
| `omarchy launch browser [url]` | `omarchy-launch-browser` | Launch the default browser as determined by xdg-settings. |
| `omarchy launch editor <path>` | `omarchy-launch-editor` | Launch the default editor as determined by $EDITOR (set via ~/.config/uwsm/default) (or nvim if missing). |
| `omarchy launch floating terminal with presentation <command>` | `omarchy-launch-floating-terminal-with-presentation` | Launch a floating terminal with the Omarchy presentation wrapper |
| `omarchy launch or focus <window-pattern> <launch-command>` | `omarchy-launch-or-focus` | Launch an app or focus an existing window matching a pattern |
| `omarchy launch or focus tui <command> [args...]` | `omarchy-launch-or-focus-tui` | Launch a TUI or focus an existing terminal window for it |
| `omarchy launch or focus webapp <window-pattern> <url-and-flags...>` | `omarchy-launch-or-focus-webapp` | Launch or focus on a given web app identified by the window-pattern. |
| `omarchy launch screensaver` | `omarchy-launch-screensaver` | Launch the Omarchy screensaver in the default terminal on the system with the correct font configuration. |
| `omarchy launch tui <command> [args...]` | `omarchy-launch-tui` | Launch a TUI command in the default terminal with Omarchy styling |
| `omarchy launch walker` | `omarchy-launch-walker` | Launch Walker and ensure its Elephant data provider is running |
| `omarchy launch webapp <url>` | `omarchy-launch-webapp` | Launch a URL as a web app in the default supported browser |
| `omarchy launch wifi` | `omarchy-launch-wifi` | Launch the Omarchy wifi controls (provided by the Impala TUI). |
| `omarchy menu file label paths formats [walker args...]` | `omarchy-menu-file` | Pick a file with Walker |
| `omarchy menu input prompt [walker args...]` | `omarchy-menu-input` | Prompt for text input with Walker |
| `omarchy menu keybindings` | `omarchy-menu-keybindings` | Display Hyprland keybindings defined in your configuration using walker for an interactive search menu. |
| `omarchy menu` | `omarchy-menu` | Launch the Omarchy Menu or takes a parameter to jump straight to a submenu. |
| `omarchy menu select prompt option... [-- walker args...]` | `omarchy-menu-select` | Pick one option with Walker |
| `omarchy migrate` | `omarchy-migrate` | Run all pending migrations to bring the system in line with the installed version. |
| `omarchy notification dismiss <summary>` | `omarchy-notification-dismiss` | Dismiss a mako notification on the basis of its summary. Used by the first-run notifications to dismiss them after clicking for action. |
| `omarchy notification send <glyph> <headline> [description] [notify-send options]` | `omarchy-notification-send` | Send a desktop notification with Omarchy glyph and body spacing |
| `omarchy npx install <package> [command-name]` | `omarchy-npx-install` | Install an npx wrapper for a given npm package. |
| `omarchy pkg add <packages...>` | `omarchy-pkg-add` | Install Arch packages if they are missing |
| `omarchy pkg aur accessible` | `omarchy-pkg-aur-accessible` | Returns true if the AUR is up and available. |
| `omarchy pkg aur add <packages...>` | `omarchy-pkg-aur-add` | Add the named packages to the system from the AUR if they're missing. Returns false if it couldn't be done. |
| `omarchy pkg aur install` | `omarchy-pkg-aur-install` | Show a fuzzy-finder TUI for picking new AUR packages to install. |
| `omarchy pkg drop <packages...>` | `omarchy-pkg-drop` | Remove all the named packages from the system if they're installed (otherwise ignore). |
| `omarchy pkg install` | `omarchy-pkg-install` | Show a fuzzy-finder TUI for picking new Arch and OPR packages to install. |
| `omarchy pkg missing <packages...>` | `omarchy-pkg-missing` | Returns true if any of the named packages are missing from the system (or false if they're all there). |
| `omarchy pkg present <packages...>` | `omarchy-pkg-present` | Returns true if all of the named packages are installed on the system (or false if any of them are missing). |
| `omarchy pkg remove` | `omarchy-pkg-remove` | Show a fuzzy-finder TUI for picking packages installed on the system to be removed. |
| `omarchy plymouth preview <background-hex> <text-hex> <path-to-logo.png> <output-path>` | `omarchy-plymouth-preview` | Preview a Plymouth boot screen with custom colors and logo |
| `omarchy plymouth reset` | `omarchy-plymouth-reset` | Restore the default Omarchy Plymouth boot theme and SDDM login screen |
| `omarchy plymouth set by theme <theme-name>` | `omarchy-plymouth-set-by-theme` | Set the Plymouth boot theme from an Omarchy theme |
| `omarchy plymouth set <background-hex> <text-hex> <path-to-logo.png>` | `omarchy-plymouth-set` | Set the Plymouth boot theme colors and logo |
| `omarchy powerprofiles init` | `omarchy-powerprofiles-init` | Set the correct power profile on boot based on current AC/battery state. |
| `omarchy powerprofiles list` | `omarchy-powerprofiles-list` | Returns a list of all the available power profiles on the system. |
| `omarchy powerprofiles set [autodetect\|ac\|battery]` | `omarchy-powerprofiles-set` | Set the power profile to the requested level, falling back to balanced |
| `omarchy refresh applications` | `omarchy-refresh-applications` | Ensure all default .desktop, web apps, TUIs, and npx wrappers are installed. |
| `omarchy refresh chromium` | `omarchy-refresh-chromium` | Refresh the ~/.config/chromium-flags.conf file from the Omarchy defaults. |
| `omarchy refresh config <config-path>` | `omarchy-refresh-config` | Copies the named config from ~/.local/share/omarchy/config/X/Y/Z -> ~/.config/X/Y/Z. |
| `omarchy refresh fastfetch` | `omarchy-refresh-fastfetch` | Overwrite the user config for fastfetch with the Omarchy default. |
| `omarchy refresh hypridle` | `omarchy-refresh-hypridle` | Overwrite the user config for hypridle with the Omarchy default and restart the service. |
| `omarchy refresh hyprland` | `omarchy-refresh-hyprland` | Overwrite all the user configs in ~/.config/hypr with the Omarchy defaults. |
| `omarchy refresh hyprlock` | `omarchy-refresh-hyprlock` | Overwrite the user config for hyprlock with the Omarchy default. |
| `omarchy refresh hyprsunset` | `omarchy-refresh-hyprsunset` | Overwrite the user config for hyprsunset with the Omarchy default and restart the service. |
| `omarchy refresh limine` | `omarchy-refresh-limine` | Overwrite the user config for the Limine bootloader and rebuild it. |
| `omarchy refresh pacman` | `omarchy-refresh-pacman` | Overwrite the package configuration for /etc/pacman with the Omarchy default of using its dedicated mirrors and repositories, then update all packages. |
| `omarchy refresh plymouth` | `omarchy-refresh-plymouth` | Overwrite the user config for the Plymouth drive decryption and boot sequence with the Omarchy default and rebuild it. |
| `omarchy refresh sddm` | `omarchy-refresh-sddm` | Refresh the SDDM theme from default |
| `omarchy refresh swayosd` | `omarchy-refresh-swayosd` | Overwrite the user configs for swayosd (controls on-screen feedback for changing volume/songs etc) with the Omarchy defaults and restart the service. |
| `omarchy refresh tmux` | `omarchy-refresh-tmux` | Overwrite the user tmux config with the Omarchy default and reload tmux. |
| `omarchy refresh walker` | `omarchy-refresh-walker` | Overwrite the user configs for the Walker application launcher (which also powers the Omarchy Menu) and restart the services. |
| `omarchy refresh waybar` | `omarchy-refresh-waybar` | Reset Waybar config to Omarchy defaults |
| `omarchy reinstall configs` | `omarchy-reinstall-configs` | Reset all Omarchy user configs to the defaults |
| `omarchy reinstall git` | `omarchy-reinstall-git` | Reinstall the Omarchy source directory from git |
| `omarchy reinstall` | `omarchy-reinstall` | Reinstall Omarchy packages and reset default configs |
| `omarchy reinstall pkgs` | `omarchy-reinstall-pkgs` | Reinstall all default Omarchy packages from the stable channel |
| `omarchy reminder <minutes> [message] \| show \| clear` | `omarchy-reminder` | Set and show lightweight desktop notification reminders |
| `omarchy remove browser <chrome\|brave\|brave-origin\|edge\|firefox\|zen>` | `omarchy-remove-browser` | Remove a supported browser and clean up Omarchy browser defaults |
| `omarchy remove dev env <ruby\|node\|bun\|deno\|go\|php\|laravel\|symfony\|python\|elixir\|phoenix\|zig\|rust\|java\|dotnet\|ocaml\|clojure\|scala>` | `omarchy-remove-dev-env` | Remove a development environment that was previously installed via omarchy-install-dev-env. |
| `omarchy remove gaming geforce now` | `omarchy-remove-gaming-geforce-now` | Remove the GeForce NOW Flatpak app and its data. |
| `omarchy remove gaming heroic` | `omarchy-remove-gaming-heroic` | Remove Heroic Games Launcher and its game libraries, configs, and caches. |
| `omarchy remove gaming lutris` | `omarchy-remove-gaming-lutris` | Remove Lutris, Wine, umu-launcher, and all their configs and caches. |
| `omarchy remove gaming minecraft` | `omarchy-remove-gaming-minecraft` | Remove the Minecraft launcher along with its worlds, mods, and caches. |
| `omarchy remove gaming moonlight` | `omarchy-remove-gaming-moonlight` | Remove Moonlight and its configs and caches. |
| `omarchy remove gaming retroarch` | `omarchy-remove-gaming-retroarch` | Remove RetroArch, all libretro cores, and its config/saves. Leaves ~/Games/roms and ~/Games/bios alone. |
| `omarchy remove gaming steam` | `omarchy-remove-gaming-steam` | Remove Steam and all of its game libraries, configs, and caches. |
| `omarchy remove gaming xbox cloud` | `omarchy-remove-gaming-xbox-cloud` | Remove the Xbox Cloud Gaming web app. |
| `omarchy remove gaming xbox controllers` | `omarchy-remove-gaming-xbox-controllers` | Remove the xpadneo Xbox controller driver and undo its module/blacklist config. |
| `omarchy remove preinstalls` | `omarchy-remove-preinstalls` | Remove preinstalled Omarchy applications (web apps, TUIs, and selected packages). |
| `omarchy remove security fido2` | `omarchy-remove-security-fido2` | Remove FIDO2 authentication from sudo and polkit |
| `omarchy remove security fingerprint` | `omarchy-remove-security-fingerprint` | Remove fingerprint authentication from sudo, polkit, and lock screen |
| `omarchy restart app <application-name> [application-args...]` | `omarchy-restart-app` | Restart an application by killing it and relaunching via uwsm. |
| `omarchy restart bluetooth` | `omarchy-restart-bluetooth` | Unblock and restart the bluetooth service. |
| `omarchy restart btop` | `omarchy-restart-btop` | Reload btop configuration (used by the Omarchy theme switching). |
| `omarchy restart helix` | `omarchy-restart-helix` | Reload Helix configuration |
| `omarchy restart hyprctl` | `omarchy-restart-hyprctl` | Reload hyprland configuration (used by the Omarchy theme switching). |
| `omarchy restart hypridle` | `omarchy-restart-hypridle` | Restart the hypridle service (used for idle detection and auto-lock). |
| `omarchy restart hyprsunset` | `omarchy-restart-hyprsunset` | Restart the hyprsunset service (used for blue light filtering/night light). |
| `omarchy restart mako` | `omarchy-restart-mako` | Reload mako configuration (used by the Omarchy theme switching). |
| `omarchy restart opencode` | `omarchy-restart-opencode` | Reload opencode configuration (used by the Omarchy theme switching). |
| `omarchy restart pipewire` | `omarchy-restart-pipewire` | Restart the PipeWire audio service to fix audio issues or apply new configuration. |
| `omarchy restart swayosd` | `omarchy-restart-swayosd` | Restart the SwayOSD server |
| `omarchy restart terminal` | `omarchy-restart-terminal` | Reload supported terminal emulators after config changes |
| `omarchy restart tmux` | `omarchy-restart-tmux` | Restart tmux if running with the latest configuration |
| `omarchy restart trackpad` | `omarchy-restart-trackpad` | Reset the trackpad by unbinding and rebinding its driver. |
| `omarchy restart walker` | `omarchy-restart-walker` | Restart Walker and related user services |
| `omarchy restart waybar` | `omarchy-restart-waybar` | Restart Waybar |
| `omarchy restart wifi` | `omarchy-restart-wifi` | Unblock and restart the Wi-Fi service. |
| `omarchy restart xcompose` | `omarchy-restart-xcompose` | Restart the XCompose input method service (fcitx5) to apply new compose key settings. |
| `omarchy screensaver` | `omarchy-screensaver` | Run the Omarchy screensaver using random effects from TTE. |
| `omarchy setup dns [Cloudflare\|Google\|DHCP\|Custom]` | `omarchy-setup-dns` | Configure the system DNS provider |
| `omarchy setup security fido2` | `omarchy-setup-security-fido2` | Set up FIDO2 authentication for sudo and polkit |
| `omarchy setup security fingerprint` | `omarchy-setup-security-fingerprint` | Set up fingerprint authentication for sudo, polkit, and lock screen |
| `omarchy share <clipboard\|file\|folder> [path...]` | `omarchy-menu-share` | Share clipboard, files, or folders with LocalSend |
| `omarchy show done` | `omarchy-show-done` | Display a "Done!" message with a spinner and wait for user to press any key. |
| `omarchy show logo` | `omarchy-show-logo` | Display the Omarchy logo in the terminal using green color. |
| `omarchy snapshot <create\|restore>` | `omarchy-snapshot` | Create or restore system snapshots with snapper |
| `omarchy sudo keepalive` | `omarchy-sudo-keepalive` | Prompt for sudo once and keep the credential alive in the background. |
| `omarchy sudo passwordless [MINUTES]` | `omarchy-sudo-passwordless` | Toggle passwordless sudo for the current user. |
| `omarchy sudo reset` | `omarchy-sudo-reset` | Reset the sudo lockout/faillock for the current user. |
| `omarchy swayosd brightness <0-100>` | `omarchy-swayosd-brightness` | Display brightness level using SwayOSD on the current monitor. |
| `omarchy swayosd client <swayosd-client-args...>` | `omarchy-swayosd-client` | Wrapper for swayosd-client that targets the currently focused monitor. |
| `omarchy swayosd kbd brightness <0-100>` | `omarchy-swayosd-kbd-brightness` | Display keyboard brightness level using SwayOSD on the current monitor. |
| `omarchy system lock` | `omarchy-system-lock` | Lock the computer and turn off the display |
| `omarchy system logout` | `omarchy-system-logout` | Log out after closing application windows |
| `omarchy system reboot` | `omarchy-system-reboot` | Reboot after closing application windows |
| `omarchy system shutdown` | `omarchy-system-shutdown` | Shut down after closing application windows |
| `omarchy system wake` | `omarchy-system-wake` | Wake displays and restore brightness after idle |
| `omarchy theme bg install` | `omarchy-theme-bg-install` | Open the current theme's user background folder |
| `omarchy theme bg next` | `omarchy-theme-bg-next` | Cycle to the next background for the current theme |
| `omarchy theme bg set <path-to-image>` | `omarchy-theme-bg-set` | Set the current background image |
| `omarchy theme current` | `omarchy-theme-current` | Show current theme |
| `omarchy theme install [git-repo-url]` | `omarchy-theme-install` | Install a theme from a git repository |
| `omarchy theme list` | `omarchy-theme-list` | List available themes |
| `omarchy theme refresh` | `omarchy-theme-refresh` | Refresh the current theme from its templates. |
| `omarchy theme remove [theme-name]` | `omarchy-theme-remove` | Remove a user-installed theme |
| `omarchy theme set <theme-name>` | `omarchy-theme-set` | Apply an Omarchy theme |
| `omarchy theme update` | `omarchy-theme-update` | Update user-installed git themes |
| `omarchy toggle enabled <flag-name>` | `omarchy-toggle-enabled` | Check if a toggle is enabled (flag file exists) |
| `omarchy toggle hybrid gpu` | `omarchy-toggle-hybrid-gpu` | Toggle dedicated vs integrated GPU mode via supergfxd (for hybrid gpu laptops, like Asus G14). |
| `omarchy toggle idle` | `omarchy-toggle-idle` | Toggle hypridle idle locking |
| `omarchy toggle nightlight` | `omarchy-toggle-nightlight` | Toggle nightlight screen temperature |
| `omarchy toggle notification silencing` | `omarchy-toggle-notification-silencing` | Toggle notification do-not-disturb mode |
| `omarchy toggle [--enabled-notification <text>] [--disabled-notification <text>] <flag-name>` | `omarchy-toggle` | Toggle Omarchy features between enabled and disabled |
| `omarchy toggle screensaver` | `omarchy-toggle-screensaver` | Toggle screensaver availability |
| `omarchy toggle suspend` | `omarchy-toggle-suspend` | Toggle suspend availability in the system menu |
| `omarchy toggle touchpad [on\|off\|toggle]` | `omarchy-toggle-touchpad` | Enable, disable, or toggle the touchpad |
| `omarchy toggle touchscreen [on\|off\|toggle]` | `omarchy-toggle-touchscreen` | Enable, disable, or toggle the touch functionality of the screen |
| `omarchy toggle waybar` | `omarchy-toggle-waybar` | Toggle Waybar visibility |
| `omarchy transcode ascii <input-image.svg\|png> <output-path> [--width <columns>] [--height <rows>] [--mode <braille\|block>] [--threshold <percent>] [--invert]` | `omarchy-transcode-ascii` | Transcode an image into ASCII/Unicode art text |
| `omarchy transcode [--path path] [input] [format] [resolution]` | `omarchy-transcode` | Transcode pictures and videos for sharing |
| `omarchy tui install [name command window-style icon-url]` | `omarchy-tui-install` | Create a desktop launcher for a terminal UI app |
| `omarchy tui remove all` | `omarchy-tui-remove-all` | Remove all TUIs installed via omarchy-tui-install. |
| `omarchy tui remove [name...]` | `omarchy-tui-remove` | Remove terminal UI desktop launchers |
| `omarchy tz select` | `omarchy-tz-select` | Select and set the system timezone |
| `omarchy update analyze logs` | `omarchy-update-analyze-logs` | Check the update log for known failure conditions |
| `omarchy update aur pkgs` | `omarchy-update-aur-pkgs` | Update AUR packages if any are installed |
| `omarchy update available` | `omarchy-update-available` | Get remote tag |
| `omarchy update available reset` | `omarchy-update-available-reset` | Ensure Waybar icon offering the available update is removed |
| `omarchy update branch <branch>` | `omarchy-update-branch` | Switch Omarchy branches and update from the selected branch |
| `omarchy update confirm` | `omarchy-update-confirm` | Prompt for confirmation before starting an update |
| `omarchy update firmware` | `omarchy-update-firmware` | Update system firmware using fwupd. Ensures the fwupd EFI binary is installed |
| `omarchy update git` | `omarchy-update-git` | Pull the latest Omarchy git changes |
| `omarchy update keyring` | `omarchy-update-keyring` | Ensure the Omarchy and Arch keyring packages are installed and populated |
| `omarchy update [-y]` | `omarchy-update` | Update Omarchy and system packages |
| `omarchy update orphan pkgs` | `omarchy-update-orphan-pkgs` | Remove orphaned system packages after updates |
| `omarchy update perform` | `omarchy-update-perform` | Run the full Omarchy update pipeline |
| `omarchy update restart` | `omarchy-update-restart` | Prompt for required reboot or service restarts after updates |
| `omarchy update system pkgs` | `omarchy-update-system-pkgs` | Update system packages with pacman |
| `omarchy update time` | `omarchy-update-time` | Restart system time synchronization |
| `omarchy version branch` | `omarchy-version-branch` | Print the current Omarchy git branch |
| `omarchy version channel` | `omarchy-version-channel` | Print the active Omarchy mirror and package channel |
| `omarchy version` | `omarchy-version` | Print the installed Omarchy version |
| `omarchy version pkgs` | `omarchy-version-pkgs` | Print when system packages were last upgraded |
| `omarchy voxtype config` | `omarchy-voxtype-config` | Open the Voxtype configuration file |
| `omarchy voxtype install` | `omarchy-voxtype-install` | Install and configure Voxtype dictation |
| `omarchy voxtype model` | `omarchy-voxtype-model` | Open Voxtype AI model setup |
| `omarchy voxtype remove` | `omarchy-voxtype-remove` | Remove Voxtype dictation and its configuration |
| `omarchy voxtype status` | `omarchy-voxtype-status` | Clean up the voxtype --follow child when Waybar reloads |
| `omarchy weather icon` | `omarchy-weather-icon` | Returns a weather condition icon, adjusted for live sunrise and sunset. |
| `omarchy weather status` | `omarchy-weather-status` | Returns a formatted weather status string with temperature and wind speed. |
| `omarchy webapp handler hey [url]` | `omarchy-webapp-handler-hey` | Open HEY webmail and translate mailto links |
| `omarchy webapp handler zoom [url]` | `omarchy-webapp-handler-zoom` | Open Zoom web meetings from browser protocol links |
| `omarchy webapp install [name url icon [custom-exec] [mime-types]]` | `omarchy-webapp-install` | Create a desktop launcher for a web app |
| `omarchy webapp remove all` | `omarchy-webapp-remove-all` | Remove all web apps installed via omarchy-webapp-install. |
| `omarchy webapp remove [name...]` | `omarchy-webapp-remove` | Remove web app desktop launchers |
| `omarchy wifi powersave <on\|off>` | `omarchy-wifi-powersave` | Set Wi-Fi power save mode on wireless interfaces |
| `omarchy windows vm <install\|remove\|launch\|stop\|status> [options]` | `omarchy-windows-vm` | Install, launch, stop, inspect, or remove the Windows VM |
