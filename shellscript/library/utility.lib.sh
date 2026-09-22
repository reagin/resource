#!/usr/bin/env bash

# name: utility.lib.sh
# author: reagin
# github: https://github.com/reagin/resource
# description: file installation, user input and configuration helpers
#
# this file is meant to be sourced by bootstrap.lib.sh after
# message.lib.sh (it relies on the color variables defined there) and
# does not set shell options itself
#
# color variables come from message.lib.sh, lib_dependencies is read by
# bootstrap.lib.sh
# shellcheck disable=SC2154,SC2034

lib_dependencies=('grep:grep' 'awk:gawk' 'install:coreutils')

# -------------------------------------------------------------------
# install_content
#
# description:
#   installs the given content to a specified destination file with
#   defined permissions, owner, and group. the content is written
#   verbatim (no escape sequence interpretation) followed by a single
#   trailing newline; empty content produces an empty file. missing
#   parent directories are created. if the destination already exists,
#   a backup is created with a ".bak" suffix
#
# arguments:
#   $1 - file mode (e.g. "644" or "0644")
#   $2 - owner and group (e.g. "root" or "root:root")
#   $3 - content to be written to the file
#   $4 - absolute path to the destination file
#   $5 - whether to delete the backup file (e.g. "true" or "false")
#
# returns:
#   0 - install content success
#   1 - parameter error or operation failed
#
# usage:
#   install_content 644 "root:root" "content" "/path/to/destination"
# -------------------------------------------------------------------
install_content() {
  local mode owner group content destination removeflag
  local backupfile tempfile created_root

  mode="${1:-}"
  owner="${2%%:*}"
  group="${2##*:}"
  content="${3:-}"
  destination="${4:-}"
  removeflag="${5:-false}"
  backupfile="${destination}.bak"

  # Exit if the key parameter is empty
  [[ -n "${mode}" && -n "${owner}" && -n "${group}" && -n "${destination}" ]] || return 1
  # Ensure file permission is an octal mode such as 644 or 0644
  [[ "${mode}" =~ ^[0-7]{3,4}$ ]] || return 1
  # Ensure destination is an absolute path and not a directory
  [[ "${destination}" == /* ]] || return 1
  [[ -d "${destination}" ]] && return 1

  # Find the topmost directory that has to be created so it can be
  # removed again if the installation fails
  created_root="${destination}"
  while [[ ! -d "$(dirname "${created_root}")" ]]; do
    created_root="$(dirname "${created_root}")"
  done
  [[ "${created_root}" == "${destination}" ]] && created_root=""

  tempfile=$(mktemp -t tempfile_XXXXXX 2>/dev/null) || return 1

  if [[ -n "${content}" ]]; then
    printf '%s\n' "${content}" >"${tempfile}"
  else
    : >"${tempfile}"
  fi

  # Back up the file if it exists
  [[ -f "${destination}" ]] && cp -p "${destination}" "${backupfile}"

  if ! mkdir -p "$(dirname "${destination}")" 2>/dev/null ||
    ! install -m "${mode}" -o "${owner}" -g "${group}" "${tempfile}" "${destination}" 2>/dev/null; then
    rm -f "${tempfile}"
    [[ -n "${created_root}" && -d "${created_root}" ]] && rm -rf "${created_root}"
    return 1
  fi

  rm -f "${tempfile}"
  [[ "${removeflag}" == "true" ]] && rm -f "${backupfile}"
  return 0
}

# -------------------------------------------------------------------
# install_content_with_comment
#
# description:
#   calls install_content and prints status messages to the console
#
# arguments:
#   same as install_content
#
# returns:
#   the return value of install_content
#
# usage:
#   install_content_with_comment 644 "root:root" "content" "/path/to/destination"
# -------------------------------------------------------------------
install_content_with_comment() {
  echo -ne "${foreground_color_grey}installing content for ${4:-} - "
  if install_content "${@}"; then
    echo -ne "${foreground_color_green}done${sgr_reset}\n"
    return 0
  else
    echo -ne "${foreground_color_red}error${sgr_reset}\n"
    return 1
  fi
}

# -------------------------------------------------------------------
# remove_content
#
# description:
#   removes the specified file or directory. the path must be absolute
#   and normalized (no "." / ".." components) and may not be "/". if
#   the destination does not exist, the function exits successfully
#
# arguments:
#   $1 - absolute path to the file or directory to remove
#
# returns:
#   0 - remove content success
#   1 - parameter error or operation failed
#
# usage:
#   remove_content "/path/to/destination"
# -------------------------------------------------------------------
remove_content() {
  local destination

  destination="${1:-}"

  [[ -n "${destination}" && "${destination}" == /* && "${destination}" != "/" ]] || return 1
  [[ "${destination}" != *"/./"* && "${destination}" != *"/../"* ]] || return 1
  [[ "${destination}" != *"/." && "${destination}" != *"/.." ]] || return 1

  [[ -e "${destination}" || -L "${destination}" ]] || return 0

  rm -rf "${destination}" &>/dev/null || return 1
}

# -------------------------------------------------------------------
# remove_content_with_comment
#
# description:
#   calls remove_content and prints status messages to the console
#
# arguments:
#   $1 - absolute path to the file or directory to remove
#
# returns:
#   the return value of remove_content
#
# usage:
#   remove_content_with_comment "/path/to/destination"
# -------------------------------------------------------------------
remove_content_with_comment() {
  echo -ne "${foreground_color_grey}removing content for ${1:-} - "
  if remove_content "${1:-}"; then
    echo -ne "${foreground_color_green}done${sgr_reset}\n"
    return 0
  else
    echo -ne "${foreground_color_red}error${sgr_reset}\n"
    return 1
  fi
}

# -------------------------------------------------------------------
# read_input_line
#
# description:
#   reads one line of user input into the named variable. the
#   controlling terminal is preferred so prompts work when the script
#   itself is piped into bash. without a terminal, stdin is used only
#   when the script runs from a file ($0 is a regular file); when the
#   script body itself comes from stdin ("curl | bash" without a tty)
#   reading is refused so the script text is never consumed as input
#
# arguments:
#   $1 - name of the variable to store the input in
#   $@ - additional options passed to read (e.g. -s -p "prompt: ")
#
# returns:
#   0 - a line was read
#   1 - end of input or no usable input source
#
# usage:
#   read_input_line answer -p "continue? "
# -------------------------------------------------------------------
read_input_line() {
  local __target="${1}" __editing=(-e) __option
  shift

  # readline editing is pointless (and echoes) for silent input
  for __option in "${@}"; do
    [[ "${__option}" == "-s" ]] && __editing=()
  done

  if { : </dev/tty; } &>/dev/null; then
    read -r "${__editing[@]}" "${@}" "${__target?}" </dev/tty
  elif [[ -f "${0}" ]]; then
    read -r "${@}" "${__target?}"
  else
    return 1
  fi
}

# -------------------------------------------------------------------
# get_input_message
#
# description:
#   prompts the user for input with a given message and returns the
#   input. an empty string is returned at end of input
#
# arguments:
#   $1 - prompt message to display to the user
#
# returns:
#   the user input on stdout
#
# usage:
#   get_input_message "prompt information"
# -------------------------------------------------------------------
get_input_message() {
  local prompt input_message=""

  prompt="${1:-}"

  read_input_line input_message -p "${prompt}" || true
  printf '%s' "${input_message}"
}

# -------------------------------------------------------------------
# get_input_until_success
#
# description:
#   continuously prompts the user for input with a given message
#   until valid input is provided. optionally validates the input
#   against a regular expression and displays a custom error message
#   if validation fails. when $4 is "true" the input is not echoed
#   (for passwords and tokens)
#
# arguments:
#   $1 - prompt message to display to the user
#   $2 - (optional) regular expression to validate the input
#   $3 - (optional) error message to display if validation fails
#   $4 - (optional) "true" to hide the typed input
#
# returns:
#   0 - the valid user input is printed on stdout
#   1 - end of input reached before a valid value was entered
#
# usage:
#   get_input_until_success "enter your name: "
#   get_input_until_success "enter a number: " '^[0-9]+$' "input must be a number"
#   get_input_until_success "enter token: " '' '' true
# -------------------------------------------------------------------
get_input_until_success() {
  local prompt validate error_message secret input_message
  local -a read_options

  prompt="${1:-}"
  validate="${2:-}"
  error_message="${3:-invalid input, please try again}"
  secret="${4:-false}"

  read_options=(-p "${prompt}")
  [[ "${secret}" == "true" ]] && read_options=(-s -p "${prompt}")

  while read_input_line input_message "${read_options[@]}"; do
    [[ "${secret}" == "true" ]] && echo >&2

    if [[ -z "${input_message}" ]]; then
      echo -ne "${foreground_color_yellow}input cannot be empty, please try again${sgr_reset}\n" >&2
      continue
    fi

    if [[ -n "${validate}" ]] && ! grep -Eiq -- "${validate}" <<<"${input_message}"; then
      echo -ne "${foreground_color_yellow}${error_message}${sgr_reset}\n" >&2
      continue
    fi

    printf '%s' "${input_message}"
    return 0
  done

  echo -ne "${foreground_color_red}no input available for: ${prompt}${sgr_reset}\n" >&2
  return 1
}

# -------------------------------------------------------------------
# load_ini_config
#
# description:
#   loads the value of a given key from an ini-style configuration
#   file. ignores commented lines and trims whitespace. the value is
#   everything after the first "=", so values may contain "=". only
#   supports simple key=value pairs (no section support)
#
# arguments:
#   $1 - key to search
#   $2 - path to the ini configuration file
#
# returns:
#   the value of the key on stdout, or nothing if not found
#
# usage:
#   load_ini_config "key" "/path/to/config.ini"
# -------------------------------------------------------------------
load_ini_config() {
  local ini_key ini_path

  ini_key="${1:-}"
  ini_path="${2:-}"

  [[ -n "${ini_key}" && -r "${ini_path}" ]] || return 0

  awk -v search_key="${ini_key}" '
    /^[[:space:]]*[#;]/ { next }        # Skip comments
    /^[[:space:]]*$/ { next }           # Skip empty lines
    {
      position = index($0, "=")
      if (position == 0) { next }
      key = substr($0, 1, position - 1)
      value = substr($0, position + 1)
      gsub(/^[ \t]+|[ \t]+$/, "", key)  # Trim whitespace from key
      gsub(/^[ \t]+|[ \t]+$/, "", value)  # Trim whitespace from value
      if (key == search_key) {
        print value
        exit
      }
    }
  ' "${ini_path}"
}
