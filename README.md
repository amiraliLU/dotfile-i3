<img width="1599" height="899" alt="image" src="https://github.com/user-attachments/assets/3e248fc7-36a4-41b7-a8e5-b6333b34b889" />

# dotfiles — i3 / polybar / picom / rofi / fastfetch

Config files for the monochrome i3 desktop setup.

Each **top-level folder is an application config directory**, and
`install.sh` installs it to `~/.config/<folder-name>`.

## Layout

```
dotfiles/
├── install.sh                    # installer (link / copy / unlink)
├── install-deps.sh               # checks & installs required packages
├── fastfetch/
│   ├── config.jsonc              # system info fetch (logo + modules)
│   ├── gang.txt                  # active ASCII logo (referenced by config)
│   └── bogo/eogo/iogo/logo/ziba.txt   # extra alternate logos
├── i3/
│   └── config                    # window manager (bindsym, gaps, theme)
├── picom/
│   └── picom.conf                # compositor (opacity, blur, corners)
├── polybar/
│   ├── config.ini                # bar + modules
│   ├── powermenu.ini             # power/logout menu module
│   ├── launch.sh                 # kills old bars, launches per monitor
│   └── scripts/
│       └── media-info.sh         # now-playing label
└── rofi/
    └── config.rasi               # launcher theme (black & white)
```

Folder name → target:

| folder            | installs to           |
| ----------------- | --------------------- |
| `i3/`             | `~/.config/i3/`       |
| `picom/`          | `~/.config/picom/`    |
| `polybar/`        | `~/.config/polybar/`  |
| `rofi/`           | `~/.config/rofi/`     |
| `fastfetch/`      | `~/.config/fastfetch/`|

## Install

```bash
./install.sh              # check deps, then symlink into ~/.config
./install.sh --no-deps    # skip the dependency check
./install.sh --copy       # copy instead of symlinking
./install.sh i3 polybar   # only these apps
./install.sh --copy rofi  # copy only rofi
./install.sh --yes --aur  # auto-confirm, allow AUR packages
./install.sh --help       # full usage
```

Existing files at the target are moved to `<name>.bak.<timestamp>` first, so
nothing is lost. Re-running is safe: already-correct links are left alone.

By default `install.sh` asks whether to check dependencies first. Answer `n`
to only get a report, or pass `--no-deps` to skip it entirely.

Then reload the session: press `$mod+Shift+r` in i3, or log out and back in.

## Dependencies

`install-deps.sh` reads the configs, reports every missing program and font,
and installs what is missing with `pacman`. Use it on its own too:

```bash
./install-deps.sh                 # report, then install missing
./install-deps.sh --dry-run       # report only, change nothing
./install-deps.sh --yes           # no confirmation prompt
./install-deps.sh --aur           # also allow AUR packages (via yay/paru)
```

What it checks:

| package                    | used for                                  |
| -------------------------- | ----------------------------------------- |
| `i3-wm`, `i3status`        | window manager, status generator          |
| `polybar`                  | status bar                                |
| `picom`                    | shadows, blur, transparency               |
| `rofi`                     | app launcher                              |
| `dmenu`                    | fallback launcher bound in `i3/config`    |
| `feh`                      | sets the wallpaper                        |
| `dex`                      | XDG autostart `.desktop` files            |
| `xss-lock`, `i3lock`       | screen locking on suspend                 |
| `network-manager-applet`   | tray network icon                         |
| `libpulse`                 | `pactl` volume keys                       |
| `xorg-setxkbmap`           | us/ir keyboard layout toggle              |
| `playerctl`                | now-playing label in the polybar          |
| `xorg-xrandr`              | per-monitor polybar launch                |
| `iproute2`                 | default-interface detection               |
| `fastfetch`                | system info fetch                         |
| `noto-fonts-emoji`         | emoji glyphs                              |
| `ttf-nerd-fonts-symbols`   | Nerd Font icons                           |
| `adwaita-fonts`            | bar text font                             |

`--aur` is needed for one optional item: this `picom.conf` uses
`blur-method = "dual_kawase"`, which the official `picom` 13 package does not
support. Either install the AUR fork `picom-pijulius-next-git`, or set
`blur-background = false` in `picom/picom.conf`.

## Uninstall

```bash
./install.sh --unlink
```

Symlinks are deleted; copied folders are moved aside to
`<name>.bak.<timestamp>`.

## Adding another app

Just create a folder named after the app and re-run the installer:

```bash
mkdir -p ~/dotfiles/kitty && cp -a ~/.config/kitty/. ~/dotfiles/kitty/
./install.sh            # kitty is picked up automatically
```

## Notes

- `fastfetch/config.jsonc` points at `~/.config/fastfetch/gang.txt`. To use a
  different logo, change `logo.source` to one of the other `.txt` files in the
  same folder (e.g. `~/.config/fastfetch/ziba.txt`).
- `launch.sh` and `media-info.sh` must stay executable (`chmod +x`);
  `--copy` preserves the bit, and git tracks it.
- Polybar autodetects the default network interface; override with
  `NETWORK_INTERFACE=eth0 ./launch.sh`.
- The wallpaper is set from `i3/config`:
  `feh --bg-fill /home/aligurgi4/Pictures/art.jpg` — change the path there if
  the image moves.
- `picom.conf` needs a picom build with `dual_kawase` blur (picom-ibhagwan or
  picom ≥ 10 with blur support), otherwise set `blur-background = false`.
- Target dir is `${XDG_CONFIG_HOME:-$HOME/.config}`, so an exported
  `XDG_CONFIG_HOME` is respected.
