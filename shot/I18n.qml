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
            // General / TopPanel
            "loading": "loading...",
            "loading_dots": "loading...",
            "wind": "wind",
            "ms": "m/s",
            "feels": "feels",
            "today": "today",
            "now": "now",
            "search_apps": "Search applications...",

            // System tiles
            "cpu_short": "CPU", "cpu_long": "Processor",
            "ram_short": "RAM", "ram_long": "Memory",
            "gpu_short": "GPU", "gpu_long": "Graphics",
            "bat_short": "BAT", "bat_long": "Battery",
            "ssd_short": "SSD", "ssd_long": "Disk",
            "charging": "Charging", "charging_state": "Charging", "full_charge": "Full charge", "left": "Left ~", "remaining_about": "Remaining ~", "discharging": "Discharging", "discharging_state": "Discharging", "load": "load", "load_title": "load", "load_high": "Heavy load", "normal": "Normal",

            // TopPanel Edit
            "add_app": "Add application",
            "edit_cmd": "Configure Command",
            "add_cmd": "Add Command Widget",
            "add_exec_widget": "Add Command Widget",
            "exec_config_title": "Configure Command",
            "templates": "Templates:",
            "update": "Update",
            "shell": "Shell",
            "cache": "Cache",
            "exec_name_label": "TITLE (DISPLAYED ON TILE)",
            "exec_name_placeholder": "e.g.: System Update (or leave empty for auto)",
            "exec_cmd_label": "SHELL COMMAND",
            "exec_cmd_placeholder": "e.g.: metro-update or fastfetch",
            "exec_mode_label": "EXECUTION MODE",
            "exec_term_title": "In terminal",
            "exec_term_desc": "Window with output and --hold",
            "exec_bg_title": "In background (silent)",
            "exec_bg_desc": "No popup window",
            "exec_icon_label": "ICON (CHOOSE OR CUSTOM GLYPH)",
            "custom_glyph_placeholder": "Custom glyph (e.g. \\uf120)",
            "size_label": "Size:",
            "save": "Save",
            "cancel": "Cancel",
            "delete": "Delete",
            "add_widget": "Add widget",
            "clock": "clock",
            "weather": "weather",
            "photo": "photo",
            "player": "player",
            "power": "power",
            "command": "command",
            "notes": "notes",
            "app": "app",
            "compact": "compact",
            "reset": "reset",
            "sure": "sure?",

            // WeatherDetail
            "feels_like": "FEELS LIKE",
            "wind_title": "WIND",
            "humidity_title": "HUMIDITY",
            "pressure_sunset": "PRESSURE / SUNSET",
            "hourly_forecast": "HOURLY FORECAST",
            "7_days": "7 DAYS",
            "search_city": "Search city...",

            // LauncherPanel
            "apps": "applications",
            "installed": "installed",
            "search_dots": "search...",
            "pinned": "pinned",

            // ControlPanel
            "control_center": "control center",
            "on": "on",
            "off": "off",
            "sound": "Sound",
            "muted": "muted",
            "brightness": "Brightness",
            "microphone": "Microphone",
            "dnd": "Do not disturb",
            "silent_mode": "silent mode",
            "notifications_on": "notifications on",
            "screenshot": "Screenshot",
            "performance": "performance",
            "power_saver": "power saver",
            "balanced": "balanced",
            "paused": "paused",
            "no_players": "no active players",
            "nothing_playing": "Nothing playing",
            "notifications": "notifications",
            "clear_all": "clear all",
            "empty": "empty",

            // PowerMenu
                        "good_morning": "good morning",
            "good_afternoon": "good afternoon",
            "good_evening": "good evening",
            "good_night": "good night",
            "enter_password": "enter password",
            "wrong_password": "wrong password · attempt ",
            "auth_error": "authentication error",
            "checking": "checking…",
            "lock": "lock",
            "logout": "log out",
            "sleep": "sleep",
            "restart": "restart",
            "shutdown": "shut down",

            // NotesWidget
            "new_task": "New task...",
            "no_notes": "No notes",
            "list_empty": "List is empty",
            "tasks": "tasks",
            "done": "done",

            // Wi-Fi & BT
            "networks": "Networks",
            "searching_networks": "Searching networks...",
            "searching_devices": "Searching devices...",
            "connecting_to": "Connecting to ",
            "connecting": "Connecting...",
            "disconnecting": "Disconnecting...",
            "turning_on": "Turning on...",
            "turning_off": "Turning off...",
            "wifi_off": "Wi-Fi is off",
            "bt_off": "Bluetooth is off",
            "no_networks": "No networks found",
            "no_paired_devices": "No paired devices",
            "password": "password",
            "connected": "connected",
            "not_connected": "not connected",
            "devices": "Devices",
            "paired": "paired",
            "pair": "pair",
            "connect": "connect",
            "disconnect": "disconnect",
            "forget": "forget",
            "refresh": "refresh",
            "available_networks": "Available networks",
            "enter_value": "enter value and press \"ok\"",

            // Settings App Navigation
            "settings": "settings",
            "personalization": "personalization",
            "personalization_sub": "wallpapers, accent, icons",
            "network": "network",
            "network_sub": "wi-fi and bluetooth",
            "sound_sec": "sound",
            "sound_sub": "devices and volume",
            "display": "display",
            "display_sub": "monitors and modes",
            "power_sec": "power",
            "power_sub": "profiles and battery",
            "widgets": "widgets",
            "widgets_sub": "metro shell grid",
            "language": "language",
            "language_sub": "shell and system language",
            "about": "about",
            "about_sub": "hardware and software",

            // Settings - Personalization
            "wallpapers": "WALLPAPERS",
            "random_wall": "random wallpaper",
            "changing": "changing…",
            "accent": "ACCENT",
            "accent_from_wall": "accent color (from wallpaper)",
            "from_wall": "from wallpaper",
            "vivid": "vivid",
            "reset_theme": "reset theme",
            "accent_shades": "ACCENT SHADES",
            "reading_wall": "reading wallpaper…",
            "no_candidates": "no candidates — change wallpaper to refresh",
            "icon_theme": "ICON THEME",
            "icon_sub": "app and shell folders",
            "icon_hint": "icons follow GTK theme (QT_QPA_PLATFORMTHEME=gtk3) — applied on the fly, no shell restart needed",

            // Settings - Sound
            "output": "OUTPUT",
            "input": "INPUT",

            // Settings - Display
            "monitors": "MONITORS",
            "res_rate": "resolution & refresh rate",
            "scale": "scale",
            "vrr": "vrr",
            "apply": "apply",
            "display_hint": "changes apply on the fly, but persist until reboot — fix desired mode in hyprland.lua",

            // Settings - Power
            "power_profile": "POWER PROFILE",
            "battery": "BATTERY",
            "not_found": "not found",
            "on_ac": "on AC · ",
            "ac_connected": "AC adapter connected",
            "on_battery": "on battery",

            // Settings - Widgets
            "widgets_grid": "WIDGETS GRID",
            "compact_title": "compact widgets",
            "compact_desc": "reset x/y coordinates for all tiles — packGrid fills empty gaps",
            "reset_title": "reset to defaults",
            "reset_desc": "delete layout.json — returns factory grid layout",
            "restart_shell_title": "restart metro shell",
            "restart_shell_desc": "TopPanel, launcher and Control Center reload layout.json",
            "theme_title": "THEME",
            "save_theme_title": "save theme as benchmark",
            "save_theme_desc": "each tool's theme (shell, settings, lock, shot) saved separately with its opacity and accent",
            "remember": "remember",
            "restore_theme_title": "restore theme from benchmark",
            "restore_theme_desc": "each tool reverts to its own saved benchmark theme (not grid)",
            "hints_title": "HINTS",
            "hints_text": "Grid edit mode (drag/resize/delete) is activated with the edit button on the top panel. Wallpaper and accent changes recolor shell and lock screen via metro-colors.",

            // Settings - Language
            "shell_lang_title": "SHELL INTERFACE LANGUAGE",
            "shell_lang_sub": "Language of tiles, panels, widgets, menus and settings",
            "system_lang_title": "SYSTEM LOCALE (LANG)",
            "system_lang_sub": "System language for applications, terminal and environment",
            "system_lang_hint": "Sets LANG in ~/.config/locale.conf and environment. Applications may require relaunch or re-login.",
            "lang_en": "English",
            "lang_ru": "Русский",
            "current_locale": "Current system locale:",
            "set_locale": "Apply system locale",
            "system_lang_applied": "Locale saved to config. Relogin may be required.",

            // Settings - About
            "system": "SYSTEM",
            "os": "os",
            "kernel": "kernel",
            "environment": "environment",
            "device": "device",
            "processor": "processor",
            "graphics": "graphics",
            "memory": "memory",
            "disk": "disk /",
            "uptime": "uptime",
            "host": "host",
            "about_footer": "metro live tiles · quickshell 0.3.1 · config ~/.config/quickshell/metro",

            // Shot
            "area": "Area",
            "window": "Window",
            "screen": "Screen",
            "timer": "Timer",
            "cursor": "Cursor",
            "freeze": "Freeze",
            "editor": "Editor",
            "ocr": "OCR",
            "buffer_only": "Buffer only",
            "take_shot": "Capture",
            "copied_to_clipboard": "COPIED TO CLIPBOARD",
            "text_copied": "TEXT COPIED",
            "shot_saved": "SCREENSHOT SAVED",
            "clipboard": "Clipboard",
            "folder": "Folder"
        },
        "ru": {
            // General / TopPanel
            "loading": "загрузка...",
            "loading_dots": "загрузка...",
            "wind": "ветер",
            "ms": "м/с",
            "feels": "ощущ.",
            "today": "сегодня",
            "now": "сейчас",
            "search_apps": "Поиск приложений...",

            // System tiles
            "cpu_short": "ЦП", "cpu_long": "Процессор",
            "ram_short": "ОЗУ", "ram_long": "Память",
            "gpu_short": "GPU", "gpu_long": "Графика",
            "bat_short": "АКБ", "bat_long": "Батарея",
            "ssd_short": "SSD", "ssd_long": "Диск",
            "charging": "Зарядка", "charging_state": "Заряжается", "full_charge": "Полный заряд", "left": "Осталось ~", "remaining_about": "Осталось ~", "discharging": "Разряжается", "discharging_state": "Разряжается", "load": "нагрузка", "load_title": "нагрузка", "load_high": "Нагрузка", "normal": "Норма",

            // TopPanel Edit
            "add_app": "Добавить приложение",
            "edit_cmd": "Настройка команды",
            "add_cmd": "Добавить виджет-команду",
            "add_exec_widget": "Добавить виджет-команду",
            "exec_config_title": "Настройка команды",
            "templates": "Шаблоны:",
            "update": "Обновление",
            "shell": "Шелл",
            "cache": "Кэш",
            "exec_name_label": "НАЗВАНИЕ (ОТОБРАЖЕНИЕ В ПЛИТКЕ)",
            "exec_name_placeholder": "например: Обновление системы (или пусто для авто)",
            "exec_cmd_label": "КОМАНДА SHELL",
            "exec_cmd_placeholder": "например: metro-update или fastfetch",
            "exec_mode_label": "СПОСОБ ВЫПОЛНЕНИЯ",
            "exec_term_title": "В терминале",
            "exec_term_desc": "Окно с выводом и --hold",
            "exec_bg_title": "В фоне (тихо)",
            "exec_bg_desc": "Без всплывающего окна",
            "exec_icon_label": "ИКОНКА (ВЫБОР ИЛИ СВОЙ ГЛИФ)",
            "custom_glyph_placeholder": "Свой глиф (например \\uf120)",
            "size_label": "Размер:",
            "save": "Сохранить",
            "cancel": "Отмена",
            "delete": "Удалить",
            "add_widget": "Добавить виджет",
            "clock": "часы",
            "weather": "погода",
            "photo": "фото",
            "player": "плеер",
            "power": "питание",
            "command": "команда",
            "notes": "заметки",
            "app": "приложение",
            "compact": "уплотнить",
            "reset": "сброс",
            "sure": "точно?",

            // WeatherDetail
            "feels_like": "ОЩУЩАЕТСЯ",
            "wind_title": "ВЕТЕР",
            "humidity_title": "ВЛАЖНОСТЬ",
            "pressure_sunset": "ДАВЛЕНИЕ / ЗАКАТ",
            "hourly_forecast": "ПОЧАСОВОЙ ПРОГНОЗ",
            "7_days": "НА 7 ДНЕЙ",
            "search_city": "Поиск города...",

            // LauncherPanel
            "apps": "приложения",
            "installed": "установлено",
            "search_dots": "поиск...",
            "pinned": "закреплённые",

            // ControlPanel
            "control_center": "центр управления",
            "on": "включён",
            "off": "выключен",
            "sound": "Звук",
            "muted": "выкл",
            "brightness": "Яркость",
            "microphone": "Микрофон",
            "dnd": "Не беспокоить",
            "silent_mode": "тихий режим",
            "notifications_on": "уведомления вкл",
            "screenshot": "Снимок экрана",
            "performance": "производительность",
            "power_saver": "экономия энергии",
            "balanced": "баланс",
            "paused": "пауза",
            "no_players": "нет активных плееров",
            "nothing_playing": "Ничего не играет",
            "notifications": "уведомления",
            "clear_all": "очистить все",
            "empty": "пусто",

            // PowerMenu
                        "good_morning": "доброе утро",
            "good_afternoon": "добрый день",
            "good_evening": "добрый вечер",
            "good_night": "доброй ночи",
            "enter_password": "введите пароль",
            "wrong_password": "неверный пароль · попытка ",
            "auth_error": "ошибка аутентификации",
            "checking": "проверка…",
            "lock": "блокировка",
            "logout": "выйти",
            "sleep": "сон",
            "restart": "перезагрузка",
            "shutdown": "выключение",

            // NotesWidget
            "new_task": "Новая задача...",
            "no_notes": "Нет заметок",
            "list_empty": "Список пуст",
            "tasks": "задач",
            "done": "готово",

            // Wi-Fi & BT
            "networks": "Сети",
            "searching_networks": "Поиск сетей...",
            "searching_devices": "Поиск устройств...",
            "connecting_to": "Подключение к ",
            "connecting": "Подключение...",
            "disconnecting": "Отключение...",
            "turning_on": "Включение...",
            "turning_off": "Выключение...",
            "wifi_off": "Wi-Fi выключен",
            "bt_off": "Bluetooth выключен",
            "no_networks": "Сети не найдены",
            "no_paired_devices": "Нет сопряжённых устройств",
            "password": "пароль",
            "connected": "подключено",
            "not_connected": "не подключено",
            "devices": "Устройства",
            "paired": "сопряжено",
            "pair": "пара",
            "connect": "подключить",
            "disconnect": "отключить",
            "forget": "забыть",
            "refresh": "обновить",
            "available_networks": "Доступные сети",
            "enter_value": "введи значение и нажми «ок»",

            // Settings App Navigation
            "settings": "настройки",
            "personalization": "персонализация",
            "personalization_sub": "обои, акцент, иконки",
            "network": "сеть",
            "network_sub": "wi-fi и bluetooth",
            "sound_sec": "звук",
            "sound_sub": "устройства и громкость",
            "display": "дисплей",
            "display_sub": "мониторы и режимы",
            "power_sec": "питание",
            "power_sub": "профили и батарея",
            "widgets": "виджеты",
            "widgets_sub": "сетка metro-шелла",
            "language": "язык",
            "language_sub": "язык шелла и системы",
            "about": "о системе",
            "about_sub": "железо и софт",

            // Settings - Personalization
            "wallpapers": "ОБОИ",
            "random_wall": "случайные обои",
            "changing": "меняю…",
            "accent": "АКЦЕНТ",
            "accent_from_wall": "цвет акцента (из обоев)",
            "from_wall": "из обоев",
            "vivid": "vivid",
            "reset_theme": "сброс темы",
            "accent_shades": "ОТТЕНОК АКЦЕНТА",
            "reading_wall": "читаю обои…",
            "no_candidates": "нет кандидатов — смена обоев обновит",
            "icon_theme": "ТЕМА ИКОНОК",
            "icon_sub": "папки приложений и шелла",
            "icon_hint": "иконки следуют GTK-теме (QT_QPA_PLATFORMTHEME=gtk3) — применяются на лету, перезапуск шелла не нужен",

            // Settings - Sound
            "output": "ВЫВОД",
            "input": "ВХОД",

            // Settings - Display
            "monitors": "МОНИТОРЫ",
            "res_rate": "разрешение и частота",
            "scale": "масштаб",
            "vrr": "vrr",
            "apply": "применить",
            "display_hint": "изменения применяются на лету, но живут до перезагрузки — зафиксируй выбранный режим в hyprland.lua",

            // Settings - Power
            "power_profile": "ПРОФИЛЬ ПИТАНИЯ",
            "battery": "БАТАРЕЯ",
            "not_found": "не найдена",
            "on_ac": "от сети · ",
            "ac_connected": "адаптер подключен",
            "on_battery": "от батареи",

            // Settings - Widgets
            "widgets_grid": "СЕТКА ВИДЖЕТОВ",
            "compact_title": "уплотнить виджеты",
            "compact_desc": "сбросить координаты x/y у всех плиток — packGrid заполнит дыры",
            "reset_title": "сбросить к дефолту",
            "reset_desc": "удалить layout.json — вернётся заводская сетка",
            "restart_shell_title": "перезапустить metro-шелл",
            "restart_shell_desc": "TopPanel/лаунчер/CC перечитают layout.json",
            "theme_title": "ТЕМА",
            "save_theme_title": "запомнить тему как эталон",
            "save_theme_desc": "тема каждого тула (шелл, настройки, lock, shot) запомнится отдельно — со своей прозрачностью и цветом",
            "remember": "запомнить",
            "restore_theme_title": "откатить тему к эталону",
            "restore_theme_desc": "каждому тулу вернётся его собственная запомненная тема (не сетка!)",
            "hints_title": "ПОДСКАЗКИ",
            "hints_text": "edit-режим сетки (перетаскивание/ресайз/удаление) включается кнопкой «изменить» на верхней панели. Смена обоев и акцента перекрашивает шелл, экран входа через metro-colors.",

            // Settings - Language
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

            // Settings - About
            "system": "СИСТЕМА",
            "os": "система",
            "kernel": "ядро",
            "environment": "окружение",
            "device": "устройство",
            "processor": "процессор",
            "graphics": "видеокарта",
            "memory": "память",
            "disk": "диск /",
            "uptime": "аптайм",
            "host": "хост",
            "about_footer": "metro live tiles · quickshell 0.3.1 · конфиг ~/.config/quickshell/metro",

            // Shot
            "area": "Область",
            "window": "Окно",
            "screen": "Экран",
            "timer": "Таймер",
            "cursor": "Курсор",
            "freeze": "Заморозка",
            "editor": "Редактор",
            "ocr": "OCR",
            "buffer_only": "Только буфер",
            "take_shot": "Снимок",
            "copied_to_clipboard": "СКОПИРОВАНО В БУФЕР",
            "text_copied": "ТЕКСТ СКОПИРОВАН",
            "shot_saved": "СНИМОК СОХРАНЁН",
            "clipboard": "Буфер",
            "folder": "Папка"
        }
    })

    function t(key) {
        const dict = strings[lang] || strings["en"]
        if (dict && dict[key] !== undefined)
            return dict[key]
        const fallback = strings["en"]
        return (fallback && fallback[key] !== undefined) ? fallback[key] : key
    }
}
