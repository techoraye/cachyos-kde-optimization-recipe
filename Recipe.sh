#!/usr/bin/env bash
# chachyos-kde-optimizer (fixed & safe)
# Interactive Arch KDE optimization + driver/audio choices
# - Detects GPU
# - Avoids pipewire/jack2 conflicts (asks before removing)
# - Installs yay and optional powerpill via AUR if available
# - Chaotic-AUR setup (idempotent)
# - Logging
#
# Use at your own risk. Review actions before agreeing to destructive steps.

set -euo pipefail
LOGFILE="$HOME/arch-kde-optimizer.log"
exec > >(tee -a "$LOGFILE") 2>&1

# -- Helpers -------------------------------------------------------
die(){ echo "ERROR: $*"; exit 1; }
info(){ echo "INFO: $*"; }
warn(){ echo "WARN: $*"; }

# Ensure dialog is installed
if ! command -v dialog &>/dev/null; then
  echo "Installing dialog..."
  sudo pacman -S --noconfirm dialog || die "Failed to install dialog"
fi

# Confirm destructive action
confirm() {
  # $1 = message
  dialog --title "Confirm" --yesno "$1" 8 60
  return $?
}

# Run pacman install with logging and safety
pacman_install() {
  sudo pacman -S --noconfirm --needed "$@" || { warn "pacman failed for: $*"; return 1; }
}

# Install AUR helper yay if missing
ensure_yay() {
  if command -v yay &>/dev/null; then
    info "yay already installed"
    return 0
  fi
  info "Installing yay from AUR..."
  sudo pacman -S --noconfirm --needed base-devel git || die "Need base-devel/git"
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  pushd "$tmpdir/yay" >/dev/null
  makepkg -si --noconfirm || die "Failed to build yay"
  popd >/dev/null
  rm -rf "$tmpdir"
}

# Try install powerpill via yay (optional)
try_powerpill() {
  if command -v yay &>/dev/null; then
    if yay -Si powerpill &>/dev/null; then
      yay -S --noconfirm powerpill || warn "powerpill install failed"
    else
      info "powerpill not available in AUR/chaotic - skipping"
    fi
  fi
}

# Chaotic-AUR installer (idempotent)
enable_chaotic() {
  if grep -q '^\[chaotic-aur\]' /etc/pacman.conf 2>/dev/null; then
    info "Chaotic-AUR already in pacman.conf"
  else
    info "Importing chaotic keyring and mirrorlist..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || true
    sudo pacman-key --lsign-key 3056513887B78AEB || true
    sudo pacman -U --noconfirm \
      https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst \
      https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst || true
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
    sudo pacman -Syu --noconfirm || warn "pacman -Syu failed"
  fi
}

# Detect GPU vendor
detect_gpu() {
  vendor="unknown"
  if command -v lspci &>/dev/null; then
    gpu_line=$(lspci | grep -i -E 'vga|3d|display' | head -n1 || true)
    echo "Detected GPU line: $gpu_line"
    if echo "$gpu_line" | grep -iq 'nvidia'; then vendor="nvidia"; fi
    if echo "$gpu_line" | grep -iq 'amd|radeon'; then vendor="amd"; fi
    if echo "$gpu_line" | grep -iq 'intel'; then vendor="intel"; fi
  fi
  echo "$vendor"
}

# Audio backend: safe handling of pipewire vs jack2
install_audio_pipewire() {
  # If jack2 exists, warn and ask
  if pacman -Qi jack2 &>/dev/null; then
    if confirm "jack2 is installed. pipewire-jack conflicts with jack2. Remove jack2 and pulseaudio (if present) and install PipeWire?"; then
      info "Removing jack2/pulseaudio (may remove packages depending on them)..."
      sudo pacman -Rns --noconfirm jack2 jack2-dbus pulseaudio pulseaudio-jack 2>/dev/null || true
    else
      warn "User declined to remove jack2. Skipping PipeWire install."
      return 1
    fi
  fi

  pacman_install pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber helvum pipewire-v4l2 pipewire-zeroconf pipewire-roc pipewire-libcamera || warn "PipeWire install issues"
  # enable user wireplumber (pipewire runs in user session)
  systemctl --user enable --now wireplumber 2>/dev/null || true
  systemctl --user restart pipewire pipewire-pulse 2>/dev/null || true
  info "PipeWire installed and wireplumber started (user)."
}

install_audio_jack2() {
  # If pipewire-jack exists, warn and ask
  if pacman -Qi pipewire-jack &>/dev/null; then
    if confirm "pipewire-jack is installed. jack2 conflicts with pipewire-jack. Remove pipewire-jack and install jack2?"; then
      sudo pacman -Rns --noconfirm pipewire-jack pipewire 2>/dev/null || true
    else
      warn "User declined to remove PipeWire. Skipping jack2 install."
      return 1
    fi
  fi
  pacman_install jack2 jack2-dbus alsa-plugins-jack || warn "jack2 install issues"
}

# KDE install
install_kde() {
  pacman_install plasma-meta kde-utilities-meta kde-system-meta flatpak flatpak-kcm flatpak-xdg-utils gwenview adwaita-fonts materia-gtk-theme || warn "KDE install issues"
}

# Drivers menu actions
install_drivers_menu() {
  choice=$(dialog --stdout --menu "Choose GPU driver:" 12 60 6 \
    1 "Auto-detect & recommend" \
    2 "NVIDIA (proprietary)" \
    3 "Nouveau (open-source)" \
    4 "AMD (mesa + vulkan)" \
    5 "Intel (mesa + vulkan)" \
    6 "Return")
  case $choice in
    1)
      g=$(detect_gpu)
      case $g in
        nvidia)
          dialog --msgbox "Detected NVIDIA. Installing proprietary driver." 6 50
          pacman_install linux-cachyos-lts-nvidia-open opencl-nvidia nvidia-utils nvidia-settings || warn "nvidia install failed"
          ;;
        amd)
          dialog --msgbox "Detected AMD. Installing mesa + vulkan-radeon." 6 50
          pacman_install mesa vulkan-radeon radeontop amdgpu_top || warn "amd driver install failed"
          ;;
        intel)
          dialog --msgbox "Detected Intel. Installing mesa + vulkan-intel." 6 50
          pacman_install mesa vulkan-intel intel-media-driver || warn "intel driver install failed"
          ;;
        *)
          dialog --msgbox "GPU not detected. Choose driver from menu." 6 50
          install_drivers_menu
          ;;
      esac
      ;;
    2) pacman_install linux-cachyos-lts-nvidia-open opencl-nvidia nvidia-utils nvidia-settings || warn "nvidia install failed" ;;
    3) pacman_install xf86-video-nouveau mesa || warn "nouveau install failed" ;;
    4) pacman_install mesa vulkan-radeon radeontop amdgpu_top || warn "amd install failed" ;;
    5) pacman_install mesa vulkan-intel intel-media-driver || warn "intel install failed" ;;
    6) return ;;
  esac
}

# Build tools
install_build_tools() {
  pacman_install base-devel git cmake bison flex m4 patch pkgconf jdk8-openjdk icedtea-web || warn "build tools install failed"
  ensure_yay
  try_powerpill
}

# Gaming stack
install_gaming_stack() {
  # When installing steam & lib32 libs, multilib must be enabled - we assume user has it enabled
  pacman_install steam lutris gamemode lib32-gamemode mangohud lib32-mangohud protonup-qt pipewire-jack pipewire-alsa pipewire-pulse || warn "gaming stack install issues"
}

# Performance tweaks
performance_tweaks() {
  # zram via zramswap or zram-generator? We'll install zramswap (simple)
  pacman_install zramswap || warn "zramswap not available"
  sudo systemctl enable --now zramswap.service || warn "failed to enable zramswap"

  # cpupower
  pacman_install cpupower || warn "cpupower install issue"
  echo "GOVERNOR='performance'" | sudo tee /etc/default/cpupower >/dev/null
  sudo systemctl enable --now cpupower.service || warn "failed to enable cpupower"

  # fstrim
  sudo systemctl enable --now fstrim.timer || warn "failed to enable fstrim.timer"
}

# Firedragon
install_firedragon() {
  if pacman -Si firedragon &>/dev/null || yay -Si firedragon &>/dev/null; then
    pacman_install firedragon || { warn "firedragon via pacman failed; trying yay..."; yay -S --noconfirm firedragon || warn "firedragon install failed" ; }
  else
    warn "firedragon not found in repos. Enable Chaotic-AUR or use AUR."
  fi
}

# KDE UI tweaks
plasma_tweaks() {
  # apply safe tweaks
  kwriteconfig5 --file kwinrc --group Compositing --key MaxFPS 144 || warn "kwriteconfig5 failed"
  kwriteconfig5 --file kwinrc --group Compositing --key RefreshRate 144 || true
  kwriteconfig5 --file klaunchrc --group BusyCursorSettings --key Timeout 1 || true
  dialog --msgbox "KDE tweaks applied. Log out and log back in for full effect." 6 60
}

# Auto Mode: best-practice full install
auto_mode() {
  dialog --infobox "Auto Mode: Updating system..." 5 60; sleep 1
  sudo pacman -Syu --noconfirm || warn "system update failed"
  install_build_tools
  enable_chaotic
  install_kde
  # prefer PipeWire unless user has jack2 and declines removal
  if pacman -Qi jack2 &>/dev/null; then
    if confirm "jack2 is installed. Auto Mode will install PipeWire and remove jack2. Continue?"; then
      install_audio_pipewire || warn "pipewire issues"
    else
      install_audio_jack2 || warn "jack2 install skipped"
    fi
  else
    install_audio_pipewire || install_audio_jack2 || warn "audio backend install issues"
  fi
  install_drivers_menu
  install_gaming_stack
  performance_tweaks
  plasma_tweaks
  dialog --msgbox "Auto Mode complete. Reboot recommended." 6 60
}

# Main menu loop
while true; do
  CHOICE=$(dialog --stdout --title "Arch KDE Optimizer" --menu "Choose an action:" 20 70 12 \
    1 "Full System Update" \
    2 "Install Build Tools + yay (optional powerpill)" \
    3 "Enable Chaotic-AUR" \
    4 "Install KDE Plasma Desktop" \
    5 "Install Drivers (menu)" \
    6 "Install Firedragon Browser" \
    7 "Install Gaming Stack" \
    8 "Audio Backend (PipeWire or jack2)" \
    9 "Performance Optimizations (zRAM, cpupower, fstrim)" \
    10 "KDE UI Tweaks" \
    11 "Auto Mode (recommended)" \
    12 "Exit")
  ret=$?
  clear
  if [ $ret -ne 0 ]; then
    echo "Cancelled. Exiting."
    exit 0
  fi

  case $CHOICE in
    1) sudo pacman -Syu --noconfirm || warn "update failed" ;;
    2) install_build_tools ;;
    3) enable_chaotic ;;
    4) install_kde ;;
    5) install_drivers_menu ;;
    6) install_firedragon ;;
    7) install_gaming_stack ;;
    8)
       AUDIO_CHOICE=$(dialog --stdout --menu "Choose audio backend:" 12 60 4 \
         1 "PipeWire (recommended)" \
         2 "jack2 (legacy JACK)" \
         3 "Return")
       case $AUDIO_CHOICE in
         1) install_audio_pipewire || dialog --msgbox "PipeWire install skipped or failed." 6 50 ;;
         2) install_audio_jack2 || dialog --msgbox "jack2 install skipped or failed." 6 50 ;;
         3) ;;
       esac
       ;;
    9) performance_tweaks ;;
    10) plasma_tweaks ;;
    11) auto_mode ;;
    12) echo "Done. Logfile: $LOGFILE"; exit 0 ;;
    *) echo "Invalid option" ;;
  esac
done
