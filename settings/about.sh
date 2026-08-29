#!/bin/bash
# помощник секции «о системе» — key=value строки
echo "os=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2)"
echo "kernel=$(uname -r)"
echo "host=$(uname -n)"
echo "wm=Hyprland $(hyprctl version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)"
echo "cpu=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//')"

gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1)
[ -z "$gpu" ] && gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d' | cut -d: -f3- | sed 's/^ *//')
echo "gpu=$gpu"

echo "ram=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}')"
echo "disk=$(df -h / 2>/dev/null | awk 'NR==2{print $3" из "$2}')"
echo "term=$(grep -m1 'TERM' /sys/class/dmi/id/product_name 2>/dev/null || cat /sys/class/dmi/id/product_name 2>/dev/null)"
echo "up=$(uptime -p 2>/dev/null)"
