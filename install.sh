#!/usr/bin/env bash
# install.sh — install/update/restore metro-shell
#   ./install.sh              interactive mode
#   ./install.sh restore      restore from backup right away
#   ./install.sh --check      check only: distro, hardware, dependencies
#   ./install.sh --deps-only  dependencies only
#   ./install.sh --no-deps    files only, no dependencies
#   ./install.sh --yes        answer yes by default (no questions)
#   ./install.sh --help       help
#
# Supported: Arch/CachyOS/EndeavourOS/Manjaro (pacman),
# Ubuntu/Debian/Mint/Pop!_OS (apt), Fedora/Nobara (dnf),
# LFS + arch packages (sven: sudo sven sync / sudo sven install).
# Everything else — manual mode: files are copied, package list is shown.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── output ─────────────────────────────────────────────────────────────────
G=$'\e[1;32m'; Y=$'\e[1;33m'; R=$'\e[1;31m'; B=$'\e[1;36m'; D=$'\e[2m'; N=$'\e[0m'
msg()  { printf '%s\n' "${B}==>${N} $*"; }
ok()   { printf '%s\n' "${G} ✓${N} $*"; }
warn() { printf '%s\n' "${Y} !${N} $*"; }
err()  { printf '%s\n' "${R} ✗${N} $*" >&2; }
die()  { err "$*"; exit 1; }
AUTO_YES=0
# ask "question" [1] — second arg: default answer is yes
ask()  { local a d="${2:-0}"; (( AUTO_YES )) && return $(( ! d ));
         read -rp "$(printf '%s' "${B}?>${N} $1 [$([[ $d = 1 ]] && printf 'Y/n' || printf 'y/N')] ")" a
         a="${a:-$([[ $d = 1 ]] && echo y || echo n)}"; [[ "$a" =~ ^[YyДд] ]]; }

banner() {
    printf '%s\n' "${B}=========================================="
    printf '%s\n' "  M E T R O   S H E L L"
    printf '%s\n' "  quickshell · hyprland · metro live tiles"
    printf '%s\n' "==========================================$N"
}

# ── targets ────────────────────────────────────────────────────────────────
SH_DIR="$HOME/.config/quickshell/metro"
BIN_DIR="$HOME/.local/bin"
DT_DIR="$HOME/.local/share/applications"
BACKUP_ROOT="$HOME/metro-backup"

# "<path relative to ~/.config (or bin/ applications/)>:<source in repo>"
ITEMS=(
    "quickshell/metro:$SCRIPT_DIR/shell"
    "quickshell/metro-settings:$SCRIPT_DIR/settings"
    "quickshell/metro-lock:$SCRIPT_DIR/lock"
    "quickshell/metro-shot:$SCRIPT_DIR/shot"
    "quickshell/metro-shell.conf:$SCRIPT_DIR/metro-shell.conf"
    "bin/qs-metro:$SCRIPT_DIR/bin/qs-metro"
    "bin/metro-colors:$SCRIPT_DIR/bin/metro-colors"
    "bin/metro-conf:$SCRIPT_DIR/bin/metro-conf"
    "bin/metro_conf.py:$SCRIPT_DIR/bin/metro_conf.py"
    "bin/metro-lock:$SCRIPT_DIR/bin/metro-lock"
    "bin/metro-settings:$SCRIPT_DIR/bin/metro-settings"
    "bin/metro-shot:$SCRIPT_DIR/bin/metro-shot"
    "bin/metro-update:$SCRIPT_DIR/bin/metro-update"
    "bin/metro-snap:$SCRIPT_DIR/bin/metro-snap"
    "bin/metro-appearance:$SCRIPT_DIR/bin/metro-appearance"
    "bin/metro-theme:$SCRIPT_DIR/bin/metro-theme"
    "bin/wall:$SCRIPT_DIR/bin/wall"
    "bin/wall-start:$SCRIPT_DIR/bin/wall-start"
    "applications/metro-settings.desktop:$SCRIPT_DIR/desktop/metro-settings.desktop"
    "hypr/hyprland.lua:$SCRIPT_DIR/hypr/hyprland.lua"
    "hypr/hypridle.conf:$SCRIPT_DIR/hypr/hypridle.conf"
    "mako/config:$SCRIPT_DIR/mako/config"
)
# Seed files: existing ones are NOT overwritten on update (user data)
SEED_ONLY=(
    "quickshell/metro-shell.conf"
    "quickshell/metro/layout.json"
    "quickshell/metro/pinned.json"
    "quickshell/metro/notes.json"
    "quickshell/metro/city.json"
)

target_for_rel() {
    case "$1" in
        applications/*) echo "$DT_DIR/${1#applications/}" ;;
        bin/*)          echo "$BIN_DIR/${1#bin/}" ;;
        *)              echo "$HOME/.config/$1" ;;
    esac
}

installed() { [[ -d "$SH_DIR" ]]; }

# ── distro detection ───────────────────────────────────────────────────────
DISTRO="unknown"   # arch | debian | fedora | unknown
PM=""              # pacman | sven | apt | dnf | ""

detect_distro() {
    local id="" like=""
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        id="${ID:-}"; like="${ID_LIKE:-}"
    fi
    case " $id $like " in
        *" arch "*) DISTRO="arch"; PM="pacman" ;;
        *" debian "*|*" ubuntu "*) DISTRO="debian"; PM="apt" ;;
        *" fedora "*) DISTRO="fedora"; PM="dnf" ;;
        *)
            if command -v pacman >/dev/null 2>&1; then DISTRO="arch"; PM="pacman"
            elif command -v sven >/dev/null 2>&1; then DISTRO="arch"; PM="sven"
            elif command -v apt-get >/dev/null 2>&1; then DISTRO="debian"; PM="apt"
            elif command -v dnf >/dev/null 2>&1; then DISTRO="fedora"; PM="dnf"
            fi ;;
    esac
    ok "distro: ${id:-?} → family $DISTRO (manager: ${PM:-none})"
}

# ── hardware detection ─────────────────────────────────────────────────────
HW_GPU="unknown" HW_BAT=0 HW_BACKLIGHT=0 HW_BT=0 HW_WIFI=0

detect_hw() {
    msg "hardware"
    local vga
    vga="$(lspci 2>/dev/null | grep -iE 'vga|3d|display' || true)"
    if grep -qi nvidia <<<"$vga"; then HW_GPU="nvidia"
    elif grep -qiE 'amd|ati|radeon' <<<"$vga"; then HW_GPU="amd"
    elif grep -qiE 'intel' <<<"$vga"; then HW_GPU="intel"
    fi
    [[ -n "$(ls -d /sys/class/power_supply/BAT* 2>/dev/null)" ]] && HW_BAT=1
    [[ -n "$(ls /sys/class/backlight/ 2>/dev/null)" ]] && HW_BACKLIGHT=1
    if command -v bluetoothctl >/dev/null 2>&1 && \
       bluetoothctl show 2>/dev/null | grep -qi 'controller'; then HW_BT=1
    elif command -v rfkill >/dev/null 2>&1 && \
       rfkill list bluetooth 2>/dev/null | grep -q .; then HW_BT=1
    fi
    if ls /sys/class/net/ 2>/dev/null | grep -q '^wl'; then HW_WIFI=1
    elif command -v nmcli >/dev/null 2>&1 && \
       nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep -q ':wifi'; then HW_WIFI=1
    fi
    echo "  gpu: $HW_GPU · battery: $HW_BAT · backlight: $HW_BACKLIGHT · bluetooth: $HW_BT · wi-fi: $HW_WIFI"
    (( HW_BAT )) || warn "no battery (desktop?) — BAT tiles will show 0, that's fine"
    (( HW_BACKLIGHT )) || warn "no backlight devices — brightness slider won't work"
    if [[ "$HW_GPU" == "nvidia" ]] && ! command -v nvidia-smi >/dev/null 2>&1; then
        warn "NVIDIA GPU but no nvidia-smi — install the proprietary driver (or the GPU widget shows 0)"
    fi
}

# ── per-family packages ────────────────────────────────────────────────────
# Critical ones go as a batch; optional ones — one by one with a warning.
ARCH_PKGS=(hyprland quickshell awww hypridle mako grim slurp jq curl playerctl
    networkmanager bluez bluez-utils brightnessctl pipewire wireplumber
    power-profiles-daemon matugen python-pillow papirus-icon-theme qt6-5compat
    ttf-noto-nerd polkit-gnome cliphist wl-clipboard satty hyprpicker
    tesseract tesseract-data-eng tesseract-data-rus kitty nemo ffmpeg
    xdg-utils desktop-file-utils noto-fonts)
ARCH_AUR=(ttf-segoe-ui-variable)

DEBIAN_PKGS=(hyprland hypridle mako grim slurp jq curl playerctl network-manager
    bluez brightnessctl pipewire wireplumber pipewire-pulse power-profiles-daemon
    python3-pil papirus-icon-theme wl-clipboard tesseract-ocr tesseract-ocr-eng
    tesseract-ocr-rus kitty nemo ffmpeg xdg-utils desktop-file-utils
    libglib2.0-bin unzip fonts-noto cliphist cargo git pkg-config
    libwayland-dev wayland-protocols libxkbcommon-dev liblz4-dev scdoc)

FEDORA_PKGS=(hyprland hypridle hyprpicker mako grim slurp jq curl playerctl
    NetworkManager bluez brightnessctl pipewire wireplumber power-profiles-daemon
    python3-pillow papirus-icon-theme wl-clipboard tesseract tesseract-langpack-eng
    tesseract-langpack-rus kitty nemo ffmpeg xdg-utils desktop-file-utils glib2
    unzip google-noto-sans-fonts polkit-gnome cargo git pkg-config wayland-devel
    wayland-protocols-devel libxkbcommon-devel lz4-devel scdoc)

install_batch_then_single() {
    # $1 = manager command prefix (e.g. "sudo pacman -S --needed"),
    # rest = packages. Batch first, on failure — one by one.
    local -a installer=()
    read -ra installer <<<"$1"; shift
    local -a pkgs=("$@") failed=()
    if "${installer[@]}" "${pkgs[@]}"; then
        return 0
    fi
    warn "batch install partially failed — retrying one by one"
    local p
    for p in "${pkgs[@]}"; do
        "${installer[@]}" "$p" 2>/dev/null || failed+=("$p")
    done
    if (( ${#failed[@]} )); then
        warn "failed: ${failed[*]} (see fallbacks/manual steps below)"
        return 1
    fi
    return 0
}

ensure_quickshell_arch() {
    command -v quickshell >/dev/null 2>&1 && return 0
    if [[ "${PM:-}" == "sven" ]]; then
        warn "no quickshell — trying sven (arch+AUR)"
        sudo sven install quickshell || sudo sven install quickshell-git || true
        return 0
    fi
    warn "no quickshell in repos — trying AUR"
    if [[ -n "${HELPER:-}" ]]; then
        "$HELPER" -S --needed quickshell || "$HELPER" -S --needed quickshell-git || true
    fi
}

ensure_quickshell_debian() {
    command -v quickshell >/dev/null 2>&1 && return 0
    msg "quickshell → PPA avengemedia/danklinux"
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:avengemedia/danklinux
    sudo apt-get update
    sudo apt-get install -y quickshell || sudo apt-get install -y quickshell-git || true
}

ensure_quickshell_fedora() {
    command -v quickshell >/dev/null 2>&1 && return 0
    msg "quickshell → COPR errornointernet/quickshell"
    sudo dnf copr enable -y errornointernet/quickshell
    sudo dnf install -y quickshell || true
}

ensure_awww_from_source() {
    # awww (swww fork, Codeberg LGFae/awww): outside Arch it builds via cargo.
    command -v awww >/dev/null 2>&1 && { ok "awww present"; return 0; }
    warn "awww not in packages — building from source (cargo)"
    local src="$HOME/.cache/metro-build/awww"
    mkdir -p "$(dirname "$src")"
    if [[ ! -d "$src/.git" ]]; then
        git clone --depth 1 https://codeberg.org/LGFae/awww "$src" || return 1
    fi
    (cd "$src" && cargo build --release) || return 1
    mkdir -p "$BIN_DIR"
    install -m755 "$src/target/release/awww" "$src/target/release/awww-daemon" "$BIN_DIR/"
    ok "awww built into $BIN_DIR"
}

ensure_matugen_cargo() {
    command -v matugen >/dev/null 2>&1 && { ok "matugen present"; return 0; }
    warn "matugen not in packages — installing via cargo"
    cargo install matugen --locked || return 1
    [[ -d "$HOME/.cargo/bin" ]] && [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]] &&
        warn "add ~/.cargo/bin to PATH (matugen, awww)"
}

ensure_satty_note() {
    command -v satty >/dev/null 2>&1 && return 0
    warn "no satty (screenshot editor) — metro-shot works without it; manual: https://github.com/gabm/Satty/releases"
    return 1
}

ensure_nerd_font() {
    # via grep -c (not -q): with pipefail an early grep -q exit gives SIGPIPE
    # and a false "no font" — count matches with a full pass.
    if (( $(fc-list 2>/dev/null | grep -ci "nerd") > 0 )); then
        ok "nerd font present"; return 0
    fi
    msg "nerd font → downloading Noto Nerd Font into ~/.local/share/fonts"
    mkdir -p "$HOME/.local/share/fonts" "$HOME/.cache/metro-build"
    local noto_zip="$HOME/.cache/metro-build/Noto.zip"
    if curl -sSL --connect-timeout 15 --max-time 120 --retry 1 -o "$noto_zip" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Noto.zip" \
        && unzip -oq "$noto_zip" -d "$HOME/.local/share/fonts/NotoNerd" \
        && fc-cache -f >/dev/null 2>&1; then
        ok "nerd font installed"
    else
        warn "download failed — glyph icons may show as boxes; install any Nerd Font manually"
    fi
    rm -f "$noto_zip"
}

HELPER=""

detect_helper() {
    if command -v paru >/dev/null 2>&1; then
        HELPER="paru"
    elif command -v yay >/dev/null 2>&1; then
        HELPER="yay"
    else
        warn "no AUR helper found (paru/yay)"
        if ask "install yay via pacman?" 1; then
            sudo pacman -S --needed yay
            HELPER="yay"
        else
            warn "without a helper AUR packages are skipped: ${ARCH_AUR[*]}"
        fi
    fi
    [[ -n "$HELPER" ]] && ok "AUR helper: $HELPER"
}

install_deps() {
    msg "[1/4] dependencies ($DISTRO)"
    case "$DISTRO" in
        arch)
            if [[ "$PM" == "sven" ]]; then
                # sven pulls both arch and AUR packages with one command — no helper needed
                sudo sven sync || warn "sven sync failed — installing on stale databases"
                install_batch_then_single "sudo sven install" "${ARCH_PKGS[@]}" "${ARCH_AUR[@]}" || true
            else
                detect_helper
                install_batch_then_single "sudo pacman -S --needed" "${ARCH_PKGS[@]}" || true
                if [[ -n "$HELPER" ]]; then
                    "$HELPER" -S --needed "${ARCH_AUR[@]}" || true
                fi
            fi
            ensure_quickshell_arch
            ensure_awww_from_source || warn "no awww — wallpapers via wall won't work"
            ensure_matugen_cargo || warn "no matugen — wallpaper theme won't build (PIL fallback)"
            ;;
        debian)
            sudo apt-get update
            install_batch_then_single "sudo apt-get install -y" "${DEBIAN_PKGS[@]}" || true
            ensure_quickshell_debian
            if ! command -v Hyprland >/dev/null 2>&1; then
                warn "Hyprland missing (stock Ubuntu repos often lack it) —"
                echo "  ${D}options: PPA avengemedia/danklinux (already added above) or https://hyprland.org${N}"
            fi
            ensure_awww_from_source || warn "no awww — wallpapers via wall won't work"
            ensure_matugen_cargo || warn "no matugen — wallpaper theme won't build (PIL fallback)"
            ensure_satty_note || true
            command -v hyprpicker >/dev/null 2>&1 || warn "no hyprpicker (freeze-only screenshots)"
            ;;
        fedora)
            install_batch_then_single "sudo dnf install -y" "${FEDORA_PKGS[@]}" || true
            ensure_quickshell_fedora
            ensure_awww_from_source || warn "no awww — wallpapers via wall won't work"
            ensure_matugen_cargo || warn "no matugen — wallpaper theme won't build (PIL fallback)"
            ensure_satty_note || true
            ;;
        *)
            warn "unknown distro — installing files only, packages are on you:"
            echo "  needed: hyprland hypridle quickshell(>=0.3.1) awww mako grim slurp jq curl"
            echo "  playerctl NetworkManager bluez brightnessctl pipewire wireplumber"
            echo "  power-profiles-daemon matugen python3-PIL papirus-icon-theme"
            echo "  polkit-agent cliphist wl-clipboard satty hyprpicker tesseract kitty nemo ffmpeg"
            echo "  quickshell: https://quickshell.org/docs/guide/install-setup"
            echo "  awww: build with cargo from https://codeberg.org/LGFae/awww"
            echo "  openSUSE: same package names as Fedora (zypper), quickshell from an OBS/COPR build"
            ;;
    esac
    ensure_nerd_font || true
    fc-cache -f >/dev/null 2>&1 || true
    verify_deps
}

# Binary → criticality (for --check and post-check)
# Note: the Hyprland binary starts with a capital H.
REQ_BINS=(Hyprland quickshell jq curl grim slurp wl-copy wl-paste python3)
OPT_BINS=(awww matugen playerctl nmcli bluetoothctl brightnessctl wpctl
          powerprofilesctl makoctl hypridle satty hyprpicker tesseract kitty
          cliphist gsettings ffmpeg)

verify_deps() {
    msg "checking dependencies"
    local miss_req=() miss_opt=() b
    for b in "${REQ_BINS[@]}"; do
        command -v "$b" >/dev/null 2>&1 || miss_req+=("$b")
    done
    for b in "${OPT_BINS[@]}"; do
        command -v "$b" >/dev/null 2>&1 || miss_opt+=("$b")
    done
    if command -v quickshell >/dev/null 2>&1; then
        local qv
        qv="$(quickshell --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || true)"
        [[ -n "$qv" ]] && echo "  quickshell: $qv (need >= 0.3.1)"
    fi
    (( ${#miss_req[@]} )) && err "MISSING critical: ${miss_req[*]}" || ok "critical binaries present"
    (( ${#miss_opt[@]} )) && warn "missing optional: ${miss_opt[*]} (matching features degrade silently)"
    (( ${#miss_req[@]} )) && return 1 || return 0
}

check_only() {
    verify_deps || true
    echo "  ${D}quickshell config: ${SH_DIR}$([ -d "$SH_DIR" ] && echo ' (installed)' || echo ' (not installed)')$N"
}

# ── backup / restore ─────────────────────────────────────────────────────────
BACKUP_DEST=""

do_backup() {
    local ts dest n=0
    ts="$(date +%Y%m%d-%H%M%S)"
    dest="$BACKUP_ROOT/$ts"
    for it in "${ITEMS[@]}"; do
        local rel="${it%%:*}" src; src="$(target_for_rel "$rel")"
        if [[ -e "$src" ]]; then
            mkdir -p "$dest/$(dirname "$rel")"
            cp -a "$src" "$dest/$rel"
            n=$((n + 1))
        fi
    done
    if (( n == 0 )); then
        rmdir "$dest" 2>/dev/null || true
        warn "no existing configs found — nothing to back up"
        return 1
    fi
    BACKUP_DEST="$dest"
    ok "backup: $dest ($n items)"
}

choose_backup() {
    [[ -d "$BACKUP_ROOT" ]] || die "no backups ($BACKUP_ROOT)"
    local list
    list="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '20*' | sort)"
    [[ -n "$list" ]] || die "no backups ($BACKUP_ROOT)"
    if [[ "$(echo "$list" | wc -l)" -gt 1 ]]; then
        echo "$list" | nl -w2 -s') '
        local a
        read -rp "$(printf '%s' "${B}?>${N} which one to restore [latest]: ")" a
        [[ -n "$a" && "$a" =~ ^[0-9]+$ ]] && echo "$list" | sed -n "${a}p" || echo "$list" | tail -n1
    else
        echo "$list"
    fi
}

do_restore() {
    local src="$1" item
    msg "restoring from $src"
    for it in "${ITEMS[@]}"; do
        local rel="${it%%:*}"
        if [[ -e "$src/$rel" ]]; then
            local dst; dst="$(target_for_rel "$rel")"
            mkdir -p "$(dirname "$dst")"
            rm -rf "$dst"
            cp -a "$src/$rel" "$dst"
            ok "restored: ${dst/#$HOME/~}"
        fi
    done
    chmod +x "$BIN_DIR"/{qs-metro,metro-colors,metro-conf,metro-lock,metro-settings,metro-shot,metro-update,metro-snap,metro-appearance,metro-theme,wall,wall-start} 2>/dev/null || true
    ok "done. apply with: hyprctl reload (or relogin)"
}

restore_menu() {
    do_restore "$(choose_backup)"
}

# ── file installation ────────────────────────────────────────────────────────
do_install_files() {
    local clean="$1"
    msg "[2/4] shell files"
    # Stash user data before copying whole directories, then bring it back
    # (except clean reinstall — a deliberate reset to repo seeds there;
    # a backup was already made in reinstall()/fresh_install())
    local stash; stash="$(mktemp -d)"
    local s sp
    for s in "${SEED_ONLY[@]}"; do
        sp="$(target_for_rel "$s")"
        if [[ -e "$sp" ]]; then
            mkdir -p "$stash/$(dirname "$s")"
            cp -a "$sp" "$stash/$s"
        fi
    done
    for it in "${ITEMS[@]}"; do
        local rel="${it%%:*}" src="${it#*:}"
        local dst; dst="$(target_for_rel "$rel")"
        # hyprland.lua: differing existing one goes to a backup next to it, repo version wins
        if [[ "$rel" == "hypr/hyprland.lua" && -e "$dst" ]]; then
            if ! diff -q "$src" "$dst" >/dev/null 2>&1; then
                local bak="$dst.user-$(date +%Y%m%d-%H%M%S)"
                cp -af "$dst" "$bak"
                warn "hyprland.lua differed — yours saved: ${bak/#$HOME/~}"
            fi
        fi
        if [[ -d "$src" ]]; then
            mkdir -p "$dst"
            cp -af "$src/." "$dst/"
        else
            mkdir -p "$(dirname "$dst")"
            cp -af "$src" "$dst"
        fi
    done
    if [[ "$clean" != yes ]]; then
        for s in "${SEED_ONLY[@]}"; do
            if [[ -e "$stash/$s" ]]; then
                sp="$(target_for_rel "$s")"
                mkdir -p "$(dirname "$sp")"
                cp -a "$stash/$s" "$sp"
            fi
        done
        ok "user data kept: metro-shell.conf, layout/pinned/notes/city.json"
    else
        warn "clean reinstall — grid/city/config reset to repo seeds"
    fi
    rm -rf "$stash"
    chmod +x "$BIN_DIR"/qs-metro "$BIN_DIR"/metro-colors "$BIN_DIR"/metro-conf \
             "$BIN_DIR"/metro-lock "$BIN_DIR"/metro-settings "$BIN_DIR"/metro-shot \
             "$BIN_DIR"/metro-update "$BIN_DIR"/metro-snap "$BIN_DIR"/metro-appearance \
             "$BIN_DIR"/metro-theme "$BIN_DIR"/wall "$BIN_DIR"/wall-start
    update-desktop-database "$DT_DIR" >/dev/null 2>&1 || true
    ok "copied: quickshell/metro{,-settings,-lock,-shot}, bin/, hypr/, mako/"
}

post_setup() {
    msg "[3/4] wallpapers and icons"
    # Stock wallpapers from the repo → ~/Wallpapers (yours are never touched).
    # If you have no wallpaper yet — point state at default.jpg and build
    # its colors via metro-colors (live wall applies on first wall /
    # wall-start run inside the session).
    if [[ -d "$SCRIPT_DIR/assets/wallpapers" ]]; then
        mkdir -p "$HOME/Wallpapers"
        cp -n "$SCRIPT_DIR"/assets/wallpapers/* "$HOME/Wallpapers/" 2>/dev/null || true
        if [[ ! -f "$HOME/.local/state/metro/wall" ]]; then
            if [[ -f "$HOME/Wallpapers/default.jpg" ]]; then
                mkdir -p "$HOME/.local/state/metro"
                printf '%s\n' "$HOME/Wallpapers/default.jpg" > "$HOME/.local/state/metro/wall"
                "$BIN_DIR/metro-colors" >/dev/null 2>&1 || true
                ok "stock wallpaper: ~/Wallpapers/default.jpg (theme color taken from it)"
            fi
        fi
    fi
    # Default shell language: English (switch to Russian in Settings → Language)
    if [[ ! -f "$HOME/.local/state/metro/lang" ]]; then
        mkdir -p "$HOME/.local/state/metro"
        printf '%s' "en" > "$HOME/.local/state/metro/lang"
    fi
    if command -v gsettings >/dev/null 2>&1; then
        local cur
        cur="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || echo "''")"
        if [[ "$cur" != *Papirus-Dark* ]] && ask "Papirus-Dark icon theme (needed for shell icons)?" 1; then
            gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
            ok "icons: Papirus-Dark"
        fi
    else
        warn "no gsettings — set the Papirus-Dark icon theme manually"
    fi

    if [[ ! -f "$HOME/.local/state/metro/wall" ]]; then
        warn "no wallpaper selected — after login run: wall ~/Wallpapers/<file>"
    fi
    warn "check your hardware with: hyprctl monitors"
    echo "  ${D}optionally set modes via the hl.monitor block in ~/.config/hypr/hyprland.lua${N}"

    msg "[4/4] launch"
    # Single-config watcher: edit metro-shell.conf — themes rebuild themselves
    if [[ -d "$SCRIPT_DIR/systemd" ]] && command -v systemctl >/dev/null 2>&1; then
        mkdir -p "$HOME/.config/systemd/user"
        cp -a "$SCRIPT_DIR/systemd/." "$HOME/.config/systemd/user/"
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now metro-conf-watcher.path 2>/dev/null || true
        ok "config watcher: metro-conf-watcher.path"
    elif [[ -d "$SCRIPT_DIR/systemd" ]]; then
        warn "no systemd — metro-conf-watcher.path skipped (non-critical)"
    fi
    verify_deps || warn "install what's missing, then rerun ./install.sh (files are already in place)"
    # Apply the new Hyprland config right away instead of asking (inside a session only)
    if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        if hyprctl reload >/dev/null 2>&1; then
            ok "hyprctl reload — config applied"
        else
            warn "hyprctl reload failed — run it manually: hyprctl reload"
        fi
    else
        echo "  • relogin into Hyprland or run: ${G}hyprctl reload${N}"
    fi
    echo "  • right now: ${G}qs-metro${N}  ·  wallpapers: ${G}wall random${N}  ·  settings: ${G}metro-settings${N}  ·  screenshot: ${G}metro-shot${N}"
    echo "  • system update: ${G}metro-update${N}  ·  lockscreen: ${G}metro-lock${N} (hypridle locks after 5 min; ${D}loginctl lock-session${N} — manual)"
    ask "launch the shell now (qs-metro)?" 1 && "$BIN_DIR/qs-metro"
}

# ── scenarios ────────────────────────────────────────────────────────────────
fresh_install() {
    if ask "back up existing configs (if any)?" 1; then
        do_backup || true
    fi
    (( SKIP_DEPS )) || install_deps
    do_install_files no
    post_setup
    [[ -n "$BACKUP_DEST" ]] && echo "  ${D}rollback anytime: ./install.sh restore (backup $BACKUP_DEST)${N}"
}

update_install() {
    (( SKIP_DEPS )) || install_deps
    do_install_files no
    post_setup
}

reinstall() {
    do_backup || true
    (( SKIP_DEPS )) || install_deps
    do_install_files yes
    post_setup
}

menu_installed() {
    echo
    echo "  metro-shell is already installed. what now?"
    echo "   ${G}1${N}) update         ${D}— overwrite files; layout/pinned/notes/city.json and metro-shell.conf are kept${N}"
    echo "   ${G}2${N}) reinstall      ${D}— backup, then clean install (grid/city reset to seeds)${N}"
    echo "   ${G}3${N}) restore        ${D}— roll everything back from a backup ($BACKUP_ROOT)${N}"
    echo "   ${G}0${N}) exit"
    local a
    read -rp "$(printf '%s' "${B}?>${N} choice: ")" a
    case "$a" in
        1) update_install ;;
        2) reinstall ;;
        3) restore_menu ;;
        *) echo "bye." ;;
    esac
}

usage() {
    cat <<EOF
metro-shell — dotfiles installer (quickshell shell + hyprland + mako)

  ./install.sh              interactive mode
  ./install.sh restore      restore from backup right away
  ./install.sh --check      check: distro, hardware, dependencies
  ./install.sh --deps-only  dependencies only
  ./install.sh --no-deps    skip dependencies (files only)
  ./install.sh --yes        answer "yes" by default

What gets installed: quickshell (shell/settings/lockscreen/screenshot tool), utils in ~/.local/bin,
hyprland.lua + hypridle.conf, mako, .desktop file.
Distros: Arch (pacman + AUR paru/yay; LFS — sven: sync + install) · Debian/Ubuntu (apt + PPA danklinux for
quickshell, awww built from source) · Fedora (dnf + COPR for quickshell).
Kept as-is: metro-shell.conf, layout/pinned/notes/city.json.
hyprland.lua is always refreshed from the repo; your differing one goes to hyprland.lua.user-<date> next to it.
Backups: $BACKUP_ROOT/<date-time>
EOF
}

SKIP_DEPS=0

main() {
    local mode="install" arg
    for arg in "$@"; do
        case "$arg" in
            --help|-h) usage; exit 0 ;;
            --yes|-y) AUTO_YES=1 ;;
            --check) mode="check" ;;
            --deps-only) mode="deps" ;;
            --no-deps) SKIP_DEPS=1 ;;
            restore) mode="restore" ;;
            *) die "unknown argument: $arg (see --help)" ;;
        esac
    done
    [[ $EUID -eq 0 ]] && die "run as your own user — sudo is asked for when needed"
    [[ -d "$SCRIPT_DIR/shell" && -f "$SCRIPT_DIR/bin/wall" ]] || die "run from the unpacked repository (no shell/ or bin/)"
    # The repo must be readable by the current user: installing from someone
    # else's $HOME (e.g. /home/banue when testing as another user) can't work — clone it:
    # git clone https://github.com/banuee/metro-shell.git ~/metro-shell
    [[ -r "$SCRIPT_DIR/shell/TopPanel.qml" && -r "$SCRIPT_DIR/bin/wall" ]] || \
        die "cannot read repo files ($SCRIPT_DIR) — clone it as your own user: git clone https://github.com/banuee/metro-shell.git ~/metro-shell"

    banner
    detect_distro
    detect_hw

    case "$mode" in
        check) check_only; return ;;
        deps) sudo -v; install_deps; return ;;
        restore) restore_menu; return ;;
    esac

    if [[ "$DISTRO" == "unknown" ]]; then
        warn "package manager not recognized — install dependencies manually (list above)"
        ask "continue with files only?" 1 || exit 0
        SKIP_DEPS=1
    fi
    (( SKIP_DEPS )) || sudo -v

    if installed; then
        menu_installed
    else
        msg "installing metro-shell"
        fresh_install
    fi
}

main "$@"
