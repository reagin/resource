#!/usr/bin/env bash

# name: message.lib.sh
# author: reagin
# github: https://github.com/reagin/resource
# description: format output information

# enable the following shell options:
# -E: ensure that err trap is also valid in function, subshell, and command replacements
# -e: when any command exits in a non-zero state, exit the script immediately
# -u: when using undefined variables, the script will report an error and exit
# -o pipefail: when any command in the pipeline fails, the entire pipeline returns to a failed state
set -Eeuo pipefail

export lib_command_dependency=('sed' 'tput')
export lib_package_dependency=('sed' 'ncurses-bin')

# Define cursor variables
export sgr_reset="\x1B[0m"
export sgr_bold="\x1B[1m"
export sgr_faint="\x1B[2m"
export sgr_italic="\x1B[3m"
export sgr_underline="\x1B[4m"
export sgr_invert="\x1B[7m"
export sgr_strike="\x1B[9m"
# Define color variables
export foreground_color_black="\x1B[38;2;0;0;0m"
export foreground_color_blue="\x1B[38;2;0;135;215m"
export foreground_color_green="\x1B[38;2;0;175;0m"
export foreground_color_grey="\x1B[38;2;128;128;128m"
export foreground_color_purple="\x1B[38;2;175;175;255m"
export foreground_color_red="\x1B[38;2;215;0;0m"
export foreground_color_yellow="\x1B[38;2;215;215;95m"
export background_color_balck="\x1B[48;2;0;0;0m"
export background_color_blue="\x1B[48;2;0;120;200m"
export background_color_green="\x1B[48;2;0;160;0m"
export background_color_grey="\x1B[48;2;120;120;120m"
export background_color_purple="\x1B[48;2;160;160;220m"
export background_color_red="\x1B[48;2;200;0;0m"
export background_color_yellow="\x1B[48;2;200;200;90m"

# -------------------------------------------------------------------
# show_content_left
#
# description:
#   prints the given arguments aligned to the left edge of the
#   terminal
#
# arguments:
#   $@ - the text to display
#
# usage:
#   show_content_left "left aligned text"
# -------------------------------------------------------------------
show_content_left() {
  echo -ne "\x1B[1G${*}"
}

# -------------------------------------------------------------------
# show_content_center
#
# description:
#   prints the given arguments centered horizontally in the terminal.
#   strips ansi escape sequences to calculate the correct width
#
# arguments:
#   $@ - the text to display
#
# usage:
#   show_content_center "centered text"
# -------------------------------------------------------------------
show_content_center() {
  local plain_text term_width padding_width
  # Escape strings and remove control characters
  plain_text=$(echo -ne "${*}" | sed -E 's/\x1B\[[0-9;]*[mK]//g')
  # When the tput instruction error occurs, set the terminal width to the string length
  term_width=$(tput cols 2>/dev/null || echo ${#plain_text})
  padding_width=$(((term_width - ${#plain_text}) / 2))
  ((padding_width < 0)) && padding_width=0
  echo -ne "\x1B[${padding_width}G${*}"
}

# -------------------------------------------------------------------
# show_content_right
#
# description:
#   prints the given arguments aligned to the right edge of the
#   terminal. strips ansi escape sequences to calculate the correct
#   width
#
# arguments:
#   $@ - the text to display
#
# usage:
#   show_content_right "right aligned text"
# -------------------------------------------------------------------
show_content_right() {
  local plain_text term_width padding_width
  # Escape strings and remove control characters
  plain_text=$(echo -ne "${*}" | sed -E 's/\x1B\[[0-9;]*[mK]//g')
  # When the tput instruction error occurs, set the terminal width to the string length
  term_width=$(tput cols 2>/dev/null || echo ${#plain_text})
  padding_width=$((term_width - ${#plain_text}))
  ((padding_width < 0)) && padding_width=0
  echo -ne "\x1B[${padding_width}G${*}"
}

# -------------------------------------------------------------------
# show_text
#
# description:
#   prints the given arguments as an message in faint font
#
# arguments:
#   $@ - the text to display
#
# usage:
#   show_text "this is an faint message"
# -------------------------------------------------------------------
show_text() {
  echo -ne "${sgr_faint}${*}${sgr_reset}"
}

# -------------------------------------------------------------------
# show_info
#
# description:
#   prints the given arguments as an info message in blue color
#
# arguments:
#   $@ - the text to display
#
# usage:
#   show_info "this is an info message"
# -------------------------------------------------------------------
show_info() {
  echo -ne "${foreground_color_blue}[INFO]${sgr_reset} ${sgr_faint}${*}${sgr_reset}"
}

# -------------------------------------------------------------------
# show_warn
#
# description:
#   prints the given arguments as a warning message in yellow color
#
# arguments:
#   $@ - the text to display
#
# usage:
#   show_warn "this is a warning message"
# -------------------------------------------------------------------
show_warn() {
  echo -ne "${foreground_color_yellow}[WARN]${sgr_reset} ${sgr_faint}${*}${sgr_reset}"
}

# -------------------------------------------------------------------
# show_error
#
# description:
#   prints the given arguments as an error message in red color
#
# arguments:
#   $@ - the text to display
#
# usage:
#   show_error "this is an error message"
# -------------------------------------------------------------------
show_error() {
  echo -ne "${foreground_color_red}[ERROR]${sgr_reset} ${sgr_faint}${*}${sgr_reset}"
}

# -------------------------------------------------------------------
# show_success
#
# description:
#   prints the given arguments as a success message in green color
#
# arguments:
#   $@ - the text to display
#
# usage:
#   show_success "this is a success message"
# -------------------------------------------------------------------
show_success() {
  echo -ne "${foreground_color_green}[SUCCESS]${sgr_reset} ${sgr_faint}${*}${sgr_reset}"
}
