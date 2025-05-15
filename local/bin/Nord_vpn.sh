#!/usr/bin/env bash
#             __ _                           _
#  _ __ ___  / _(_)      _ __   ___  _ __ __| |_   ___ __  _ __
# | '__/ _ \| |_| |_____| '_ \ / _ \| '__/ _` \ \ / / '_ \| '_ \
# | | | (_) |  _| |_____| | | | (_) | | | (_| |\ V /| |_) | | | |
# |_|  \___/|_| |_|     |_| |_|\___/|_|  \__,_| \_/ | .__/|_| |_|
#                                                   |_|

# exit when any command fails
set -e

echoexit() {
    # Print to stderr and exit
    printf "%s\n" "$@" 1>&2
    exit 1
}

# Checking dependencies:
type nordvpn >/dev/null || echoexit "'nordvpn' not found."
type rofi >/dev/null || echoexit "'rofi' not found."

completion_to_lines() {
    tr '\r\b\t' '\n' | sed '/^[[:space:]]*$/d'
}

menu() {
    # Menu command, should read from stdin and write to stdout.
    local stdin
    local line_count
    stdin="$(cat)"
    line_count="$(printf "%s" "$stdin" | wc -l)"

    if [ "$line_count" -lt 5 ]; then
        printf "%s" "$stdin" | sort | rofi -dmenu -i -p "NordVPN" -no-custom -l "$((line_count + 1))"
    else
        printf "%s" "$stdin" | sort | rofi -dmenu -i -p "NordVPN" -no-custom
    fi
}

usage() {
    printf "Dynamic menu interface for nordvpn.

Usage:
  rofi-nordvpn [-h] [-s]
    -h                                 Display this help message.
    -s                                 Display current vpn status, useful for status bars.
"
}

# Initial menu.
init_menu() {
    local choices
    choices=" Connect\n Disconnect\n Nord Status\n Nord Settings"
    printf "%b" "$choices" | menu
}

# nordvpn connect menu.
connect() {
    local choices
    choices=" Auto Connect\n Country\n City\n Use p2p\n Use onion"
    printf "%b" "$choices" | menu
}

# Country selection menu.
countries() {
    # script needed to avoid it crashing when called from status bar (https://github.com/loiccoyle/rofi-nordvpn/issues/1)
    script -q -c "sudo nordvpn connect --generate-bash-completion" /dev/null | completion_to_lines | menu
}

# City selection menu.
# Arg:
#   $1: a country
cities() {
    script -q -c "sudo nordvpn connect $1 --generate-bash-completion" /dev/null | completion_to_lines | menu
}

# Print the vpn status, for status bars.
status() {
    local status
    status="$(sudo nordvpn status | tr -d '\r -')"
    if [ -n "${status##*Connected*}" ]; then
        printf "Off"
    else
        printf "%s" "$(printf "%s" "$status" | grep "City" | cut -d ":" -f 2)"
    fi
}

# Show vpn status menu.
vpn_status() {
    local choices
    choices="$(sudo nordvpn status | tr -d '\r-' | sed 's/^ *//')"
    printf "%s" "$choices" | menu
}

# Show vpn settings.
settings() {
    local choices
    choices="$(sudo nordvpn settings | tr -d '\r-' | sed 's/^ *//')"
    printf "%s" "$choices" | menu
}

# Parse options to the `rofi-nordvpn` command
while getopts ":hs" opt; do
    case ${opt} in
    h)
        usage
        exit 0
        ;;
    s)
        status
        exit 0
        ;;
    \?)
        printf "Invalid Option: -%s\n" "$OPTARG" 1>&2
        usage
        exit 1
        ;;
    esac
done

case "$(init_menu)" in
" Connect")
    case $(connect) in
    " Auto Connect")
        sudo nordvpn connect
        ;;
    " Country")
        country="$(countries)"
        [ -n "$country" ] && sudo nordvpn connect "$country"
        ;;
    " City")
        country="$(countries)"
        [ -n "$country" ] && city="$(cities "$country")"
        [ -n "$city" ] && sudo nordvpn connect "$country" "$city"
        ;;
    " Use p2p")
        sudo nordvpn connect p2p
        ;;
    " Use onion")
        sudo nordvpn connect onion_over_vpn
        ;;
    *) ;;

    esac
    ;;
" Disconnect")
    sudo nordvpn disconnect
    ;;
" Nord Status")
    vpn_status
    ;;
" Nord Settings")
    settings
    ;;
*) ;;

esac
