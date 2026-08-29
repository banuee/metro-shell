-- ~/.config/hypr/hyprland.lua

hl.monitor({
    output   = "eDP-2",
    mode     = "1920x1080@300.00",
    position = "0x0",
    scale    = 1,
})
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@300.00",
    position = "0x0",
    scale    = 1,
})
hl.monitor({
    output   = "HDMI-A-2",
    mode     = "1360x768@300.00",
    position = "1920x0",
    scale    = 1,
})

hl.env("XCURSOR_SIZE", "10")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("quickshell -p " .. os.getenv("HOME") .. "/.config/quickshell/metro")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("awww-daemon")
end)

hl.config({
    general = {
        gaps_in     = 10,
        gaps_out    = 10,
        border_size = 0,
        col = {
            active_border   = "rgba(ffffffff)",
            inactive_border = "rgba(ffffffff)",
        },
        layout        = "dwindle",
        allow_tearing = false,
    },
    decoration = {
        rounding       = 20,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = false,
        },
        blur = {
            enabled    = true,
            size       = 3,
            passes     = 3,
            noise      = 0.02,
            contrast   = 0.85,
            brightness = 1,
            vibrancy   = 0.55,
            xray       = false,
        },
    },
    animations = { enabled = true },
})

hl.curve("Open",  { type = "bezier", points = { {0,    0},    {0.2,  1}    } })
hl.curve("Move",  { type = "bezier", points = { {0.80, 0},    {0.12, 1.4}  } })
hl.curve("Tag",   { type = "bezier", points = { {0.4,  0},    {0.2,  1}    } })
hl.curve("Close", { type = "bezier", points = { {0.46, 1.0},  {0.29, 0.99} } })
hl.curve("Focus", { type = "bezier", points = { {0.46, 1.0},  {0.29, 0.99} } })

hl.animation({ leaf = "windows",    enabled = true, speed = 3.5, bezier = "Move"  })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 3.5, bezier = "Open",  style = "popin 70%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3.0, bezier = "Close", style = "popin 20%" })
hl.animation({ leaf = "border",     enabled = true, speed = 3.0, bezier = "Focus" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 3.5, bezier = "Open"  })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 3.0, bezier = "Close" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4.0, bezier = "Tag", style = "slide" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.5, bezier = "Open", style = "slide" })

hl.config({
    dwindle = {
        preserve_split = false,
        smart_split     = false,
    },
    master = {
        new_status = "master",
        mfact      = 0.55,
    },
    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
    },
})

hl.config({
    input = {
        kb_layout        = "us,ru",
        kb_options       = "grp:alt_shift_toggle",
        numlock_by_default = false,
        repeat_rate      = 25,
        repeat_delay     = 600,
        follow_mouse     = 1,
        sensitivity      = 0,
        accel_profile    = "flat",
        natural_scroll   = false,
        left_handed      = false,
        touchpad = {
            disable_while_typing   = true,
            tap_to_click           = true,
            tap_and_drag           = true,
            drag_lock               = true,
            natural_scroll          = false,
            middle_button_emulation = false,
        },
    },
})

local mainMod = "SUPER"

hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("chromium"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nemo"))
hl.bind(mainMod .. " + J", hl.dsp.exec_cmd("steam"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("vscodium"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("hyprshot-gui"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("~/.local/bin/metro-lock"))


hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +10%"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), { locked = true, repeating = true })

hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + Q", hl.dsp.window.close())

hl.bind(mainMod .. " + Tab", hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + A", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + D", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + W", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + X", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

local currentLayout = "dwindle"
hl.bind(mainMod .. " + N", function()
    currentLayout = (currentLayout == "dwindle") and "master" or "dwindle"
    hl.config({ general = { layout = currentLayout } })
end)

hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind("ALT + SHIFT + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 2"))

for i = 1, 9 do
    hl.bind("ALT + " .. i, hl.dsp.focus({ workspace = i }))
end

hl.bind(mainMod .. " + left", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ workspace = "e+1" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind("ALT + Z", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + I", hl.dsp.window.move({ workspace = "special:minimized" }))
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.workspace.toggle_special("minimized"))

hl.bind("CTRL + ALT + left", function() hl.dispatch(hl.dsp.focus({ workspace = "e-1" })) end)
hl.bind("CTRL + ALT + right", function() hl.dispatch(hl.dsp.focus({ workspace = "e+1" })) end)

for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, function() hl.dispatch(hl.dsp.focus({ workspace = tostring(i) })) end)
    hl.bind(mainMod .. " + SHIFT + " .. i, function() hl.dispatch(hl.dsp.window.move({ workspace = tostring(i) })) end)
end

hl.layer_rule({
    name  = "metro-glass",
    match = { namespace = "quickshell:metro" },
    blur  = true,
    ignore_alpha = 0.2,
})