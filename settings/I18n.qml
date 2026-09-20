pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string lang: "en"

    readonly property string langFile: Quickshell.env("HOME") + "/.local/state/metro/lang"

    function setLanguage(l) {
        if (l !== "en" && l !== "ru")
            return
        lang = l
        pSaveLang.command = ["sh", "-c", "mkdir -p \"$HOME/.local/state/metro\" && printf '%s' '" + l + "' > \"" + langFile + "\""]
        pSaveLang.running = true
    }

    property Process pSaveLang: Process {
        command: ["true"]
    }

    property Process pLoadLang: Process {
        command: ["sh", "-c", "cat \"$HOME/.local/state/metro/lang\" 2>/dev/null || echo 'en'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if (t === "ru" || t === "en") {
                    if (root.lang !== t)
                        root.lang = t
                }
            }
        }
        running: true
    }

    property Timer watcher: Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            if (!pLoadLang.running)
                pLoadLang.running = true
        }
    }

    readonly property var strings: ({
        "en": {
            // Navigation
            "settings": "settings",
            "personalization": "personalization",
            "personalization_sub": "wallpapers, accent, icons",
            "network": "network & internet",
            "network_sub": "wi-fi, saved passwords, dns, proxy, bluetooth",
            "keyboard_input": "keyboard & input",
            "keyboard_sub": "layouts, hotkeys, mouse & touchpad",
            "sound_sec": "sound & audio",
            "sound_sub": "volume, devices, mic, test sound",
            "display": "display & monitors",
            "display_sub": "resolution, refresh rate, scale, vrr",
            "window_manager": "window manager",
            "window_manager_sub": "gaps, rounding, blur, animations",
            "default_apps": "default apps",
            "default_apps_sub": "browser, files, editor, media players",
            "notifications_sec": "notifications",
            "notifications_sub": "mako, dnd mode, timeouts, position",
            "power_sec": "power & battery",
            "power_sub": "profiles, battery stats, sleep timeouts",
            "widgets": "metro widgets",
            "widgets_sub": "grid layout, compact, reset, theme backup",
            "language": "language & region",
            "language_sub": "shell UI and system locale",
            "about": "about system",
            "about_sub": "hardware, os, kernel, updates",

            // Common
            "on": "on",
            "off": "off",
            "enabled": "enabled",
            "disabled": "disabled",
            "apply": "apply",
            "save": "save",
            "cancel": "cancel",
            "delete": "delete",
            "connect": "connect",
            "disconnect": "disconnect",
            "forget": "forget",
            "refresh": "refresh",
            "copy": "copy",
            "copied": "copied!",
            "password": "password",
            "enter_value": "enter value and press \"ok\"",
            "search": "search...",
            "all": "all",
            "custom": "custom",
            "sure": "sure?",
            "loading": "loading...",
            "success": "applied successfully",
            "error": "error occurred",

            // Personalization
            "wallpapers": "WALLPAPERS",
            "random_wall": "random wallpaper",
            "changing": "changing…",
            "local_walls": "Local",
            "live_walls": "Live Wallpapers",
            "live_walls_desc": "Animated loop wallpapers (.gif, .webp, .mp4)",
            "open_live_folder": "Open Live folder",
            "no_live_walls": "No live wallpapers in ~/Wallpapers/live yet",
            "wallhaven_walls": "Wallhaven",
            "accent": "ACCENT COLOR",
            "accent_from_wall": "accent color (from wallpaper)",
            "from_wall": "from wallpaper",
            "vivid": "vivid",
            "reset_theme": "reset theme",
            "accent_shades": "ACCENT SHADES",
            "reading_wall": "reading wallpaper…",
            "no_candidates": "no candidates — change wallpaper to refresh",
            "icon_theme": "ICON THEME",
            "icon_sub": "app and shell icon theme",
            "icon_hint": "icons follow GTK theme — metro shell automatically reloads icons instantly",

            // Network - Tabs
            "tab_wifi": "Wi-Fi & Details",
            "tab_saved_wifi": "Saved Networks & Passwords",
            "tab_dns": "DNS Settings",
            "tab_proxy": "Proxy Settings",
            "tab_bluetooth": "Bluetooth",

            // Network - Wi-Fi & Info
            "wifi_power": "Wi-Fi Power",
            "wifi_off": "Wi-Fi is off",
            "not_connected": "not connected",
            "networks_found": "networks found",
            "available_networks": "AVAILABLE NETWORKS",
            "network_details": "NETWORK DETAILS",
            "local_ip": "Local IP:",
            "ipv6_addr": "IPv6:",
            "gateway": "Default Gateway:",
            "mac_addr": "MAC Address:",
            "public_ip": "Public IP:",
            "fetch_public_ip": "check",
            "checking_ip": "checking...",

            // Network - Saved Wi-Fi
            "saved_networks_title": "SAVED WI-FI NETWORKS",
            "saved_networks_desc": "View saved connection profiles, passwords, and auto-connect settings",
            "no_saved_networks": "No saved Wi-Fi networks found",
            "show_password": "show password",
            "hide_password": "hide",
            "autoconnect": "auto-connect",

            // Network - DNS
            "dns_title": "DNS CONFIGURATION",
            "dns_desc": "Configure Domain Name System servers for your active network connection",
            "active_connection": "Active Connection:",
            "current_dns": "Active System DNS:",
            "dns_mode": "DNS PRESETS",
            "dns_dhcp": "Automatic (DHCP)",
            "dns_dhcp_sub": "Default DNS provided by your router/ISP",
            "dns_cloudflare": "Cloudflare DNS",
            "dns_cloudflare_sub": "1.1.1.1, 1.0.0.1 · Fast & privacy-focused",
            "dns_google": "Google Public DNS",
            "dns_google_sub": "8.8.8.8, 8.8.4.4 · High availability & global coverage",
            "dns_quad9": "Quad9 Security",
            "dns_quad9_sub": "9.9.9.9, 149.112.112.112 · Blocks malicious domains",
            "dns_adguard": "AdGuard DNS",
            "dns_adguard_sub": "94.140.14.14, 94.140.15.15 · Blocks ads & trackers",
            "dns_custom": "Custom DNS",
            "dns_custom_sub": "Enter your own primary and secondary DNS server IPs",
            "primary_dns": "Primary DNS Server",
            "secondary_dns": "Secondary DNS Server (optional)",
            "apply_dns": "Apply DNS",

            // Network - Proxy
            "proxy_title": "SYSTEM PROXY",
            "proxy_desc": "Configure HTTP, HTTPS, and SOCKS5 network proxy for applications",
            "proxy_mode": "PROXY MODE",
            "proxy_none": "Direct Connection (No Proxy)",
            "proxy_manual": "Manual Proxy",
            "proxy_auto": "Automatic (PAC URL)",
            "http_proxy": "HTTP Proxy",
            "https_proxy": "HTTPS Proxy",
            "socks_proxy": "SOCKS5 Proxy",
            "host": "Host / IP",
            "port": "Port",
            "ignore_hosts": "No Proxy For (Ignore Hosts)",
            "pac_url": "PAC Configuration URL",
            "apply_proxy": "Apply Proxy",

            // Network - Bluetooth
            "bluetooth": "BLUETOOTH",
            "searching_devices": "searching devices...",
            "bt_off": "Bluetooth is off",
            "connected_count": "connected",
            "paired_devices": "PAIRED & DETECTED DEVICES",
            "pair": "pair",
            "unpair": "unpair",
            "scan": "scan",
            "scanning": "scanning…",

            // Keyboard & Input - Tabs
            "tab_layouts": "Layouts & Typing",
            "tab_hotkeys": "Keybindings (Hyprland)",
            "tab_mouse_touchpad": "Mouse & Touchpad",
            "layouts_tab": "Layouts",
            "hotkeys_tab": "Keybindings",
            "touchpad_tab": "Mouse & Touchpad",

            // Keyboard - Layouts
            "keyboard_title": "KEYBOARD & INPUT",
            "keyboard_desc": "Configured input layouts, keybindings, and pointer settings",
            "layout_manage": "LAYOUT MANAGEMENT",
            "layout_manage_desc": "Configured input layouts and layout switching key combination",
            "layouts_title": "KEYBOARD LAYOUTS",
            "layouts_desc": "Configured input layouts and layout switching key combination",
            "add_layout": "Add Layout",
            "switch_shortcut": "SWITCH LAYOUT SHORTCUT",
            "repeat_settings": "TYPING REPEAT RATE & DELAY",
            "repeat_rate": "Repeat rate (chars/sec):",
            "repeat_delay": "Repeat delay (ms):",
            "numlock_title": "NumLock on startup",
            "apply_keyboard": "Apply Keyboard Settings",

            // Keyboard - Keybindings
            "hotkeys_title": "HYPRLAND KEYBINDINGS",
            "hotkeys_desc": "Search and manage global window manager and application hotkeys",
            "hotkeys_catalog": "HYPRLAND KEYBINDINGS",
            "hotkeys_catalog_desc": "Search and manage global window manager and application hotkeys",
            "search_hotkeys": "Search key combination or action...",
            "cat_all": "All",
            "cat_apps": "Apps",
            "cat_window": "Windows",
            "cat_media": "Media",
            "cat_tools": "Tools",
            "cat_system": "System",
            "cat_workspace": "Workspaces",
            "add_hotkey": "Add Keybinding",
            "add_bind": "Add Keybinding",
            "add_bind_title": "ADD NEW KEYBINDING",
            "mod_key": "Modifier (Mod)",
            "key_name": "Key",
            "key_placeholder": "Key (e.g. Return, Space, B)",
            "cmd_action": "Command to run",
            "cmd_placeholder": "Command (e.g. kitty, firefox)",
            "save_bind": "Save Keybinding",
            "connected": "connected",

            // Touchpad & Mouse
            "touchpad_title": "TOUCHPAD SETTINGS",
            "tap_to_click": "Tap to click",
            "natural_scroll_touchpad": "Natural scrolling (touchpad)",
            "disable_while_typing": "Disable touchpad while typing",
            "tap_and_drag": "Tap and drag",
            "drag_lock": "Drag lock",
            "middle_click_emulation": "Middle button emulation",
            "mouse_title": "MOUSE SETTINGS",
            "sensitivity": "Pointer Sensitivity",
            "accel_profile": "Acceleration Profile",
            "natural_scroll_mouse": "Natural scrolling (mouse)",
            "left_handed": "Left-handed mode",

            // Sound
            "output": "AUDIO OUTPUT",
            "input": "AUDIO INPUT (MICROPHONE)",
            "test_sound": "Test Speaker Sound",
            "playing_test": "playing test sound…",

            // Display
            "monitors": "CONNECTED MONITORS",
            "res_rate": "resolution & refresh rate",
            "scale": "scale",
            "vrr": "vrr",
            "display_hint": "changes apply on the fly, and persist until reboot — update hyprland.lua to fix mode permanently",

            // Window Manager
            "wm_title": "HYPRLAND WINDOW MANAGER",
            "wm_desc": "Customize window gaps, corner rounding, blur effects, and animations",
            "gaps_title": "WINDOW GAPS",
            "gaps_in": "Inner gaps (between windows):",
            "gaps_out": "Outer gaps (screen edge):",
            "rounding_title": "CORNER ROUNDING",
            "rounding": "Window corner radius:",
            "border_title": "WINDOW BORDERS",
            "border_size": "Border size:",
            "blur_title": "BLUR & GLASS EFFECTS",
            "blur_enabled": "Enable blur",
            "blur_size": "Blur radius / size:",
            "blur_passes": "Blur passes (smoothness):",
            "animations_title": "ANIMATIONS",
            "animations_enabled": "Enable animations",
            "animation_speed": "Animation speed (lower is faster):",
            "layout_mode": "Window layout mode (Dwindle / Master)",
            "apply_wm": "Apply Window Manager Settings",

            // Default Apps
            "default_apps_title": "DEFAULT APPLICATIONS",
            "default_apps_desc": "Select preferred default applications for file types and web browsing",
            "app_browser": "Web Browser",
            "app_file_manager": "File Manager",
            "app_text_editor": "Text Editor",
            "app_video": "Video Player",
            "app_audio": "Audio Player",
            "app_image": "Image Viewer",
            "app_pdf": "Document / PDF Viewer",
            "no_apps_found": "No matching desktop apps found",

            // Notifications
            "notif_title": "MAKO NOTIFICATION DAEMON",
            "notif_desc": "Configure on-screen notification popups, position, timeouts, and DND",
            "dnd_title": "Do Not Disturb (Silent Mode)",
            "dnd_desc": "Mute notification popups while preserving notification history",
            "notif_timeout": "Notification display timeout (seconds):",
            "notif_anchor": "Screen Position",
            "notif_max": "Maximum visible notifications:",
            "test_notif": "Send Test Notification",
            "clear_notif": "Clear Notification History",

            // Power
            "power_profile": "POWER PROFILE",
            "performance": "performance",
            "balanced": "balanced",
            "power_saver": "power saver",
            "battery": "BATTERY STATUS",
            "on_ac": "on AC · ",
            "ac_connected": "AC adapter connected",
            "on_battery": "on battery",
            "not_found": "not found",

            // Widgets
            "widgets_grid": "WIDGETS GRID",
            "compact_title": "compact widgets",
            "compact_desc": "reset x/y coordinates for all tiles — packGrid fills empty gaps",
            "compact": "compact",
            "reset_title": "reset to default",
            "reset_desc": "remove layout.json — restore default factory tiles",
            "reset": "reset",
            "lock_grid": "LOCK SCREEN GRID",
            "lock_compact_desc": "reset x/y of lock tiles — grid refills gaps (lock-layout.json)",
            "lock_reset_desc": "remove lock-layout.json — lock screen returns to factory grid",
            "restart_shell_title": "restart metro shell",
            "restart_shell_desc": "TopPanel/launcher/CC reload layout.json",
            "restart": "restart",
            "theme_title": "THEME BASELINE",
            "save_theme_title": "save theme as baseline",
            "save_theme_desc": "theme of each tool is remembered independently with its colors",
            "remember": "remember",
            "restore_theme_title": "restore theme from baseline",
            "restore_theme_desc": "restore saved baseline colors and glass transparency",
            "hints_title": "HINTS",
            "hints_text": "Edit mode for the grid is toggled by the 'edit' button on the top panel. Wallpapers and accent automatically recolor the shell, lock screen, and display manager.",

            // Language
            "shell_lang_title": "SHELL UI LANGUAGE",
            "shell_lang_sub": "Language of tiles, panels, menus, and settings UI",
            "system_lang_title": "SYSTEM LANGUAGE (LANG)",
            "system_lang_sub": "System locale for apps, terminal, and desktop environment",
            "system_lang_hint": "Sets LANG in ~/.config/locale.conf and session environment. Some applications require a restart or re-login to update.",
            "lang_en": "English",
            "lang_ru": "Русский",
            "current_locale": "Current system locale:",
            "set_locale": "Apply system locale",
            "system_lang_applied": "Locale saved. Re-login may be needed for full effect.",

            // About
            "system": "SYSTEM INFORMATION",
            "os": "operating system",
            "kernel": "kernel",
            "environment": "environment / wm",
            "device": "device / terminal",
            "processor": "processor (cpu)",
            "graphics": "graphics (gpu)",
            "memory": "memory (ram)",
            "disk": "root disk (/)",
            "uptime": "uptime",
            "host": "hostname",
            "updates_check": "SYSTEM UPDATES",
            "updates_count": "Pending packages:",
            "check_updates": "check updates",
            "install_updates": "launch update (metro-update)",
            "about_footer": "metro live tiles · quickshell 0.3.1 · config ~/.config/quickshell/metro"
        },
        "ru": {
            // Navigation
            "settings": "настройки",
            "personalization": "персонализация",
            "personalization_sub": "обои, акцент, иконки",
            "network": "сеть и интернет",
            "network_sub": "wi-fi, сохранённые пароли, dns, прокси, bluetooth",
            "keyboard_input": "клавиатура и ввод",
            "keyboard_sub": "раскладки, бинды, мышь и тачпад",
            "sound_sec": "звук и аудио",
            "sound_sub": "громкость, устройства, микрофон, тест звука",
            "display": "дисплей и мониторы",
            "display_sub": "разрешение, частота, масштаб, vrr",
            "window_manager": "окна и интерфейс",
            "window_manager_sub": "отступы, скругления, блюр, анимации",
            "default_apps": "приложения по умолчанию",
            "default_apps_sub": "браузер, файлы, редактор, медиаплееры",
            "notifications_sec": "уведомления",
            "notifications_sub": "mako, тихий режим dnd, таймауты, позиция",
            "power_sec": "питание и батарея",
            "power_sub": "профили, батарея, таймауты сна",
            "widgets": "виджеты metro",
            "widgets_sub": "сетка плиток, уплотнение, сброс, бэкап темы",
            "language": "язык и регион",
            "language_sub": "язык шелла и системная локаль",
            "about": "о системе",
            "about_sub": "железо, os, ядро, обновления",

            // Common
            "on": "вкл",
            "off": "выкл",
            "enabled": "включено",
            "disabled": "выключено",
            "apply": "применить",
            "save": "сохранить",
            "cancel": "отмена",
            "delete": "удалить",
            "connect": "подключить",
            "disconnect": "отключить",
            "forget": "забыть",
            "refresh": "обновить",
            "copy": "копировать",
            "copied": "скопировано!",
            "password": "пароль",
            "enter_value": "введи значение и нажми «ок»",
            "search": "поиск...",
            "all": "все",
            "custom": "пользовательский",
            "sure": "точно?",
            "loading": "загрузка...",
            "success": "успешно применено",
            "error": "произошла ошибка",

            // Personalization
            "wallpapers": "ОБОИ",
            "random_wall": "случайные обои",
            "changing": "меняю…",
            "local_walls": "Локальные",
            "live_walls": "Живые обои",
            "live_walls_desc": "Анимированные зацикленные обои (.gif, .webp, .mp4)",
            "open_live_folder": "Открыть папку ~/Wallpapers/live",
            "no_live_walls": "В папке ~/Wallpapers/live пока нет живых обоев",
            "wallhaven_walls": "Wallhaven",
            "accent": "ЦВЕТ АКЦЕНТА",
            "accent_from_wall": "цвет акцента (из обоев)",
            "from_wall": "из обоев",
            "vivid": "vivid",
            "reset_theme": "сброс темы",
            "accent_shades": "ОТТЕНОК АКЦЕНТА",
            "reading_wall": "читаю обои…",
            "no_candidates": "нет кандидатов — смена обоев обновит",
            "icon_theme": "ТЕМА ИКОНОК",
            "icon_sub": "папки приложений и шелла",
            "icon_hint": "иконки следуют GTK-теме — шелл metro автоматически перезагружает иконки на лету",

            // Network - Tabs
            "tab_wifi": "Wi-Fi и сведения",
            "tab_saved_wifi": "Запомненные сети и пароли",
            "tab_dns": "Настройка DNS",
            "tab_proxy": "Настройка Прокси",
            "tab_bluetooth": "Bluetooth",

            // Network - Wi-Fi & Info
            "wifi_power": "Питание Wi-Fi",
            "wifi_off": "Wi-Fi выключен",
            "not_connected": "не подключено",
            "networks_found": "сетей найдено",
            "available_networks": "ДОСТУПНЫЕ СЕТИ",
            "network_details": "СВЕДЕНИЯ О СЕТИ",
            "local_ip": "Локальный IP:",
            "ipv6_addr": "IPv6 адрес:",
            "gateway": "Основной шлюз:",
            "mac_addr": "MAC-адрес:",
            "public_ip": "Внешний IP:",
            "fetch_public_ip": "узнать",
            "checking_ip": "проверяю...",

            // Network - Saved Wi-Fi
            "saved_networks_title": "ЗАПОМНЕННЫЕ WI-FI СЕТИ",
            "saved_networks_desc": "Просмотр сохранённых профилей, паролей и параметров автоподключения",
            "no_saved_networks": "Нет сохранённых Wi-Fi сетей",
            "show_password": "показать пароль",
            "hide_password": "скрыть",
            "autoconnect": "автоподключение",

            // Network - DNS
            "dns_title": "НАСТРОЙКА DNS-СЕРВЕРОВ",
            "dns_desc": "Управление DNS-серверами для текущего активного подключения к сети",
            "active_connection": "Активное подключение:",
            "current_dns": "Текущий системный DNS:",
            "dns_mode": "ПРЕСЕТЫ DNS",
            "dns_dhcp": "Автоматический (DHCP)",
            "dns_dhcp_sub": "DNS по умолчанию от роутера / интернет-провайдера",
            "dns_cloudflare": "Cloudflare DNS",
            "dns_cloudflare_sub": "1.1.1.1, 1.0.0.1 · Максимальная скорость и приватность",
            "dns_google": "Google Public DNS",
            "dns_google_sub": "8.8.8.8, 8.8.4.4 · Высокая надёжность и стабильность",
            "dns_quad9": "Quad9 Security",
            "dns_quad9_sub": "9.9.9.9, 149.112.112.112 · Автоматическая блокировка вредоносных сайтов",
            "dns_adguard": "AdGuard DNS",
            "dns_adguard_sub": "94.140.14.14, 94.140.15.15 · Блокировка рекламы и трекеров",
            "dns_custom": "Пользовательский DNS",
            "dns_custom_sub": "Ввод собственных IP-адресов первичного и вторичного DNS",
            "primary_dns": "Первичный DNS-сервер",
            "secondary_dns": "Вторичный DNS-сервер (необязательно)",
            "apply_dns": "Применить DNS",

            // Network - Proxy
            "proxy_title": "СИСТЕМНЫЙ ПРОКСИ-СЕРВЕР",
            "proxy_desc": "Настройка HTTP, HTTPS и SOCKS5 прокси для приложений и консоли",
            "proxy_mode": "РЕЖИМ ПРОКСИ",
            "proxy_none": "Прямое подключение (Без прокси)",
            "proxy_manual": "Ручная настройка",
            "proxy_auto": "Автоматически (PAC URL)",
            "http_proxy": "HTTP Прокси",
            "https_proxy": "HTTPS Прокси",
            "socks_proxy": "SOCKS5 Прокси",
            "host": "Хост / IP",
            "port": "Порт",
            "ignore_hosts": "Исключения (Без прокси для):",
            "pac_url": "URL файла автоконфигурации (PAC):",
            "apply_proxy": "Применить Прокси",

            // Network - Bluetooth
            "bluetooth": "BLUETOOTH",
            "searching_devices": "поиск устройств...",
            "bt_off": "Bluetooth выключен",
            "connected_count": "подключено",
            "paired_devices": "СОПРЯЖЁННЫЕ И НАЙДЕННЫЕ УСТРОЙСТВА",
            "pair": "сопряжение",
            "unpair": "удалить",
            "scan": "поиск",
            "scanning": "ищу…",

            // Keyboard & Input - Tabs
            "tab_layouts": "Раскладки и ввод",
            "tab_hotkeys": "Горячие клавиши (Hyprland)",
            "tab_mouse_touchpad": "Мышь и тачпад",
            "layouts_tab": "Раскладки",
            "hotkeys_tab": "Горячие клавиши",
            "touchpad_tab": "Мышь и тачпад",

            // Keyboard - Layouts
            "keyboard_title": "КЛАВИАТУРА И ВВОД",
            "keyboard_desc": "Настройка раскладок ввода, горячих клавиш и параметров мыши/тачпада",
            "layout_manage": "УПРАВЛЕНИЕ РАСКЛАДКАМИ",
            "layout_manage_desc": "Настроенные языки ввода и комбинация переключения раскладки",
            "layouts_title": "РАСКЛАДКИ КЛАВИАТУРЫ",
            "layouts_desc": "Настроенные языки ввода и комбинация переключения раскладки",
            "add_layout": "Добавить раскладку",
            "switch_shortcut": "КОМБИНАЦИЯ ПЕРЕКЛЮЧЕНИЯ РАСКЛАДКИ",
            "repeat_settings": "ПАРАМЕТРЫ ПОВТОРА КЛАВИШ",
            "repeat_rate": "Скорость автоповтора (знаков/сек):",
            "repeat_delay": "Задержка перед повтором (мс):",
            "numlock_title": "NumLock включён при старте",
            "apply_keyboard": "Применить настройки клавиатуры",

            // Keyboard - Keybindings
            "hotkeys_title": "ГОРЯЧИЕ КЛАВИШИ HYPRLAND",
            "hotkeys_desc": "Поиск и управление комбинациями клавиш оконного менеджера и приложений",
            "hotkeys_catalog": "ГОРЯЧИЕ КЛАВИШИ HYPRLAND",
            "hotkeys_catalog_desc": "Поиск и управление комбинациями клавиш оконного менеджера и приложений",
            "search_hotkeys": "Поиск комбинации или действия...",
            "cat_all": "Все",
            "cat_apps": "Приложения",
            "cat_window": "Окна",
            "cat_media": "Медиа",
            "cat_tools": "Инструменты",
            "cat_system": "Система",
            "cat_workspace": "Воркспейсы",
            "add_hotkey": "Добавить комбинацию",
            "add_bind": "Добавить бинд",
            "add_bind_title": "ДОБАВИТЬ НОВУЮ КОМБИНАЦИЮ КЛАВИШ",
            "mod_key": "Модификатор (Mod)",
            "key_name": "Клавиша",
            "key_placeholder": "Клавиша (напр. Return, Space, B)",
            "cmd_action": "Команда для запуска",
            "cmd_placeholder": "Команда (напр. kitty, firefox)",
            "save_bind": "Сохранить комбинацию",
            "connected": "подключено",

            // Touchpad & Mouse
            "touchpad_title": "НАСТРОЙКИ ТАЧПАДА",
            "tap_to_click": "Нажатие для клика (Tap to click)",
            "natural_scroll_touchpad": "Естественная прокрутка (тачпад)",
            "disable_while_typing": "Отключать тачпад при наборе текста",
            "tap_and_drag": "Перетаскивание касанием (Tap and drag)",
            "drag_lock": "Фиксация перетаскивания (Drag lock)",
            "middle_click_emulation": "Эмуляция средней кнопки мыши",
            "mouse_title": "НАСТРОЙКИ МЫШИ",
            "sensitivity": "Чувствительность указателя",
            "accel_profile": "Профиль ускорения",
            "natural_scroll_mouse": "Естественная прокрутка (мышь)",
            "left_handed": "Режим для левши",

            // Sound
            "output": "ВЫВОД ЗВУКА",
            "input": "ВХОД ЗВУКА (МИКРОФОН)",
            "test_sound": "Проверить звук динамиков",
            "playing_test": "воспроизведение тестового звука…",

            // Display
            "monitors": "ПОДКЛЮЧЁННЫЕ МОНИТОРЫ",
            "res_rate": "разрешение и частота",
            "scale": "масштаб",
            "vrr": "vrr",
            "display_hint": "изменения применяются на лету, но живут до перезагрузки — зафиксируй выбранный режим в hyprland.lua",

            // Window Manager
            "wm_title": "ОКОННЫЙ МЕНЕДЖЕР HYPRLAND",
            "wm_desc": "Настройка внешнего вида, отступов, скруглений окон, эффектов блюра и анимаций",
            "gaps_title": "ОТСТУПЫ ОКОН (GAPS)",
            "gaps_in": "Внутренние отступы (между окнами):",
            "gaps_out": "Внешние отступы (от краев экрана):",
            "rounding_title": "СКРУГЛЕНИЕ УГЛОВ ОКОН",
            "rounding": "Радиус скругления углов:",
            "border_title": "РАМКА ОКОН",
            "border_size": "Толщина границы окна:",
            "blur_title": "ЭФФЕКТЫ БЛЮРА И СТЕКЛА",
            "blur_enabled": "Включить блюр окон",
            "blur_size": "Радиус / размер блюра:",
            "blur_passes": "Проходы блюра (сглаживание):",
            "animations_title": "АНИМАЦИИ",
            "animations_enabled": "Включить анимации окон",
            "animation_speed": "Скорость анимаций (меньше — быстрее):",
            "layout_mode": "Режим компоновки окон (Dwindle / Master)",
            "apply_wm": "Применить настройки оконного менеджера",

            // Default Apps
            "default_apps_title": "ПРИЛОЖЕНИЯ ПО УМОЛЧАНИЮ",
            "default_apps_desc": "Выбор приложений по умолчанию для веб-серфинга, файлов и медиа",
            "app_browser": "Веб-браузер",
            "app_file_manager": "Файловый менеджер",
            "app_text_editor": "Текстовый редактор",
            "app_video": "Видеоплеер",
            "app_audio": "Аудиоплеер",
            "app_image": "Просмотр изображений",
            "app_pdf": "Просмотр документов (PDF)",
            "no_apps_found": "Не найдено установленных приложений",

            // Notifications
            "notif_title": "ДЕМОН УВЕДОМЛЕНИЙ MAKO",
            "notif_desc": "Настройка всплывающих окон, расположения на экране, таймаутов и режима тишины",
            "dnd_title": "Режим «Не беспокоить» (Тихий режим)",
            "dnd_desc": "Скрывает всплывающие плашки уведомлений с сохранением их в истории",
            "notif_timeout": "Время показа уведомления (секунд):",
            "notif_anchor": "Расположение на экране",
            "notif_max": "Максимум видимых уведомлений:",
            "test_notif": "Отправить тестовое уведомление",
            "clear_notif": "Очистить историю уведомлений",

            // Power
            "power_profile": "ПРОФИЛЬ ПИТАНИЯ",
            "performance": "производительность",
            "balanced": "баланс",
            "power_saver": "экономия энергии",
            "battery": "СОСТОЯНИЕ БАТАРЕИ",
            "on_ac": "от сети · ",
            "ac_connected": "адаптер подключен",
            "on_battery": "от батареи",
            "not_found": "не найдена",

            // Widgets
            "widgets_grid": "СЕТКА ВИДЖЕТОВ",
            "compact_title": "уплотнить виджеты",
            "compact_desc": "сбросить координаты x/y у всех плиток — packGrid заполнит дыры",
            "compact": "уплотнить",
            "reset_title": "сбросить к дефолту",
            "reset_desc": "удалить layout.json — вернётся заводская сетка",
            "lock_grid": "СЕТКА ЭКРАНА БЛОКИРОВКИ",
            "lock_compact_desc": "сбросить координаты x/y плиток лока — сетка заполнит дыры (lock-layout.json)",
            "lock_reset_desc": "удалить lock-layout.json — локскрин вернётся к заводской сетке",
            "reset": "сброс",
            "restart_shell_title": "перезапустить metro-шелл",
            "restart_shell_desc": "TopPanel/лаунчер/CC перечитают layout.json",
            "restart": "перезапуск",
            "theme_title": "ЭТАЛОН ТЕМЫ",
            "save_theme_title": "запомнить тему как эталон",
            "save_theme_desc": "тема каждого тула (шелл, настройки, lock, shot) запомнится отдельно",
            "remember": "запомнить",
            "restore_theme_title": "откатить тему к эталону",
            "restore_theme_desc": "каждому тулу вернётся его собственная запомненная тема",
            "hints_title": "ПОДСКАЗКИ",
            "hints_text": "edit-режим сетки включается кнопкой «изменить» на верхней панели. Смена обоев и акцента перекрашивает шелл, экран входа через metro-colors.",

            // Language
            "shell_lang_title": "ЯЗЫК ШЕЛЛА",
            "shell_lang_sub": "Язык плиток, панелей, меню и настроек интерфейса",
            "system_lang_title": "СИСТЕМНЫЙ ЯЗЫК (LANG)",
            "system_lang_sub": "Системная локаль для приложений, консоли и окружения",
            "system_lang_hint": "Устанавливает LANG в ~/.config/locale.conf и окружении. Для некоторых приложений может потребоваться перезапуск или повторный вход.",
            "lang_en": "English",
            "lang_ru": "Русский",
            "current_locale": "Текущая системная локаль:",
            "set_locale": "Применить системную локаль",
            "system_lang_applied": "Локаль сохранена. Может потребоваться повторный вход.",

            // About
            "system": "СВЕДЕНИЯ О СИСТЕМЕ",
            "os": "операционная система",
            "kernel": "ядро",
            "environment": "окружение / wm",
            "device": "устройство / терминал",
            "processor": "процессор (cpu)",
            "graphics": "видеокарта (gpu)",
            "memory": "оперативная память",
            "disk": "системный диск (/)",
            "uptime": "время работы",
            "host": "имя хоста",
            "updates_check": "ОБНОВЛЕНИЯ СИСТЕМЫ",
            "updates_count": "Доступно обновлений пакетов:",
            "check_updates": "проверить",
            "install_updates": "обновить систему (metro-update)",
            "about_footer": "metro live tiles · quickshell 0.3.1 · конфиг ~/.config/quickshell/metro"
        }
    })

    function t(key) {
        const dict = strings[lang] || strings["ru"] || strings["en"]
        if (dict && dict[key] !== undefined)
            return dict[key]
        const fallback = strings["ru"] || strings["en"]
        return (fallback && fallback[key] !== undefined) ? fallback[key] : key
    }
}
