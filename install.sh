#!/usr/bin/env bash
# install.sh — установка/обновление/восстановление metro-shell
#   ./install.sh            интерактивный режим
#   ./install.sh restore    сразу восстановить из бэкапа
#   ./install.sh --help     справка
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── вывод ────────────────────────────────────────────────────────────────
G=$'\e[1;32m'; Y=$'\e[1;33m'; R=$'\e[1;31m'; B=$'\e[1;36m'; D=$'\e[2m'; N=$'\e[0m'
msg()  { printf '%s\n' "${B}==>${N} $*"; }
ok()   { printf '%s\n' "${G} ✓${N} $*"; }
warn() { printf '%s\n' "${Y} !${N} $*"; }
err()  { printf '%s\n' "${R} ✗${N} $*" >&2; }
die()  { err "$*"; exit 1; }
# ask "вопрос" [1] — второй аргумент: ответ по умолчанию да
ask()  { local a d="${2:-0}"; read -rp "$(printf '%s' "${B}?>${N} $1 [$([[ $d = 1 ]] && printf 'Y/n' || printf 'y/N')] ")" a; a="${a:-$([[ $d = 1 ]] && echo y || echo n)}"; [[ "$a" =~ ^[YyДд] ]]; }

banner() {
    printf '%s' "$B"
    cat <<'EOF'

  __  __       _          ____  _          _ _  ____
 |  \/  | ___ | |_ ___ _ / ___|| |__   ___| | |/ ___|  ___ _ ____   _____
 | |\/| |/ _ \| __/ _ \ '\___ \| '_ \ / _ \ | |\___ \ / _ \ '__\ \ / / _ \
 | |  | | (_) | ||  __/ / ___) | | | |  __/ | | ___) |  __/ |   \ V /  __/
 |_|  |_|\___/ \__\___| |____/|_| |_|\___|_|_|____/ \___|_|    \_/ \___|

EOF
    printf '%s\n' "        quickshell · hyprland · metro live tiles$N"
}

# ── цели ─────────────────────────────────────────────────────────────────
SH_DIR="$HOME/.config/quickshell/metro"
BIN_DIR="$HOME/.local/bin"
DT_DIR="$HOME/.local/share/applications"
BACKUP_ROOT="$HOME/metro-backup"

# "<путь относительно ~/.config (или bin/ applications/)>:<источник в репо>"
ITEMS=(
    "quickshell/metro:$SCRIPT_DIR/shell"
    "quickshell/metro-settings:$SCRIPT_DIR/settings"
    "quickshell/metro-lock:$SCRIPT_DIR/lock"
    "bin/qs-metro:$SCRIPT_DIR/bin/qs-metro"
    "bin/metro-colors:$SCRIPT_DIR/bin/metro-colors"
    "bin/metro-lock:$SCRIPT_DIR/bin/metro-lock"
    "bin/metro-settings:$SCRIPT_DIR/bin/metro-settings"
    "bin/wall:$SCRIPT_DIR/bin/wall"
    "bin/wall-start:$SCRIPT_DIR/bin/wall-start"
    "applications/metro-settings.desktop:$SCRIPT_DIR/desktop/metro-settings.desktop"
    "hypr/hyprland.lua:$SCRIPT_DIR/hypr/hyprland.lua"
    "hypr/hypridle.conf:$SCRIPT_DIR/hypr/hypridle.conf"
    "mako/config:$SCRIPT_DIR/mako/config"
)

target_for_rel() {
    case "$1" in
        applications/*) echo "$DT_DIR/${1#applications/}" ;;
        bin/*)          echo "$BIN_DIR/${1#bin/}" ;;
        *)              echo "$HOME/.config/$1" ;;
    esac
}

installed() { [[ -d "$SH_DIR" ]]; }

# ── зависимости ──────────────────────────────────────────────────────────
REPO_DEPS=(
    hyprland quickshell awww hypridle mako grim
    jq curl playerctl networkmanager bluez bluez-utils
    brightnessctl pipewire wireplumber power-profiles-daemon
    matugen python-pillow papirus-icon-theme qt6-5compat
    ttf-noto-nerd polkit-gnome cliphist wl-clipboard
)
AUR_DEPS=(ttf-segoe-ui-variable)
HELPER=""

detect_helper() {
    if command -v paru >/dev/null 2>&1; then
        HELPER="paru"
    elif command -v yay >/dev/null 2>&1; then
        HELPER="yay"
    else
        warn "AUR-хелпер не найден (paru/yay)"
        if ask "установить yay через pacman?" 1; then
            sudo pacman -S --needed yay
            HELPER="yay"
        else
            warn "без хелпера AUR-пакеты будут пропущены: ${AUR_DEPS[*]}"
        fi
    fi
    [[ -n "$HELPER" ]] && ok "AUR-хелпер: $HELPER"
}

install_deps() {
    msg "[1/4] зависимости"
    detect_helper
    sudo pacman -S --needed "${REPO_DEPS[@]}"
    if [[ -n "$HELPER" && ${#AUR_DEPS[@]} -gt 0 ]]; then
        "$HELPER" -S --needed "${AUR_DEPS[@]}"
    fi
    fc-cache -f >/dev/null 2>&1 || true
    ok "зависимости на месте"
}

# ── бэкап / восстановление ───────────────────────────────────────────────
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
        warn "существующих конфигов не найдено — бэкапить нечего"
        return 1
    fi
    BACKUP_DEST="$dest"
    ok "бэкап: $dest ($n шт.)"
}

choose_backup() {
    [[ -d "$BACKUP_ROOT" ]] || die "бэкапов нет ($BACKUP_ROOT)"
    local list
    list="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '20*' | sort)"
    [[ -n "$list" ]] || die "бэкапов нет ($BACKUP_ROOT)"
    if [[ "$(echo "$list" | wc -l)" -gt 1 ]]; then
        echo "$list" | nl -w2 -s') '
        local a
        read -rp "$(printf '%s' "${B}?>${N} какой восстановить [последний]: ")" a
        [[ -n "$a" && "$a" =~ ^[0-9]+$ ]] && echo "$list" | sed -n "${a}p" || echo "$list" | tail -n1
    else
        echo "$list"
    fi
}

do_restore() {
    local src="$1" item
    msg "восстановление из $src"
    for it in "${ITEMS[@]}"; do
        local rel="${it%%:*}"
        if [[ -e "$src/$rel" ]]; then
            local dst; dst="$(target_for_rel "$rel")"
            mkdir -p "$(dirname "$dst")"
            rm -rf "$dst"
            cp -a "$src/$rel" "$dst"
            ok "восстановлено: ${dst/#$HOME/~}"
        fi
    done
    chmod +x "$BIN_DIR"/qs-metro "$BIN_DIR"/metro-colors "$BIN_DIR"/metro-lock \
             "$BIN_DIR"/metro-settings "$BIN_DIR"/wall "$BIN_DIR"/wall-start 2>/dev/null || true
    ok "готово. примени: hyprctl reload (или перелогин)"
}

restore_menu() {
    do_restore "$(choose_backup)"
}

# ── установка файлов ─────────────────────────────────────────────────────
do_install_files() {
    local clean="$1"
    msg "[2/4] файлы шелла"
    for it in "${ITEMS[@]}"; do
        local rel="${it%%:*}" src="${it#*:}"
        local dst; dst="$(target_for_rel "$rel")"
        if [[ "$clean" == yes && -e "$dst" ]]; then
            rm -rf "$dst"
        fi
        if [[ -d "$src" ]]; then
            mkdir -p "$dst"
            cp -a "$src/." "$dst/"
        else
            mkdir -p "$(dirname "$dst")"
            cp -a "$src" "$dst"
        fi
    done
    chmod +x "$BIN_DIR"/qs-metro "$BIN_DIR"/metro-colors "$BIN_DIR"/metro-lock \
             "$BIN_DIR"/metro-settings "$BIN_DIR"/wall "$BIN_DIR"/wall-start
    update-desktop-database "$DT_DIR" >/dev/null 2>&1 || true
    ok "скопировано: quickshell/metro{,-settings,-lock}, bin/, hypr/, mako/"
}

post_setup() {
    msg "[3/4] иконки"
    local cur
    cur="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || echo "''")"
    if [[ "$cur" != *Papirus-Dark* ]] && ask "тема иконок Papirus-Dark (нужна для иконок шелла)?" 1; then
        gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
        ok "иконки: Papirus-Dark"
    fi

    msg "[4/4] запуск"
    echo "  • перелогинься или: ${G}hyprctl reload${N}${D} — exec-once в hyprland.lua поднимет шелл${N}"
    echo "  • прямо сейчас: ${G}qs-metro${N}  ·  обои: ${G}wall random${N}  ·  настройки: ${G}metro-settings${N}"
    echo "  • локскрин: ${G}metro-lock${N} (hypridle лочит через 5 мин; ${D}loginctl lock-session${N} — вручную)"
    ask "запустить шелл сейчас (qs-metro)?" 1 && "$BIN_DIR/qs-metro"
}

# ── сценарии ─────────────────────────────────────────────────────────────
fresh_install() {
    if ask "сделать бэкап существующих конфигов (если найдутся)?" 1; then
        do_backup || true
    fi
    install_deps
    do_install_files no
    post_setup
    [[ -n "$BACKUP_DEST" ]] && echo "  ${D}откат в любой момент: ./install.sh restore (бэкап $BACKUP_DEST)${N}"
}

update_install() {
    install_deps
    do_install_files no
    post_setup
}

reinstall() {
    do_backup || true
    install_deps
    do_install_files yes
    post_setup
}

menu_installed() {
    echo
    echo "  metro-shell уже установлен. что делаем?"
    echo "   ${G}1${N}) обновить        ${D}— перезаписать файлы; layout.json/city.json сохранятся${N}"
    echo "   ${G}2${N}) переустановить   ${D}— бэкап, затем чистая установка (сетка/город сбросятся)${N}"
    echo "   ${G}3${N}) восстановить     ${D}— откатить всё из бэкапа ($BACKUP_ROOT)${N}"
    echo "   ${G}0${N}) выход"
    local a
    read -rp "$(printf '%s' "${B}?>${N} выбор: ")" a
    case "$a" in
        1) update_install ;;
        2) reinstall ;;
        3) restore_menu ;;
        *) echo "выход." ;;
    esac
}

usage() {
    cat <<EOF
metro-shell — установщик дотфайлов (quickshell-шелл + hyprland + mako)

  ./install.sh            интерактивный режим
  ./install.sh restore    сразу восстановить из бэкапа

Что ставится: quickshell (шелл/настройки/локскрин), утилиты в ~/.local/bin,
hyprland.lua + hypridle.conf, mako, .desktop-файл.
Зависимости: pacman --needed (+ AUR через paru/yay, при отсутствии —
предложит установить yay).
Бэкапы: $BACKUP_ROOT/<дата-время>
EOF
}

main() {
    [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
    [[ $EUID -eq 0 ]] && die "запускай от своего юзера — sudo спросится сам"
    command -v pacman >/dev/null 2>&1 || die "нужен Arch-based дистрибутив (pacman не найден)"
    [[ -d "$SCRIPT_DIR/shell" && -f "$SCRIPT_DIR/bin/wall" ]] || die "запускай из распакованного репозитория (нет shell/ или bin/)"

    banner
    sudo -v

    if [[ "${1:-}" == "restore" ]]; then
        restore_menu
        return
    fi

    if installed; then
        menu_installed
    else
        msg "установка metro-shell"
        fresh_install
    fi
}

main "$@"
