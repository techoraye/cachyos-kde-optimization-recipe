# ✅ cachyos KDE Optimization Recipe

A complete interactive optimization script for **KDE Plasma on Arch-based systems**.  
Supports Arch Linux, EndeavourOS, CachyOS, Garuda, and other Arch derivatives.

---

## 📌 Overview
`Recipe.sh` provides a modular, menu-based installation and optimization system using a TUI powered by `dialog`.  
You choose exactly what you want: KDE setup, Chaotic-AUR, GPU drivers, gaming stack, performance tweaks, etc.

---

## ✨ Features

✔ Full system update  
✔ Build tools + yay + powerpill  
✔ Chaotic-AUR repository setup  
✔ KDE Plasma desktop + system utilities  
✔ GPU / WiFi driver selection  
✔ Gaming stack (Steam, Lutris, Gamemode, Mangohud, Proton)  
✔ Performance optimizations (zRAM, CPU governor, fstrim)  
✔ Plasma UI tweaks  
✔ Clean interactive menu

---

## ✅ Requirements

- Arch-based distro
- Sudo privileges
- Internet connection
- `dialog` (installed automatically if missing)
- Multilib enabled (recommended for gaming)

---

## 🚀 Installation & Usage

```bash
git clone https://github.com/techoraye/cachyos-kde-optimization-recipe.git
cd cachyos-kde-optimization-recipe
chmod +x Recipe.sh
./Recipe.sh
