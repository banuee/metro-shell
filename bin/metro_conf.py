"""metro_conf — общая либа единого конфига metro-shell.conf.

Формат как старый hyprland.conf: key = value, секции name { }, # комменты.
Импорт: sys.path[0] уже ~/.local/bin при запуске metro-colors/metro-conf,
поэтому просто `import metro_conf` / `from metro_conf import load`.
"""
import os
import re

CONF = os.path.expanduser("~/.config/quickshell/metro-shell.conf")

DEFAULTS = {
    "theme": "metro",
    "accent": "auto",
    "panel.toppanel_bg": "0.30",
    "panel.launcher_bg": "0.30",
    "panel.control_bg": "0.30",
    "panel.toppanel_radius": "16",
    "panel.launcher_radius": "16",
    "panel.control_radius": "16",
    "settings.glass": "dark",
    "shot.theme": "own",
    "shot.accent_follow": "true",
    "fonts.family": "Segoe UI Variable Static Text",
    "fonts.headline": "Segoe UI Variable Static Display Light",
    "fonts.icon": "NotoSans Nerd Font",
    "compositor.rounding": "12",
    "compositor.blur": "true",
}


def parse(text):
    out = {}
    stack = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^([A-Za-z0-9_.-]+)\s*\{\s*(?:#.*)?$", line)
        if m:
            stack.append(m.group(1))
            continue
        if line == "}":
            if stack:
                stack.pop()
            continue
        m = re.match(r'^([A-Za-z0-9_.-]+)\s*=\s*"(.*)"\s*(?:#.*)?$', line)
        if not m:
            m = re.match(r"^([A-Za-z0-9_.-]+)\s*=\s*(\S+)(?:\s+#.*)?$", line)
        if m:
            key = ".".join(stack + [m.group(1)]) if stack else m.group(1)
            out[key] = m.group(2).strip()
    return out


def load():
    cfg = dict(DEFAULTS)
    if os.path.isfile(CONF):
        with open(CONF, encoding="utf-8") as f:
            cfg.update(parse(f.read()))
    return cfg


def conf_float(cfg, key, lo=0.0, hi=1.0):
    try:
        return max(lo, min(hi, float(cfg.get(key, DEFAULTS[key]))))
    except (ValueError, TypeError):
        return float(DEFAULTS[key])


def conf_int(cfg, key, lo=0, hi=64):
    try:
        return max(lo, min(hi, int(float(cfg.get(key, DEFAULTS[key])))))
    except (ValueError, TypeError):
        return int(DEFAULTS[key])
