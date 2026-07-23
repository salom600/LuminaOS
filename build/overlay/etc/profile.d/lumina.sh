# /etc/profile.d/lumina.sh — sourced by every login shell
# Path & prompt customization for LuminaOS.

# Make scripts under /usr/share/lumina available everywhere
export PATH="$PATH:/usr/share/lumina/bin"

# Pretty colored prompt (cyan user@host, blue path, green $)
if [ "$(id -u)" -eq 0 ]; then
    PS1='\[\e[1;31m\]\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]# '
else
    PS1='\[\e[1;36m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]$ '
fi

# Editor
export EDITOR=vim
export VISUAL=vim
export PAGER=less

# Less colors
export LESS='-R'
export LESSOPEN='|/usr/bin/lesspipe %s'

# Locale fallback
export LANG=en_US.UTF-8
export LC_COLLATE=C

# XDG
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Wayland apps prefer this
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland
export _JAVA_AWT_WM_NONREPARENTING=1
