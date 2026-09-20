#!/usr/bin/env python3
"""
settings_backend.py — Comprehensive system settings backend for Metro Settings
Supports:
- Hyprland input (keyboard layouts, switch shortcuts, repeat rate/delay, numlock, mouse, touchpad)
- Hyprland keybindings (catalog, search, add, delete)
- Hyprland aesthetics / window manager (gaps, rounding, border, blur, animations, layout)
- Network Manager saved Wi-Fi networks & passwords
- Network DNS (presets: DHCP, Cloudflare, Google, Quad9, AdGuard, Custom)
- System Proxy (none, manual HTTP/HTTPS/SOCKS, auto PAC)
- Network IP & interface details + public IP
- Default applications (browser, file manager, terminal, editor, video, audio, image, pdf)
- Mako notifications daemon configuration
"""

import sys
import os
import re
import json
import shlex
import ipaddress
import subprocess
import pathlib

HYPR_LUA = pathlib.Path.home() / ".config/hypr/hyprland.lua"
MAKO_CONF = pathlib.Path.home() / ".config/mako/config"
PROXY_ENV = pathlib.Path.home() / ".config/environment.d/20-proxy.conf"

def q(s):
    """Shell-quote одного аргумента. Использовать для ЛЮБОГО внешнего
    значения, вставляемого в команду для run_cmd(shell=True)."""
    return shlex.quote(str(s))

def nmcli_split(line):
    """Разбор nmcli -t по НЕэкранированным ':' (nmcli экранирует
    ':' как '\\:' и '\\' как '\\\\'). Обычный split(':') ломается
    на SSID с двоеточием."""
    parts, cur, i = [], "", 0
    while i < len(line):
        c = line[i]
        if c == "\\" and i + 1 < len(line) and line[i + 1] in (":", "\\"):
            cur += line[i + 1]
            i += 2
            continue
        if c == ":":
            parts.append(cur)
            cur = ""
        else:
            cur += c
        i += 1
    parts.append(cur)
    return parts

def lua_str(s):
    """Значение для Lua-строки в двойных кавычках: экранирует \\ и \",
    режет переводы строк (иначе breakout из литерала)."""
    return str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ").replace("\r", "")

def atomic_write(path, text):
    """Атомарная запись файла: tmp + fsync + rename. Обрезанный конфиг
    при крахе посреди write_text исключён."""
    path = pathlib.Path(path)
    tmp = path.with_name(path.name + f".tmp-{os.getpid()}")
    tmp.write_text(text)
    with open(tmp, "rb") as f:
        try:
            os.fsync(f.fileno())
        except OSError:
            pass
    os.replace(tmp, path)

def run_cmd(cmd, timeout=10):
    try:
        res = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return res.stdout.strip(), res.stderr.strip(), res.returncode
    except Exception as e:
        return "", str(e), 1

# ─────────────────────────────────────────────────────────────
# 1. INPUT SETTINGS (Keyboard, Layouts, Touchpad, Mouse)
# ─────────────────────────────────────────────────────────────

def get_input():
    if not HYPR_LUA.exists():
        return {"error": "hyprland.lua not found"}
    
    content = HYPR_LUA.read_text()
    data = {
        "kb_layout": "us,ru",
        "kb_options": "grp:alt_shift_toggle",
        "numlock_by_default": False,
        "repeat_rate": 25,
        "repeat_delay": 600,
        "follow_mouse": 1,
        "sensitivity": 0.0,
        "accel_profile": "flat",
        "natural_scroll": False,
        "left_handed": False,
        "touchpad": {
            "disable_while_typing": True,
            "tap_to_click": True,
            "tap_and_drag": True,
            "drag_lock": True,
            "natural_scroll": False,
            "middle_button_emulation": False
        }
    }
    
    m = re.search(r"hl\.config\(\{\s*input\s*=\s*\{(.*?)\}\s*,?\s*\}\)", content, re.DOTALL)
    if m:
        block = m.group(1)
        for k in ["kb_layout", "kb_options", "accel_profile"]:
            km = re.search(rf'{k}\s*=\s*"([^"]*)"', block)
            if km:
                data[k] = km.group(1)
        for k in ["numlock_by_default", "natural_scroll", "left_handed"]:
            km = re.search(rf'{k}\s*=\s*(true|false)', block)
            if km:
                data[k] = km.group(1) == "true"
        for k in ["repeat_rate", "repeat_delay", "follow_mouse"]:
            km = re.search(rf'{k}\s*=\s*(\d+)', block)
            if km:
                data[k] = int(km.group(1))
        km = re.search(r'sensitivity\s*=\s*([-\d.]+)', block)
        if km:
            data["sensitivity"] = float(km.group(1))
            
        tm = re.search(r'touchpad\s*=\s*\{(.*?)\}', block, re.DOTALL)
        if tm:
            tblock = tm.group(1)
            for k in ["disable_while_typing", "tap_to_click", "tap_and_drag", "drag_lock", "natural_scroll", "middle_button_emulation"]:
                tkm = re.search(rf'{k}\s*=\s*(true|false)', tblock)
                if tkm:
                    data["touchpad"][k] = tkm.group(1) == "true"
                    
    return data

def set_input(new_data):
    if isinstance(new_data, dict) and list(new_data.keys()) == ["error"]:
        return new_data
    if not HYPR_LUA.exists():
        return {"error": "hyprland.lua not found"}

    # Валидация строковых полей: иначе значение с кавычкой/переводом строки
    # ломает Lua-файл и вырывается из hyprctl eval '...'
    if "kb_layout" in new_data and not re.fullmatch(r"[A-Za-z0-9_,+\- ]*", str(new_data["kb_layout"])):
        return {"error": "invalid kb_layout"}
    if "kb_options" in new_data and not re.fullmatch(r"[A-Za-z0-9_,:+\- ]*", str(new_data["kb_options"])):
        return {"error": "invalid kb_options"}
    if "accel_profile" in new_data and str(new_data["accel_profile"]) not in ("", "flat", "adaptive", "custom"):
        return {"error": "invalid accel_profile"}
    # Числа — принудительно числа (иначе строка вставится в Lua-код как код)
    for k in ("repeat_rate", "repeat_delay", "follow_mouse"):
        if k in new_data:
            try:
                new_data[k] = int(new_data[k])
            except (ValueError, TypeError):
                return {"error": f"invalid {k}"}
    if "sensitivity" in new_data:
        try:
            new_data["sensitivity"] = float(new_data["sensitivity"])
        except (ValueError, TypeError):
            return {"error": "invalid sensitivity"}

    content = HYPR_LUA.read_text()
    cur = get_input()
    
    for k, v in new_data.items():
        if k == "touchpad" and isinstance(v, dict):
            cur["touchpad"].update(v)
        else:
            cur[k] = v
            
    new_block = f"""hl.config({{
    input = {{
        kb_layout        = "{lua_str(cur['kb_layout'])}",
        kb_options       = "{lua_str(cur['kb_options'])}",
        numlock_by_default = {str(cur['numlock_by_default']).lower()},
        repeat_rate      = {cur['repeat_rate']},
        repeat_delay     = {cur['repeat_delay']},
        follow_mouse     = {cur['follow_mouse']},
        sensitivity      = {cur['sensitivity']},
        accel_profile    = "{lua_str(cur['accel_profile'])}",
        natural_scroll   = {str(cur['natural_scroll']).lower()},
        left_handed      = {str(cur['left_handed']).lower()},
        touchpad = {{
            disable_while_typing   = {str(cur['touchpad']['disable_while_typing']).lower()},
            tap_to_click           = {str(cur['touchpad']['tap_to_click']).lower()},
            tap_and_drag           = {str(cur['touchpad']['tap_and_drag']).lower()},
            drag_lock               = {str(cur['touchpad']['drag_lock']).lower()},
            natural_scroll          = {str(cur['touchpad']['natural_scroll']).lower()},
            middle_button_emulation = {str(cur['touchpad']['middle_button_emulation']).lower()},
        }},
    }},
}})"""

    if re.search(r"hl\.config\(\{\s*input\s*=\s*\{(.*?)\}\s*,?\s*\}\)", content, re.DOTALL):
        updated = re.sub(r"hl\.config\(\{\s*input\s*=\s*\{(.*?)\}\s*,?\s*\}\)", new_block, content, flags=re.DOTALL)
    else:
        updated = content + "\n\n" + new_block
        
    atomic_write(HYPR_LUA, updated)

    eval_lua = f"""hl.config({{
        input = {{
            kb_layout = "{lua_str(cur['kb_layout'])}",
            kb_options = "{lua_str(cur['kb_options'])}",
            numlock_by_default = {str(cur['numlock_by_default']).lower()},
            repeat_rate = {cur['repeat_rate']},
            repeat_delay = {cur['repeat_delay']},
            sensitivity = {cur['sensitivity']},
            accel_profile = "{lua_str(cur['accel_profile'])}",
            natural_scroll = {str(cur['natural_scroll']).lower()},
            left_handed = {str(cur['left_handed']).lower()},
            touchpad = {{
                disable_while_typing = {str(cur['touchpad']['disable_while_typing']).lower()},
                tap_to_click = {str(cur['touchpad']['tap_to_click']).lower()},
                tap_and_drag = {str(cur['touchpad']['tap_and_drag']).lower()},
                drag_lock = {str(cur['touchpad']['drag_lock']).lower()},
                natural_scroll = {str(cur['touchpad']['natural_scroll']).lower()},
                middle_button_emulation = {str(cur['touchpad']['middle_button_emulation']).lower()},
            }}
        }}
    }})"""
    # весь Lua — один shell-аргумент: кавычки/переводы внутри безопасны
    run_cmd(f"hyprctl eval {q(eval_lua)}")
    return {"status": "ok", "data": cur}

# ─────────────────────────────────────────────────────────────
# 2. KEYBINDINGS
# ─────────────────────────────────────────────────────────────

def get_binds():
    if not HYPR_LUA.exists():
        return []
        
    content = HYPR_LUA.read_text()
    binds = []
    
    action_labels = {
        "chromium": ("Chromium", "apps", "\uf268"),
        "kitty": ("Kitty Terminal", "apps", "\uf120"),
        "nemo": ("Nemo (Files)", "apps", "\uf07b"),
        "steam": ("Steam", "apps", "\uf1b6"),
        "vscodium": ("VSCodium", "apps", "\uf121"),
        "metro-shot area": ("Снимок области", "tools", "\uf030"),
        "metro-shot": ("Тулбар снимка экрана", "tools", "\uf030"),
        "metro-lock": ("Блокировка экрана", "system", "\uf023"),
        "wpctl set-volume @DEFAULT_SINK@ 5%+": ("Увеличить громкость (+5%)", "media", "\uf028"),
        "wpctl set-volume @DEFAULT_SINK@ 5%-": ("Уменьшить громкость (-5%)", "media", "\uf027"),
        "wpctl set-mute @DEFAULT_SINK@ toggle": ("Заглушить звук (Mute)", "media", "\uf6a9"),
        "wpctl set-mute @DEFAULT_SOURCE@ toggle": ("Заглушить микрофон", "media", "\uf131"),
        "brightnessctl set +10%": ("Увеличить яркость (+10%)", "system", "\uf185"),
        "brightnessctl set 10%-": ("Уменьшить яркость (-10%)", "system", "\uf185"),
        "hl.dsp.exit()": ("Выход из Hyprland", "system", "\uf011"),
        "hl.dsp.window.close()": ("Закрыть активное окно", "window", "\uf00d"),
        "hl.dsp.window.cycle_next()": ("Следующее окно", "window", "\uf07e"),
        "hl.dsp.window.float({ action = \"toggle\" })": ("Переключить плавающий режим", "window", "\uf2d0"),
        "hl.dsp.window.fullscreen()": ("Полный экран (Fullscreen)", "window", "\uf065"),
        "hl.dsp.window.fullscreen({ mode = \"maximized\" })": ("Развернуть окно (Maximize)", "window", "\uf2d0"),
        "hl.dsp.workspace.toggle_special(\"magic\")": ("Специальный воркспейс magic", "workspace", "\uf0d0"),
        "hl.dsp.window.move({ workspace = \"special:minimized\" })": ("Свернуть окно в скрытые", "window", "\uf2d1"),
        "hl.dsp.workspace.toggle_special(\"minimized\")": ("Показать свёрнутые окна", "window", "\uf2d2"),
    }
    
    for idx, line in enumerate(content.splitlines()):
        s = line.strip()
        if not s.startswith("hl.bind("):
            continue
            
        m = re.match(r'hl\.bind\((.*?)\s*,\s*(.*?)(?:,\s*(\{.*?\}))?\)$', s)
        if not m:
            continue
            
        combo_raw = m.group(1).strip()
        action_raw = m.group(2).strip()
        
        combo = combo_raw.replace('mainMod .. "', 'SUPER').replace('"', '').strip()
        if combo.startswith("+ "):
            combo = "SUPER + " + combo[2:]
        if combo.endswith(" .. mainMod"):
            combo = combo[:-11] + " SUPER"
            
        cmd_str = ""
        is_custom = True
        label = "Пользовательское действие"
        category = "custom"
        glyph = "\uf11c"
        
        exec_m = re.match(r'hl\.dsp\.exec_cmd\("([^"]*)"\)', action_raw)
        if exec_m:
            cmd_str = exec_m.group(1)
            for pat, (lbl, cat, gl) in action_labels.items():
                if pat in cmd_str:
                    label = lbl
                    category = cat
                    glyph = gl
                    is_custom = False
                    break
            if is_custom:
                label = f"Команда: {cmd_str}"
                category = "apps"
                glyph = "\uf120"
        else:
            for pat, (lbl, cat, gl) in action_labels.items():
                if pat in action_raw:
                    label = lbl
                    category = cat
                    glyph = gl
                    is_custom = False
                    break
            if is_custom:
                if "focus" in action_raw:
                    label = "Навигация / Фокус окна"
                    category = "window"
                    glyph = "\uf0b2"
                elif "workspace" in action_raw:
                    label = "Переключение воркспейса"
                    category = "workspace"
                    glyph = "\uf009"
                elif "window.drag" in action_raw or "window.resize" in action_raw:
                    label = "Мышь: Перемещение / Ресайз"
                    category = "window"
                    glyph = "\uf245"
                else:
                    label = action_raw
                    category = "custom"
                    glyph = "\uf013"
                    
        binds.append({
            "id": idx,
            "line": s,
            "combo": combo,
            "action": action_raw,
            "command": cmd_str,
            "label": label,
            "category": category,
            "glyph": glyph,
            "is_custom": is_custom
        })
        
    return binds

def add_bind(mod, key, cmd):
    if not HYPR_LUA.exists():
        return {"error": "hyprland.lua not found"}

    # mod/key — только символы хоткеев, cmd — экранируем для Lua-строки
    if not re.fullmatch(r"[A-Za-z0-9_ +]*", str(mod or "")) or \
       not re.fullmatch(r"[A-Za-z0-9_+\- ]+", str(key or "")):
        return {"error": "invalid mod/key"}
    if not cmd or len(str(cmd)) > 500:
        return {"error": "invalid command"}

    content = HYPR_LUA.read_text()
    
    if mod and mod != "NONE":
        mod_clean = mod.replace("SUPER + ", "").replace("SUPER", "").strip()
        if "SUPER" in mod:
            combo_str = f'mainMod .. " + {mod_clean} + {key}"' if mod_clean else f'mainMod .. " + {key}"'
        else:
            combo_str = f'"{mod} + {key}"'
    else:
        combo_str = f'"{key}"'
        
    new_line = f'hl.bind({combo_str}, hl.dsp.exec_cmd("{lua_str(cmd)}"))'

    updated = content.rstrip() + "\n" + new_line + "\n"
    atomic_write(HYPR_LUA, updated)
    run_cmd("hyprctl reload")
    return {"status": "ok", "bind": new_line}

def remove_bind_by_line(target_line):
    if not HYPR_LUA.exists():
        return {"error": "hyprland.lua not found"}
        
    content = HYPR_LUA.read_text()
    lines = content.splitlines()
    new_lines = [l for l in lines if l.strip() != target_line.strip()]

    atomic_write(HYPR_LUA, "\n".join(new_lines) + "\n")
    run_cmd("hyprctl reload")
    return {"status": "ok"}

# ─────────────────────────────────────────────────────────────
# 3. SAVED WI-FI NETWORKS & PASSWORDS
# ─────────────────────────────────────────────────────────────

def get_saved_wifi():
    out, _, _ = run_cmd("LC_ALL=C nmcli -t -f NAME,TYPE,UUID,AUTOCONNECT connection show")
    active_out, _, _ = run_cmd("LC_ALL=C nmcli -t -f NAME,TYPE connection show --active")
    
    active_names = set()
    for l in active_out.splitlines():
        parts = nmcli_split(l)
        if len(parts) >= 2 and parts[1] == "802-11-wireless":
            active_names.add(parts[0])

    saved = []
    for l in out.splitlines():
        parts = nmcli_split(l)
        if len(parts) >= 3 and parts[1] == "802-11-wireless":
            name = parts[0]
            uuid = parts[2]
            autoconnect = parts[3] == "yes" if len(parts) > 3 else True

            pw_out, _, _ = run_cmd(f'nmcli -s -g 802-11-wireless-security.psk connection show {q(name)} 2>/dev/null')
            sec_out, _, _ = run_cmd(f'nmcli -t -f 802-11-wireless-security.key-mgmt connection show {q(name)} 2>/dev/null')
            
            sec_raw = sec_out.replace("802-11-wireless-security.key-mgmt:", "").strip()
            if "wpa-psk" in sec_raw:
                sec_type = "WPA/WPA2 Personal"
            elif "sae" in sec_raw:
                sec_type = "WPA3 Personal"
            elif "wpa-eap" in sec_raw:
                sec_type = "WPA Enterprise"
            elif "none" in sec_raw or not sec_raw:
                sec_type = "Открытая (Open)"
            else:
                sec_type = sec_raw.upper()
                
            if not pw_out.strip():
                pw_wep, _, _ = run_cmd(f'nmcli -s -g 802-11-wireless-security.wep-key0 connection show {q(name)} 2>/dev/null')
                password = pw_wep.strip()
            else:
                password = pw_out.strip()
                
            saved.append({
                "name": name,
                "uuid": uuid,
                "autoconnect": autoconnect,
                "security": sec_type,
                "password": password,
                "active": name in active_names
            })
            
    saved.sort(key=lambda x: (not x["active"], x["name"].lower()))
    return saved

def set_wifi_autoconnect(name, enable):
    val = "yes" if enable else "no"
    out, err, code = run_cmd(f'nmcli connection modify {q(name)} connection.autoconnect {val}')
    return {"status": "ok" if code == 0 else "error", "message": err or out}

def forget_wifi(name):
    out, err, code = run_cmd(f'nmcli connection delete id {q(name)}')
    return {"status": "ok" if code == 0 else "error", "message": err or out}

# ─────────────────────────────────────────────────────────────
# 4. NETWORK DNS
# ─────────────────────────────────────────────────────────────

def get_dns_info():
    conn_out, _, _ = run_cmd("LC_ALL=C nmcli -t -f NAME,TYPE,DEVICE connection show --active | grep -E ':802-11-wireless:|:802-3-ethernet:' | head -n1")
    conn_name = ""
    dev_name = ""
    if conn_out:
        parts = nmcli_split(conn_out)
        conn_name = parts[0]
        dev_name = parts[2] if len(parts) > 2 else ""

    dns_configured = ""
    ignore_auto = False
    if conn_name:
        dns_out, _, _ = run_cmd(f'LC_ALL=C nmcli -s -g ipv4.dns connection show {q(conn_name)} 2>/dev/null')
        dns_configured = dns_out.strip()
        auto_out, _, _ = run_cmd(f'LC_ALL=C nmcli -s -g ipv4.ignore-auto-dns connection show {q(conn_name)} 2>/dev/null')
        ignore_auto = auto_out.strip() == "yes"

    active_dns = []
    sys_dns, _, _ = run_cmd("LC_ALL=C nmcli -t -f IP4.DNS dev show 2>/dev/null | grep -E '^IP4\\.DNS' | cut -d: -f2")
    for d in sys_dns.splitlines():
        if d.strip() and d.strip() not in active_dns:
            active_dns.append(d.strip())
            
    dns_servers = [s.strip() for s in dns_configured.replace(",", " ").split() if s.strip()]
    mode = "dhcp"
    if ignore_auto and dns_servers:
        s_set = set(dns_servers)
        if s_set == {"1.1.1.1", "1.0.0.1"} or s_set == {"1.1.1.1"}:
            mode = "cloudflare"
        elif s_set == {"8.8.8.8", "8.8.4.4"} or s_set == {"8.8.8.8"}:
            mode = "google"
        elif s_set == {"9.9.9.9", "149.112.112.112"} or s_set == {"9.9.9.9"}:
            mode = "quad9"
        elif s_set == {"94.140.14.14", "94.140.15.15"} or s_set == {"94.140.14.14"}:
            mode = "adguard"
        elif s_set == {"208.67.222.222", "208.67.220.220"}:
            mode = "opendns"
        else:
            mode = "custom"
            
    return {
        "connection": conn_name,
        "device": dev_name,
        "mode": mode,
        "configured_servers": dns_servers,
        "active_servers": active_dns,
        "ignore_auto": ignore_auto
    }

def set_dns(conn_name, mode, custom_primary="", custom_secondary=""):
    if not conn_name:
        info = get_dns_info()
        conn_name = info["connection"]
        if not conn_name:
            return {"status": "error", "message": "No active network connection"}
            
    presets = {
        "cloudflare": "1.1.1.1 1.0.0.1",
        "google": "8.8.8.8 8.8.4.4",
        "quad9": "9.9.9.9 149.112.112.112",
        "adguard": "94.140.14.14 94.140.15.15",
        "opendns": "208.67.222.222 208.67.220.220",
    }
    
    if mode == "dhcp":
        cmd = f'nmcli connection modify {q(conn_name)} ipv4.dns "" ipv4.ignore-auto-dns no && nmcli connection up {q(conn_name)}'
    elif mode in presets:
        servers = presets[mode]
        cmd = f'nmcli connection modify {q(conn_name)} ipv4.dns {q(servers)} ipv4.ignore-auto-dns yes && nmcli connection up {q(conn_name)}'
    elif mode == "custom":
        servers = f"{custom_primary} {custom_secondary}".strip()
        if not servers:
            return {"status": "error", "message": "Please specify at least one DNS server"}
        # каждый DNS обязан быть валидным IP — иначе отказ (заодно закрывает инъекцию)
        for s in servers.split():
            try:
                ipaddress.ip_address(s)
            except ValueError:
                return {"status": "error", "message": f"Invalid DNS server: {s}"}
        cmd = f'nmcli connection modify {q(conn_name)} ipv4.dns {q(servers)} ipv4.ignore-auto-dns yes && nmcli connection up {q(conn_name)}'
    else:
        return {"status": "error", "message": f"Unknown DNS mode: {mode}"}
        
    out, err, code = run_cmd(cmd)
    return {"status": "ok" if code == 0 else "error", "message": err or out}

# ─────────────────────────────────────────────────────────────
# 5. SYSTEM PROXY
# ─────────────────────────────────────────────────────────────

def get_proxy():
    mode_out, _, _ = run_cmd("gsettings get org.gnome.system.proxy mode")
    mode = mode_out.replace("'", "").strip() if mode_out else "none"
    
    http_host, _, _ = run_cmd("gsettings get org.gnome.system.proxy.http host")
    http_port, _, _ = run_cmd("gsettings get org.gnome.system.proxy.http port")
    https_host, _, _ = run_cmd("gsettings get org.gnome.system.proxy.https host")
    https_port, _, _ = run_cmd("gsettings get org.gnome.system.proxy.https port")
    socks_host, _, _ = run_cmd("gsettings get org.gnome.system.proxy.socks host")
    socks_port, _, _ = run_cmd("gsettings get org.gnome.system.proxy.socks port")
    auto_url, _, _ = run_cmd("gsettings get org.gnome.system.proxy autoconfig-url")
    ignore_hosts, _, _ = run_cmd("gsettings get org.gnome.system.proxy ignore-hosts")
    
    return {
        "mode": mode,
        "http_host": http_host.replace("'", "").strip(),
        "http_port": int(http_port.strip()) if http_port.strip().isdigit() else 8080,
        "https_host": https_host.replace("'", "").strip(),
        "https_port": int(https_port.strip()) if https_port.strip().isdigit() else 8080,
        "socks_host": socks_host.replace("'", "").strip(),
        "socks_port": int(socks_port.strip()) if socks_port.strip().isdigit() else 1080,
        "autoconfig_url": auto_url.replace("'", "").strip(),
        "ignore_hosts": ignore_hosts.strip() or "['localhost', '127.0.0.0/8', '::1']"
    }

def set_proxy(data):
    if isinstance(data, dict) and list(data.keys()) == ["error"]:
        return data
    mode = data.get("mode", "none")
    if mode not in ("none", "manual", "auto"):
        return {"status": "error", "message": f"Unknown proxy mode: {mode}"}

    def clean_host(v):
        v = str(v or "").strip()
        if v and not re.fullmatch(r"[A-Za-z0-9.\-]+", v):
            raise ValueError(f"Invalid proxy host: {v}")
        return v

    def clean_port(v, default):
        try:
            p = int(v)
        except (ValueError, TypeError):
            raise ValueError(f"Invalid proxy port: {v}")
        if not 1 <= p <= 65535:
            raise ValueError(f"Invalid proxy port: {v}")
        return p

    try:
        cmds = [f"gsettings set org.gnome.system.proxy mode {q(mode)}"]

        if mode == "manual":
            if "http_host" in data:
                host = clean_host(data["http_host"])
                cmds.append(f"gsettings set org.gnome.system.proxy.http host {q(host)}")
            if "http_port" in data:
                cmds.append(f"gsettings set org.gnome.system.proxy.http port {clean_port(data['http_port'], 8080)}")
            if "https_host" in data:
                host = clean_host(data["https_host"])
                cmds.append(f"gsettings set org.gnome.system.proxy.https host {q(host)}")
            if "https_port" in data:
                cmds.append(f"gsettings set org.gnome.system.proxy.https port {clean_port(data['https_port'], 8080)}")
            if "socks_host" in data:
                host = clean_host(data["socks_host"])
                cmds.append(f"gsettings set org.gnome.system.proxy.socks host {q(host)}")
            if "socks_port" in data:
                cmds.append(f"gsettings set org.gnome.system.proxy.socks port {clean_port(data['socks_port'], 1080)}")

            PROXY_ENV.parent.mkdir(parents=True, exist_ok=True)
            env_lines = []
            if data.get("http_host"):
                hp = f"http://{clean_host(data['http_host'])}:{clean_port(data.get('http_port', 8080), 8080)}"
                env_lines.append(f"http_proxy={hp}")
                env_lines.append(f"HTTP_PROXY={hp}")
            if data.get("https_host"):
                hsp = f"http://{clean_host(data['https_host'])}:{clean_port(data.get('https_port', 8080), 8080)}"
                env_lines.append(f"https_proxy={hsp}")
                env_lines.append(f"HTTPS_PROXY={hsp}")
            if data.get("socks_host"):
                sp = f"socks5://{clean_host(data['socks_host'])}:{clean_port(data.get('socks_port', 1080), 1080)}"
                env_lines.append(f"all_proxy={sp}")
                env_lines.append(f"ALL_PROXY={sp}")
            env_lines.append("no_proxy=localhost,127.0.0.1,localaddress,.localdomain.host")
            env_lines.append("NO_PROXY=localhost,127.0.0.1,localaddress,.localdomain.host")
            atomic_write(PROXY_ENV, "\n".join(env_lines) + "\n")
        elif mode == "none":
            if PROXY_ENV.exists():
                PROXY_ENV.unlink()
        elif mode == "auto" and data.get("autoconfig_url"):
            pac = str(data["autoconfig_url"]).strip()
            if not re.fullmatch(r"https?://[A-Za-z0-9.\-/:_?&=+%#;@~]+", pac):
                raise ValueError(f"Invalid PAC URL: {pac}")
            cmds.append(f"gsettings set org.gnome.system.proxy autoconfig-url {q(pac)}")
    except ValueError as e:
        return {"status": "error", "message": str(e)}

    full_cmd = "; ".join(cmds)
    out, err, code = run_cmd(full_cmd)
    return {"status": "ok" if code == 0 else "error", "message": err or out}

# ─────────────────────────────────────────────────────────────
# 6. NETWORK INTERFACES & PUBLIC IP
# ─────────────────────────────────────────────────────────────

def get_net_details():
    route_out, _, _ = run_cmd("ip -j route show default")
    gateway = "—"
    active_dev = "—"
    try:
        r_json = json.loads(route_out)
        if r_json:
            gateway = r_json[0].get("gateway", "—")
            active_dev = r_json[0].get("dev", "—")
    except:
        pass
        
    addr_out, _, _ = run_cmd("ip -j addr show")
    interfaces = []
    ipv4 = "—"
    ipv6 = "—"
    mac = "—"
    
    try:
        a_json = json.loads(addr_out)
        for iface in a_json:
            name = iface.get("ifname", "")
            if name == "lo":
                continue
            if_mac = iface.get("address", "")
            if_ip4 = ""
            if_ip6 = ""
            for a in iface.get("addr_info", []):
                if a.get("family") == "inet" and not if_ip4:
                    if_ip4 = f"{a.get('local')}/{a.get('prefixlen')}"
                elif a.get("family") == "inet6" and not if_ip6:
                    if_ip6 = a.get("local")
                    
            is_active = (name == active_dev) or (iface.get("operstate") == "UP" and bool(if_ip4))
            if is_active and ipv4 == "—" and if_ip4:
                ipv4 = if_ip4
                ipv6 = if_ip6 or "—"
                mac = if_mac
                
            interfaces.append({
                "name": name,
                "state": iface.get("operstate", "DOWN"),
                "mac": if_mac,
                "ipv4": if_ip4 or "—",
                "ipv6": if_ip6 or "—",
                "active": is_active
            })
    except:
        pass
        
    return {
        "active_device": active_dev,
        "gateway": gateway,
        "ipv4": ipv4,
        "ipv6": ipv6,
        "mac": mac,
        "interfaces": interfaces
    }

def get_public_ip():
    ip, _, code = run_cmd("curl -s -m 3 https://api.ipify.org || curl -s -m 3 https://ifconfig.me")
    ip = ip.strip()
    # без проверки сюда могла попасть HTML-страница ошибки
    if code == 0 and re.fullmatch(r"[0-9a-fA-F.:]+", ip or ""):
        try:
            ipaddress.ip_address(ip)
            return {"public_ip": ip}
        except ValueError:
            pass
    return {"public_ip": "—"}

# ─────────────────────────────────────────────────────────────
# 7. DEFAULT APPLICATIONS
# ─────────────────────────────────────────────────────────────

def get_installed_apps():
    dirs = [pathlib.Path("/usr/share/applications"), pathlib.Path.home() / ".local/share/applications"]
    apps = {}
    for d in dirs:
        if not d.exists():
            continue
        for f in d.glob("*.desktop"):
            try:
                txt = f.read_text(errors="ignore")
                name_m = re.search(r"^Name\s*=\s*(.+)$", txt, re.MULTILINE)
                icon_m = re.search(r"^Icon\s*=\s*(.+)$", txt, re.MULTILINE)
                mime_m = re.search(r"^MimeType\s*=\s*(.+)$", txt, re.MULTILINE)
                exec_m = re.search(r"^Exec\s*=\s*(.+)$", txt, re.MULTILINE)
                no_disp = re.search(r"^NoDisplay\s*=\s*true", txt, re.MULTILINE)
                
                if no_disp:
                    continue
                    
                name = name_m.group(1).strip() if name_m else f.stem
                icon = icon_m.group(1).strip() if icon_m else ""
                mimes = [m.strip() for m in mime_m.group(1).split(";") if m.strip()] if mime_m else []
                
                apps[f.name] = {
                    "id": f.name,
                    "name": name,
                    "icon": icon,
                    "mimes": mimes,
                    "exec": exec_m.group(1).strip() if exec_m else ""
                }
            except:
                pass
    return apps

def get_default_apps():
    apps = get_installed_apps()
    
    browser_def, _, _ = run_cmd("xdg-settings get default-web-browser")
    fm_def, _, _ = run_cmd("xdg-mime query default inode/directory")
    editor_def, _, _ = run_cmd("xdg-mime query default text/plain")
    video_def, _, _ = run_cmd("xdg-mime query default video/mp4")
    audio_def, _, _ = run_cmd("xdg-mime query default audio/mpeg")
    image_def, _, _ = run_cmd("xdg-mime query default image/png")
    pdf_def, _, _ = run_cmd("xdg-mime query default application/pdf")
    
    # Filter candidates accurately
    def has_any_mime(a, target_mimes):
        return any(tm in a["mimes"] for tm in target_mimes)
        
    def match_names(a, keywords):
        lower_id = a["id"].lower()
        lower_name = a["name"].lower()
        return any(k in lower_id or k in lower_name for k in keywords)

    categories = [
        {
            "id": "browser",
            "label": "Веб-браузер",
            "glyph": "\uf268",
            "default": browser_def.strip(),
            "mime": "x-scheme-handler/http",
            "candidates": [a for a in apps.values() if has_any_mime(a, ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"]) or match_names(a, ["browser", "chrome", "firefox", "chromium", "brave", "zen", "opera", "edge"])]
        },
        {
            "id": "file_manager",
            "label": "Файловый менеджер",
            "glyph": "\uf07b",
            "default": fm_def.strip(),
            "mime": "inode/directory",
            "candidates": [a for a in apps.values() if has_any_mime(a, ["inode/directory"]) or match_names(a, ["nemo", "nautilus", "dolphin", "thunar", "pcmanfm", "files"])]
        },
        {
            "id": "text_editor",
            "label": "Текстовый редактор",
            "glyph": "\uf121",
            "default": editor_def.strip(),
            "mime": "text/plain",
            "candidates": [a for a in apps.values() if (has_any_mime(a, ["text/plain", "text/markdown"]) or match_names(a, ["code", "codium", "kate", "gedit", "mousepad", "kwrite", "text", "nvim", "sublime", "micro"])) and not match_names(a, ["browser", "chrome", "firefox", "chromium"])]
        },
        {
            "id": "video_player",
            "label": "Видеоплеер",
            "glyph": "\uf03d",
            "default": video_def.strip(),
            "mime": "video/mp4",
            "candidates": [a for a in apps.values() if has_any_mime(a, ["video/mp4", "video/mkv", "video/webm"]) or match_names(a, ["mpv", "vlc", "celluloid", "totem", "haruna", "kodi", "video"])]
        },
        {
            "id": "audio_player",
            "label": "Аудиоплеер",
            "glyph": "\uf025",
            "default": audio_def.strip(),
            "mime": "audio/mpeg",
            "candidates": [a for a in apps.values() if has_any_mime(a, ["audio/mpeg", "audio/flac", "audio/ogg"]) or match_names(a, ["amberol", "audacious", "rhythmbox", "music", "spotify", "elisa", "clementine"])]
        },
        {
            "id": "image_viewer",
            "label": "Просмотр изображений",
            "glyph": "\uf03e",
            "default": image_def.strip(),
            "mime": "image/png",
            "candidates": [a for a in apps.values() if has_any_mime(a, ["image/png", "image/jpeg", "image/webp"]) or match_names(a, ["loupe", "imv", "gwenview", "eog", "viewnior", "qimgv", "feh", "nomacs", "ristretto"])]
        },
        {
            "id": "pdf_viewer",
            "label": "Просмотр документов (PDF)",
            "glyph": "\uf1c1",
            "default": pdf_def.strip(),
            "mime": "application/pdf",
            "candidates": [a for a in apps.values() if has_any_mime(a, ["application/pdf"]) or match_names(a, ["evince", "okular", "zathura", "pdf", "papers", "atril"])]
        }
    ]
    
    return categories

def set_default_app(cat_id, desktop_id):
    # desktop_id — имя файла из ~/.local/share/applications, без валидации
    # сюда ложится что угодно ("evil\";reboot;echo \".desktop")
    if not re.fullmatch(r"[A-Za-z0-9_@.+\-]+\.desktop", str(desktop_id or "")):
        return {"status": "error", "message": f"Invalid desktop file: {desktop_id}"}
    d = q(desktop_id)
    if cat_id == "browser":
        out, err, code = run_cmd(f"xdg-settings set default-web-browser {d}")
        run_cmd(f"xdg-mime default {d} x-scheme-handler/http x-scheme-handler/https text/html")
    elif cat_id == "file_manager":
        out, err, code = run_cmd(f"xdg-mime default {d} inode/directory")
    elif cat_id == "text_editor":
        out, err, code = run_cmd(f"xdg-mime default {d} text/plain text/markdown text/x-c text/x-python")
    elif cat_id == "video_player":
        out, err, code = run_cmd(f"xdg-mime default {d} video/mp4 video/mkv video/webm video/x-matroska video/quicktime")
    elif cat_id == "audio_player":
        out, err, code = run_cmd(f"xdg-mime default {d} audio/mpeg audio/flac audio/ogg audio/x-wav audio/aac")
    elif cat_id == "image_viewer":
        out, err, code = run_cmd(f"xdg-mime default {d} image/png image/jpeg image/webp image/gif image/bmp image/svg+xml")
    elif cat_id == "pdf_viewer":
        out, err, code = run_cmd(f"xdg-mime default {d} application/pdf")
    else:
        return {"status": "error", "message": f"Unknown category {cat_id}"}
        
    return {"status": "ok" if code == 0 else "error", "message": err or out}

# ─────────────────────────────────────────────────────────────
# 8. WINDOW MANAGER & AESTHETICS (Hyprland decoration/general)
# ─────────────────────────────────────────────────────────────

def extract_table(content, table_name):
    m = re.search(rf"\b{table_name}\s*=\s*\{{", content)
    if not m:
        return None
    start = m.start()
    brace_start = m.end() - 1
    depth = 0
    i = brace_start
    while i < len(content):
        if content[i] == '{':
            depth += 1
        elif content[i] == '}':
            depth -= 1
            if depth == 0:
                return (start, i + 1, content[start:i+1])
        i += 1
    return None

def get_wm_config():
    if not HYPR_LUA.exists():
        return {}
    content = HYPR_LUA.read_text()
    
    data = {
        "gaps_in": 10,
        "gaps_out": 10,
        "border_size": 0,
        "rounding": 20,
        "layout": "dwindle",
        "blur_enabled": True,
        "blur_size": 3,
        "blur_passes": 3,
        "blur_vibrancy": 0.55,
        "shadow_enabled": False,
        "animations_enabled": True,
        "animation_speed": 3.5
    }
    
    gt = extract_table(content, "general")
    if gt:
        gb = gt[2]
        for k in ["gaps_in", "gaps_out", "border_size"]:
            m = re.search(rf"\b{k}\s*=\s*(\d+)", gb)
            if m: data[k] = int(m.group(1))
        lm = re.search(r'\blayout\s*=\s*"([^"]*)"', gb)
        if lm: data["layout"] = lm.group(1)
        
    dt = extract_table(content, "decoration")
    if dt:
        db = dt[2]
        rm = re.search(r"\brounding\s*=\s*(\d+)", db)
        if rm: data["rounding"] = int(rm.group(1))
        
        bt = extract_table(db, "blur")
        if bt:
            bb = bt[2]
            em = re.search(r"\benabled\s*=\s*(true|false)", bb)
            if em: data["blur_enabled"] = em.group(1) == "true"
            sm = re.search(r"\bsize\s*=\s*(\d+)", bb)
            if sm: data["blur_size"] = int(sm.group(1))
            pm = re.search(r"\bpasses\s*=\s*(\d+)", bb)
            if pm: data["blur_passes"] = int(pm.group(1))
            vm = re.search(r"\bvibrancy\s*=\s*([\d.]+)", bb)
            if vm: data["blur_vibrancy"] = float(vm.group(1))
            
    am = re.search(r"animations\s*=\s*\{\s*enabled\s*=\s*(true|false)\s*\}", content)
    if am:
        data["animations_enabled"] = am.group(1) == "true"
        
    sp_m = re.search(r'leaf\s*=\s*"windows",\s*enabled\s*=\s*true,\s*speed\s*=\s*([\d.]+)', content)
    if sp_m:
        data["animation_speed"] = float(sp_m.group(1))
        
    return data

def set_wm_config(new_data):
    if isinstance(new_data, dict) and list(new_data.keys()) == ["error"]:
        return new_data
    if not HYPR_LUA.exists():
        return {"error": "hyprland.lua not found"}
    content = HYPR_LUA.read_text()
    cur = get_wm_config()
    cur.update(new_data)

    # Числа — принудительно числа, флаги — bool, layout — Lua-строка.
    # Иначе строка из JSON вставится в Lua-код как код.
    for k in ("gaps_in", "gaps_out", "border_size", "rounding", "blur_size", "blur_passes"):
        try:
            cur[k] = int(cur[k])
        except (ValueError, TypeError):
            return {"error": f"invalid {k}"}
    try:
        cur["animation_speed"] = float(cur["animation_speed"])
    except (ValueError, TypeError):
        return {"error": "invalid animation_speed"}
    for k in ("blur_enabled", "animations_enabled"):
        v = cur[k]
        cur[k] = v if isinstance(v, bool) else str(v).lower() == "true"
    layout_lua = lua_str(cur.get("layout", "dwindle"))

    # 1. Update general block
    gt = extract_table(content, "general")
    if gt:
        start, end, gb = gt
        gb = re.sub(r"\bgaps_in\s*=\s*\d+", f"gaps_in     = {cur['gaps_in']}", gb)
        gb = re.sub(r"\bgaps_out\s*=\s*\d+", f"gaps_out    = {cur['gaps_out']}", gb)
        gb = re.sub(r"\bborder_size\s*=\s*\d+", f"border_size       = {cur['border_size']}", gb)
        # lambda-замена: иначе \ в строке съестся re.sub как escape
        gb = re.sub(r'\blayout\s*=\s*"[^"]*"', lambda m: f'layout        = "{layout_lua}"', gb)
        content = content[:start] + gb + content[end:]
    
    # 2. Update decoration block
    dt = extract_table(content, "decoration")
    if dt:
        start, end, db = dt
        db = re.sub(r"\brounding\s*=\s*\d+", f"rounding       = {cur['rounding']}", db)
        
        # blur sub-block
        bt = extract_table(db, "blur")
        if bt:
            bstart, bend, bb = bt
            bb = re.sub(r"\benabled\s*=\s*(true|false)", f"enabled    = {str(cur['blur_enabled']).lower()}", bb)
            bb = re.sub(r"\bsize\s*=\s*\d+", f"size       = {cur['blur_size']}", bb)
            bb = re.sub(r"\bpasses\s*=\s*\d+", f"passes     = {cur['blur_passes']}", bb)
            db = db[:bstart] + bb + db[bend:]
        content = content[:start] + db + content[end:]
    
    # 3. Update animations
    content = re.sub(r"animations\s*=\s*\{\s*enabled\s*=\s*(true|false)\s*\}", f"animations = {{ enabled = {str(cur['animations_enabled']).lower()} }}", content)
    content = re.sub(r'(leaf\s*=\s*"windows",\s*enabled\s*=\s*true,\s*speed\s*=\s*)[\d.]+', rf'\g<1>{cur["animation_speed"]}', content)
    
    atomic_write(HYPR_LUA, content)

    # 4. Sync shell tile radius & panel radius if rounding changed
    new_rounding = int(cur.get('rounding', 16))
    for tpath in [
        pathlib.Path.home() / ".config/quickshell/metro/Theme.qml",
        pathlib.Path.home() / ".config/quickshell/metro-settings/Theme.qml",
        pathlib.Path.home() / ".config/quickshell/metro-shot/Theme.qml",
        pathlib.Path.home() / ".config/quickshell/metro-lock/Theme.qml",
    ]:
        if tpath.exists():
            try:
                tcontent = tpath.read_text()
                tcontent = re.sub(r'readonly property int radius:\s*\d+', f'readonly property int radius: {max(0, new_rounding - 4 if new_rounding > 4 else new_rounding)}', tcontent)
                tcontent = re.sub(r'readonly property int radiusSmall:\s*\d+', f'readonly property int radiusSmall: {max(0, new_rounding - 6 if new_rounding > 6 else (0 if new_rounding == 0 else 4))}', tcontent)
                tcontent = re.sub(r'readonly property int panelRadius:\s*\d+', f'readonly property int panelRadius: {new_rounding}', tcontent)
                atomic_write(tpath, tcontent)
            except Exception:
                pass
    
    eval_lua = f"""hl.config({{
        general = {{
            gaps_in = {cur['gaps_in']},
            gaps_out = {cur['gaps_out']},
            border_size = {cur['border_size']},
            layout = "{layout_lua}"
        }},
        decoration = {{
            rounding = {cur['rounding']},
            blur = {{
                enabled = {str(cur['blur_enabled']).lower()},
                size = {cur['blur_size']},
                passes = {cur['blur_passes']}
            }}
        }},
        animations = {{ enabled = {str(cur['animations_enabled']).lower()} }}
    }})"""
    run_cmd(f"hyprctl eval {q(eval_lua)}")
    return {"status": "ok", "data": cur}

# ─────────────────────────────────────────────────────────────
# 9. NOTIFICATIONS (MAKO)
# ─────────────────────────────────────────────────────────────

def get_mako_config():
    data = {
        "timeout": 6000,
        "anchor": "top-right",
        "max_visible": 3,
        "dnd": False
    }
    
    mode_out, _, _ = run_cmd("makoctl mode")
    data["dnd"] = "dnd" in mode_out.lower()
    
    if MAKO_CONF.exists():
        txt = MAKO_CONF.read_text()
        tm = re.search(r"^default-timeout\s*=\s*(\d+)", txt, re.MULTILINE)
        if tm: data["timeout"] = int(tm.group(1))
        am = re.search(r"^anchor\s*=\s*(.+)$", txt, re.MULTILINE)
        if am: data["anchor"] = am.group(1).strip()
        vm = re.search(r"^max-visible\s*=\s*(\d+)", txt, re.MULTILINE)
        if vm: data["max_visible"] = int(vm.group(1))
        
    return data

def set_mako_config(new_data):
    if isinstance(new_data, dict) and list(new_data.keys()) == ["error"]:
        return new_data
    if not MAKO_CONF.exists():
        return {"error": "mako config not found"}
    txt = MAKO_CONF.read_text()
    
    if "timeout" in new_data:
        try:
            timeout_v = int(new_data["timeout"])
        except (ValueError, TypeError):
            return {"error": "invalid timeout"}
        txt = re.sub(r"^default-timeout\s*=\s*\d+", f"default-timeout={timeout_v}", txt, flags=re.MULTILINE)
    if "anchor" in new_data:
        anchor = str(new_data["anchor"]).strip()
        if anchor not in ("top", "top-right", "top-center", "top-left", "bottom",
                          "bottom-right", "bottom-center", "bottom-left", "center"):
            return {"error": f"invalid anchor: {anchor}"}
        txt = re.sub(r"^anchor\s*=\s*.+$", f"anchor={anchor}", txt, flags=re.MULTILINE)
    if "max_visible" in new_data:
        try:
            max_v = int(new_data["max_visible"])
        except (ValueError, TypeError):
            return {"error": "invalid max_visible"}
        txt = re.sub(r"^max-visible\s*=\s*\d+", f"max-visible={max_v}", txt, flags=re.MULTILINE)
    if "dnd" in new_data:
        if new_data["dnd"]:
            run_cmd("makoctl mode -a dnd")
        else:
            run_cmd("makoctl mode -r dnd")

    atomic_write(MAKO_CONF, txt)
    run_cmd("makoctl reload")
    return {"status": "ok"}

# ─────────────────────────────────────────────────────────────
# CLI DISPATCHER
# ─────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No action specified"}))
        return

    def json_arg(i, default=None):
        try:
            return json.loads(sys.argv[i]) if len(sys.argv) > i else default
        except (json.JSONDecodeError, IndexError):
            return {"error": "invalid JSON argument"}

    action = sys.argv[1]

    if action == "input":
        sub = sys.argv[2] if len(sys.argv) > 2 else "get"
        if sub == "get":
            print(json.dumps(get_input()))
        elif sub == "set":
            print(json.dumps(set_input(json_arg(3, {}))))
        else:
            print(json.dumps({"error": f"unknown input subcommand: {sub}"}))

    elif action == "binds":
        sub = sys.argv[2] if len(sys.argv) > 2 else "get"
        if sub == "get":
            print(json.dumps(get_binds()))
        elif sub == "add":
            # QML шлёт 2 аргумента: binds add "<MOD + KEY>" "<cmd>"
            # (старый CLI-формат с 3 аргументами тоже принимаем)
            rest = sys.argv[3:]
            if len(rest) >= 3:
                mod, key, cmd = rest[0], rest[1], rest[2]
            elif len(rest) == 2:
                combo, cmd = rest
                parts = [p.strip() for p in combo.split("+")]
                key = parts[-1] if parts else ""
                mod = " + ".join(parts[:-1])
                mod = "NONE" if not mod else mod
            else:
                print(json.dumps({"error": "binds add needs <mod> <key> <cmd> or <combo> <cmd>"}))
                return
            print(json.dumps(add_bind(mod, key, cmd)))
        elif sub == "remove" or sub == "del":
            line = sys.argv[3] if len(sys.argv) > 3 else ""
            print(json.dumps(remove_bind_by_line(line)))
        else:
            print(json.dumps({"error": f"unknown binds subcommand: {sub}"}))

    elif action == "wifi":
        sub = sys.argv[2] if len(sys.argv) > 2 else "saved"
        if sub == "saved":
            print(json.dumps(get_saved_wifi()))
        elif sub == "autoconnect":
            if len(sys.argv) < 5:
                print(json.dumps({"error": "wifi autoconnect needs <name> <true|false>"}))
            else:
                val = sys.argv[4] == "true" or sys.argv[4] == "1" or sys.argv[4] == "yes"
                print(json.dumps(set_wifi_autoconnect(sys.argv[3], val)))
        elif sub == "forget":
            if len(sys.argv) < 4:
                print(json.dumps({"error": "wifi forget needs <name>"}))
            else:
                print(json.dumps(forget_wifi(sys.argv[3])))
        else:
            print(json.dumps({"error": f"unknown wifi subcommand: {sub}"}))

    elif action == "dns":
        sub = sys.argv[2] if len(sys.argv) > 2 else "get"
        if sub == "get":
            print(json.dumps(get_dns_info()))
        elif sub == "set":
            conn = sys.argv[3] if len(sys.argv) > 3 else ""
            mode = sys.argv[4] if len(sys.argv) > 4 else "dhcp"
            p = sys.argv[5] if len(sys.argv) > 5 else ""
            s = sys.argv[6] if len(sys.argv) > 6 else ""
            print(json.dumps(set_dns(conn, mode, p, s)))
        else:
            print(json.dumps({"error": f"unknown dns subcommand: {sub}"}))

    elif action == "proxy":
        sub = sys.argv[2] if len(sys.argv) > 2 else "get"
        if sub == "get":
            print(json.dumps(get_proxy()))
        elif sub == "set":
            print(json.dumps(set_proxy(json_arg(3, {}))))
        else:
            print(json.dumps({"error": f"unknown proxy subcommand: {sub}"}))

    elif action == "net":
        sub = sys.argv[2] if len(sys.argv) > 2 else "info"
        if sub == "info":
            print(json.dumps(get_net_details()))
        elif sub == "public-ip":
            print(json.dumps(get_public_ip()))
        else:
            print(json.dumps({"error": f"unknown net subcommand: {sub}"}))

    elif action == "apps":
        sub = sys.argv[2] if len(sys.argv) > 2 else "get"
        if sub == "get":
            print(json.dumps(get_default_apps()))
        elif sub == "set":
            cat = sys.argv[3] if len(sys.argv) > 3 else ""
            desktop = sys.argv[4] if len(sys.argv) > 4 else ""
            print(json.dumps(set_default_app(cat, desktop)))
        else:
            print(json.dumps({"error": f"unknown apps subcommand: {sub}"}))

    elif action == "wm":
        sub = sys.argv[2] if len(sys.argv) > 2 else "get"
        if sub == "get":
            print(json.dumps(get_wm_config()))
        elif sub == "set":
            print(json.dumps(set_wm_config(json_arg(3, {}))))
        else:
            print(json.dumps({"error": f"unknown wm subcommand: {sub}"}))

    elif action == "sys":
        print(json.dumps(get_sys_info()))
    elif action == "mako":
        sub = sys.argv[2] if len(sys.argv) > 2 else "get"
        if sub == "get":
            print(json.dumps(get_mako_config()))
        elif sub == "set":
            print(json.dumps(set_mako_config(json_arg(3, {}))))
        else:
            print(json.dumps({"error": f"unknown mako subcommand: {sub}"}))

    elif action == "theme":
        sub = sys.argv[2] if len(sys.argv) > 2 else "get"
        if sub == "get":
            print(json.dumps(get_theme_info()))
        elif sub == "list":
            print(json.dumps(get_theme_info()["themes"]))
        elif sub == "set":
            tid = sys.argv[3] if len(sys.argv) > 3 else "nothing"
            acc = sys.argv[4] if len(sys.argv) > 4 else None
            print(json.dumps(set_theme_backend(tid, acc)))
        else:
            print(json.dumps({"error": f"unknown theme subcommand: {sub}"}))
    else:
        print(json.dumps({"error": f"unknown action: {action}"}))
        sys.exit(2)

def get_theme_info():
    cur, _, _ = run_cmd("metro-theme get")
    cur = cur.strip() or "metro"
    res, _, _ = run_cmd("metro-theme list --json")
    try:
        themes = json.loads(res)
    except Exception:
        themes = []
    return {"current": cur, "themes": themes}

def set_theme_backend(theme_id, accent=None):
    if not re.fullmatch(r"[a-z0-9_-]+", str(theme_id or "")):
        return {"status": "error", "error": f"Invalid theme id: {theme_id}"}
    cmd = f"metro-theme set {q(theme_id)}"
    if accent:
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", str(accent)):
            return {"status": "error", "error": f"Invalid accent: {accent}"}
        cmd += f" {q(accent)}"
    out, err, code = run_cmd(cmd)
    return {"status": "ok" if code == 0 else "error", "output": out, "error": err}
            
def get_sys_info():
    out, _, _ = run_cmd("bash $HOME/.config/quickshell/metro-settings/about.sh")
    m = {}
    for line in out.splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            m[k.strip()] = v.strip()
    return m

if __name__ == "__main__":
    main()

