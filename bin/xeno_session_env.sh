#!/usr/bin/env bash
# Source this file to export the active graphical session environment.
# Works when called from adapter, cron, or a bare terminal (no DISPLAY set).
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/xeno_session_env.sh"

_VARS="DISPLAY|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR|XAUTHORITY"

# Read environment from the running graphical session process.
for _proc in gnome-session gnome-shell; do
    _pid=$(pgrep -u "$USER" -f "$_proc" 2>/dev/null | head -1)
    if [ -n "$_pid" ]; then
        while IFS='=' read -r _key _val; do
            export "$_key=$_val"
        done < <(cat /proc/"$_pid"/environ 2>/dev/null | tr '\0' '\n' | grep -E "^($_VARS)=")
        break
    fi
done
unset _VARS _proc _pid _key _val

# Fallback defaults if session process was not found.
export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Resolve XAUTHORITY if missing or pointing to a non-existent file.
# On GNOME/Wayland, XWayland uses a temporary auth file under XDG_RUNTIME_DIR.
if [ -z "$XAUTHORITY" ] || [ ! -f "$XAUTHORITY" ]; then
    _auth=$(ls "$XDG_RUNTIME_DIR"/.mutter-Xwaylandauth.* 2>/dev/null | head -1)
    [ -n "$_auth" ] && export XAUTHORITY="$_auth"
fi
if [ -z "$XAUTHORITY" ] || [ ! -f "$XAUTHORITY" ]; then
    [ -f "$HOME/.Xauthority" ] && export XAUTHORITY="$HOME/.Xauthority"
fi
unset _auth
