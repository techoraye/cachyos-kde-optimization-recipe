#!/usr/bin/env bash

# =====================================================
#  Arch Linux KDE Optimization Script
#  Interactive UI with dialog
#  Works on Arch / EndeavourOS / CachyOS / Garuda
#  Author: techoraye
# =====================================================

set -e

# -- Ensure dialog is installed --
if ! command -v dialog &>/dev/null; then
    sudo pacman -S --noconfirm dialog
fi

# ============ FUNCTIONS ============

system_update() {
    sudo pacman -Syu --noconfirm
}

install_build_tools() {
    sudo pacman -S --needed --noconfirm base-devel git cmake bison flex m4 patch pkgconf \
        jdk8-openjdk icedtea-web yay powerpill
}

enable_chaotic() {
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB

    sudo pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
    sudo pacman -Syu --noconfirm
}

install_kde() {
    sudo pacman -S --needed --noconfirm plasma-meta kde-utilities-meta kde-system-meta \
        flatpak flatpak-kcm flatpak-xdg-utils gwenview adwaita-fonts materia-gtk-theme
}

install_drivers() {
    CHOICE=$(dialog --clear --stdout --title "Driver Installation" --menu "Choose your hardware:" 15 60 6 \
    1 "NVIDIA (proprietary)" \
    2 "NVIDIA (open source - nouveau)" \
    3 "AMD GPU" \
    4 "Intel iGPU" \
    5 "Common WiFi drivers" \
    6 "Return")

    clear
    case $CHOICE in
        1) sudo pacman -S --noconfirm nvidia nvidia-settings nvidia-utils ;;
        2) sudo pacman -S --noconfirm xf86-video-nouveau mesa ;;
        3) sudo pacman -S --noconfirm mesa vulkan-radeon radeontop ;;
        4) sudo pacman -S --noconfirm mesa vulkan-intel intel-media-driver ;;
        5) sudo pacman -S --noconfirm broadcom-wl-dkms rtl8821ce-dkms mt76 ;;
        6) return ;;
    esac
}

install_firedragon() {
    sudo pacman -S --noconfirm firedragon
}

install_gaming_stack() {
    sudo pacman -S --noconfirm steam lutris gamemode mangohud goverlay protonup-qt \
        pipewire pipewire-jack lib32-pipewire pipewire-alsa pipewire-pulse
}

performance_tweaks() {

    # Enable zram
    echo "Enabling ZRAM..."
    sudo pacman -S --noconfirm zramswap
    sudo systemctl enable --now zramswap.service

    # CPU governor – performance mode
    echo "Setting CPU governor to performance..."
    sudo pacman -S --noconfirm cpupower
    echo "GOVERNOR='performance'" | sudo tee /etc/default/cpupower
    sudo systemctl enable --now cpupower.service

    # SSD fstrim weekly
    sudo systemctl enable --now fstrim.timer
}

plasma_tweaks() {
    kwriteconfig5 --file kwinrc --group Compositing --key MaxFPS 144
    kwriteconfig5 --file kwinrc --group Compositing --key RefreshRate 144
    kwriteconfig5 --file kwinrc --group KScreen --key ScaleFactor "1"
    kwriteconfig5 --file klaunchrc --group BusyCursorSettings --key Timeout 1

    echo "KDE tweaks applied. Log out & back in for effect."
}

# ============ MAIN UI LOOP ============

while true; do
    CHOICE=$(dialog --clear --stdout --title "Arch KDE Optimizer" \
    --menu "Select an action:" 20 60 10 \
    1 "Full System Update" \
    2 "Install Build Tools + yay" \
    3 "Enable Chaotic-AUR" \
    4 "Install KDE Plasma Desktop" \
    5 "Install Drivers" \
    6 "Install Firedragon Browser" \
    7 "Install Gaming Stack" \
    8 "Performance Optimizations (zram, CPU, SSD)" \
    9 "KDE Plasma UI Tweaks" \
    10 "Exit")

    clear
    case $CHOICE in
        1) system_update ;;
        2) install_build_tools ;;
        3) enable_chaotic ;;
        4) install_kde ;;
        5) install_drivers ;;
        6) install_firedragon ;;
        7) install_gaming_stack ;;
        8) performance_tweaks ;;
        9) plasma_tweaks ;;
        10) clear; echo "Done!"; exit 0 ;;
    esac
done
