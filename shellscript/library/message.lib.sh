#!/usr/bin/env bash

# message.lib.sh
# Author: rehuony
# Description: Format output information
# GitHub: https://github.com/rehuony/resource

# Enable the following shell options:
# -E: Ensure that ERR trap is also valid in function, subshell, and command replacements
# -e: When any command exits in a non-zero state, exit the script immediately
# -u: When using undefined variables, the script will report an error and exit
# -o pipefail: When any command in the pipeline fails, the entire pipeline returns to a failed state
set -Eeuo pipefail

lib_command_dependency=('sed' 'tput')
lib_package_dependency=('sed' 'ncurses-bin')

# Define cursor variables
readonly sgr_reset="\e[0m"
readonly sgr_bold="\e[1m"
readonly sgr_faint="\e[2m"
readonly sgr_italic="\e[3m"
readonly sgr_underline="\e[4m"
readonly sgr_invert="\e[7m"
readonly sgr_strike="\e[9m"
# Define color variables
readonly foreground_color_black="\e[38;2;0;0;0m"
readonly foreground_color_blue="\e[38;2;0;135;215m"
readonly foreground_color_green="\e[38;2;0;175;0m"
readonly foreground_color_grey="\e[38;2;128;128;128m"
readonly foreground_color_purple="\e[38;2;175;175;255m"
readonly foreground_color_red="\e[38;2;215;0;0m"
readonly foreground_color_yellow="\e[38;2;215;215;95m"
readonly background_color_balck="\e[48;2;0;0;0m"
readonly background_color_blue="\e[48;2;0;120;200m"
readonly background_color_green="\e[48;2;0;160;0m"
readonly background_color_grey="\e[48;2;120;120;120m"
readonly background_color_purple="\e[48;2;160;160;220m"
readonly background_color_red="\e[48;2;200;0;0m"
readonly background_color_yellow="\e[48;2;200;200;90m"

# -------------------------------------------------------------------
# show_text
#
# Description:
#   Prints the given arguments as text to the terminal
#
# Arguments:
#   $@ - The text to display
#
# Usage:
#   show_text "Hello, World!"
# -------------------------------------------------------------------
show_text() {
  printf "${*}"
}

# -------------------------------------------------------------------
# show_left_text
#
# Description:
#   Prints the given arguments aligned to the left edge of the
#   terminal
#
# Arguments:
#   $@ - The text to display
#
# Usage:
#   show_left_text "Left aligned text"
# -------------------------------------------------------------------
show_left_text() {
  printf "\e[1G${*}"
}

# -------------------------------------------------------------------
# show_center_text
#
# Description:
#   Prints the given arguments centered horizontally in the terminal.
#   Strips ANSI escape sequences to calculate the correct width
#
# Arguments:
#   $@ - The text to display
#
# Usage:
#   show_center_text "Centered text"
# -------------------------------------------------------------------
show_center_text() {
  local plain_text term_width padding_width
  # Escape strings and remove control characters
  plain_text=$(echo -ne "${*}" | sed -E 's/\x1B\[[0-9;]*[mK]//g')
  # When the tput instruction error occurs, set the terminal width to the string length
  term_width=$(tput cols 2>/dev/null || echo ${#plain_text})
  padding_width=$(((term_width - ${#plain_text}) / 2))
  ((padding_width < 0)) && padding_width=0
  printf "\e[${padding_width}G${*}"
}

# -------------------------------------------------------------------
# show_right_text
#
# Description:
#   Prints the given arguments aligned to the right edge of the
#   terminal. Strips ANSI escape sequences to calculate the correct
#   width
#
# Arguments:
#   $@ - The text to display
#
# Usage:
#   show_right_text "Right aligned text"
# -------------------------------------------------------------------
show_right_text() {
  local plain_text term_width padding_width
  # Escape strings and remove control characters
  plain_text=$(echo -ne "${*}" | sed -E 's/\x1B\[[0-9;]*[mK]//g')
  # When the tput instruction error occurs, set the terminal width to the string length
  term_width=$(tput cols 2>/dev/null || echo ${#plain_text})
  padding_width=$((term_width - ${#plain_text}))
  ((padding_width < 0)) && padding_width=0
  printf "\e[${padding_width}G${*}"
}

# -------------------------------------------------------------------
# show_info
#
# Description:
#   Prints the given arguments as an info message in blue color
#
# Arguments:
#   $@ - The text to display
#
# Usage:
#   show_info "This is an info message"
# -------------------------------------------------------------------
show_info() {
  printf "${foreground_color_blue}[INFO]${sgr_reset} ${sgr_faint}${*}${sgr_reset}"
}

# -------------------------------------------------------------------
# show_warn
#
# Description:
#   Prints the given arguments as a warning message in yellow color
#
# Arguments:
#   $@ - The text to display
#
# Usage:
#   show_warn "This is a warning message"
# -------------------------------------------------------------------
show_warn() {
  printf "${foreground_color_yellow}[WARN]${sgr_reset} ${sgr_faint}${*}${sgr_reset}"
}

# -------------------------------------------------------------------
# show_error
#
# Description:
#   Prints the given arguments as an error message in red color
#
# Arguments:
#   $@ - The text to display
#
# Usage:
#   show_error "This is an error message"
# -------------------------------------------------------------------
show_error() {
  printf "${foreground_color_red}[ERROR]${sgr_reset} ${sgr_faint}${*}${sgr_reset}"
}

# -------------------------------------------------------------------
# show_success
#
# Description:
#   Prints the given arguments as a success message in green color
#
# Arguments:
#   $@ - The text to display
#
# Usage:
#   show_success "This is a success message"
# -------------------------------------------------------------------
show_success() {
  printf "${foreground_color_green}[SUCCESS]${sgr_reset} ${sgr_faint}${*}${sgr_reset}"
}
