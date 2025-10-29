#!/usr/bin/env bash

# name: utility.lib.sh
# author: reagin
# github: https://github.com/reagin/resource
# description: template file used to create library shellscript

# enable the following shell options:
# -E: ensure that err trap is also valid in function, subshell, and command replacements
# -e: when any command exits in a non-zero state, exit the script immediately
# -u: when using undefined variables, the script will report an error and exit
# -o: pipefail: when any command in the pipeline fails, the entire pipeline returns to a failed state
set -Eeuo pipefail

export lib_command_dependency=('curl' 'grep' 'awk' 'md5sum' 'uuidgen')
export lib_package_dependency=('curl' 'grep' 'gawk' 'coreutils' 'uuid-runtime')

readonly sgr_reset="\x1B[0m"
readonly foreground_color_red="\x1B[38;2;215;0;0m"
readonly foreground_color_grey="\x1B[38;2;128;128;128m"
readonly foreground_color_green="\x1B[38;2;0;175;0m"
readonly foreground_color_yellow="\x1B[38;2;215;215;95m"

# -------------------------------------------------------------------
# install_content
#
# description:
#   installs the given content to a specified destination file with
#   defined permissions, owner, and group. creates a temporary file
#   to hold the content before installing. if the destination
#   already exists, a backup is created with a ".bak" suffix
#
# arguments:
#   $1 - file mode (e.g. "644")
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
  local backupfile content destination group mode owner removeflag tempfile junkfolder

  mode="${1}"
  owner="${2%%:*}"
  group="${2##*:}"
  content="${3}"
  destination="${4}"
  removeflag="${5:-false}"
  junkfolder="${destination}"
  backupfile="${destination}.bak"

  # Exit if the key parameter is empty
  [[ -n "${mode}" && -n "${owner}" && -n "${group}" && -n "${destination}" ]] || return 1
  # Ensure file permission is in 644 format
  [[ "${mode}" =~ ^[0-7]{3}$ ]] || return 1
  # Exit if target file is a folder
  [[ -e "${destination}" && -d "${destination}" ]] && return 1
  # Back up the file if it exists
  [[ -e "${destination}" && -f "${destination}" ]] && {
    cp "${destination}" "${backupfile}"
  }

  while true; do
    [[ -d "$(dirname "${junkfolder}")" ]] && break
    junkfolder="$(dirname "${junkfolder}")"
  done

  tempfile=$(mktemp -t tempfile_XXXXXX 2>/dev/null) || {
    [[ -f "${tempfile}" ]] && rm -rf "${tempfile}"
    return 1
  }
  mkdir -p "$(dirname "${destination}")" 2>/dev/null || {
    [[ -d "${junkfolder}" ]] && rm -rf "${junkfolder}"
    return 1
  }

  echo -ne "${content}" >"${tempfile}"

  install -m "${mode}" -o "${owner}" -g "${group}" "${tempfile}" "${destination}" 2>/dev/null || {
    [[ -d "${junkfolder}" ]] && rm -rf "${junkfolder}"
    [[ -f "${tempfile}" ]] && rm -rf "${tempfile}"
    return 1
  }

  [[ -f "${tempfile}" ]] && rm -rf "${tempfile}"
  [[ "${removeflag}" == "false" ]] || rm -rf "${backupfile}"
}

# -------------------------------------------------------------------
# install_content_with_comment
#
# description:
#   calls install_content to install the given content to a specified
#   destination file with defined permissions, owner, and group, and
#   prints status messages to the console. if the destination already
#   exists, a backup is created with a ".bak" suffix.
#
# arguments:
#   $1 - file mode (e.g. "644")
#   $2 - owner and group (e.g. "root" or "root:root")
#   $3 - content to be written to the file
#   $4 - absolute path to the destination file
#   $5 - whether to delete the backup file (e.g. "true" or "false")
#
# usage:
#   install_content_with_comment 644 "root:root" "content" "/path/to/destination"
# -------------------------------------------------------------------
install_content_with_comment() {
  echo -ne "${foreground_color_grey}installing content for ${4} - "
  if install_content "${@}"; then
    echo -ne "${foreground_color_green}done${sgr_reset}\n"
  else
    echo -ne "${foreground_color_red}error${sgr_reset}\n"
  fi
}

# -------------------------------------------------------------------
# remove_content
#
# description:
#   removes the specified file or directory at the given absolute
#   path. if the destination does not exist, the function exits
#   successfully. prevents accidental removal of the root directory
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
  local resolved destination

  destination="${1}"
  resolved=$(realpath "${destination}" 2>/dev/null) || return 1

  # Make sure the target path is an absolute path
  [[ -n "${destination}" && "${destination}" == "${resolved}" ]] || return 1

  rm -rf "${destination}" &>/dev/null || return 1
}

# -------------------------------------------------------------------
# remove_content_with_comment
#
# description:
#   calls remove_content to remove the specified file or directory at
#   the given absolute path, and prints status messages to the console
#
# arguments:
#   $1 - absolute path to the file or directory to remove
#
# usage:
#   remove_content_with_comment "/path/to/destination"
# -------------------------------------------------------------------
remove_content_with_comment() {
  echo -ne "${foreground_color_grey}removing content for ${1:-} - "
  if remove_content "${1:-}"; then
    echo -ne "${foreground_color_green}done${sgr_reset}\n"
  else
    echo -ne "${foreground_color_red}error${sgr_reset}\n"
  fi
}

# -------------------------------------------------------------------
# get_input_message
#
# description:
#   prompts the user for input with a given message and returns the
#   input
#
# arguments:
#   $1 - prompt message to display to the user
#
# returns:
#   the user input
#
# usage:
#   get_input_message "prompt information"
# -------------------------------------------------------------------
get_input_message() {
  local prompt input_message

  prompt="${1:-}"

  read -rep "${prompt}" input_message </dev/tty
  echo -ne "${input_message}"
}

# -------------------------------------------------------------------
# get_input_until_success
#
# description:
#   continuously prompts the user for input with a given message
#   until valid input is provided. optionally validates the input
#   against a regular expression and displays a custom error message
#   if validation fails
#
# arguments:
#   $1 - prompt message to display to the user
#   $2 - (optional) regular expression to validate the input
#   $3 - (optional) error message to display if validation fails
#
# returns:
#   echoes the valid user input to stdout
#
# usage:
#   get_input_until_success "enter your name: "
#   get_input_until_success "enter a number: " '^[0-9]+$' "input must be a number"
# -------------------------------------------------------------------
get_input_until_success() {
  local prompt validate error_message input_message

  prompt="${1:-}"
  validate="${2:-}"
  error_message="${3:-}"

  while read -rep "${prompt}" input_message </dev/tty; do
    if [[ -z "${input_message}" ]]; then
      echo -ne "${foreground_color_yellow}input cannot be empty, please try again${sgr_reset}\n" >&2
      continue
    elif [[ -n "${validate}" ]]; then
      if ! echo "$input_message" | grep -Eiq "$validate" &>/dev/null; then
        echo -ne "${foreground_color_yellow}${error_message}${sgr_reset}\n" >&2
        continue
      fi
    fi

    break
  done

  echo -ne "${input_message}"
}

# -------------------------------------------------------------------
# get_global_ip
#
# description:
#   retrieves the public/global ip address of the current machine by
#   querying an external api
#
# returns:
#   the global ip address to stdout
#
# usage:
#   get_global_ip
# -------------------------------------------------------------------
get_global_ip() {
  echo -ne "$(curl -fsSL https://api.ip.sb/ip -A Mozilla 2>/dev/null)"
}

# -------------------------------------------------------------------
# generate_random_uuid
#
# description:
#   generates a random uuid (universally unique identifier) using the
#   uuidgen command with the -r flag to produce a random-based uuid
#
# returns:
#   the generated uuid to stdout
#
# usage:
#   generate_random_uuid
# -------------------------------------------------------------------
generate_random_uuid() {
  echo -ne "$(uuidgen)"
}

# -------------------------------------------------------------------
# generate_random_password
#
# description:
#   generates a random password by reading 32 bytes from /dev/random,
#   removing null bytes, and then hashing the result with md5sum to
#   produce a fixed-length hexadecimal string
#
# returns:
#   the generated password (md5 hash) to stdout
#
# usage:
#   generate_random_password
# -------------------------------------------------------------------
generate_random_password() {
  local random_password

  random_password=$(dd if=/dev/random bs=32 count=1 status=none | od -An -tx1 | tr -d ' \n')
  echo -ne "${random_password}" | md5sum | awk '{print $1}'
}

# -------------------------------------------------------------------
# load_ini_config
#
# description:
#   loads the value of a given key from an ini-style configuration
#   file. ignores commented lines and trims whitespace. only supports
#   simple key=value pairs (no section support)
#
# arguments:
#   $1 - key to search
#   $2 - path to the ini configuration file
#
# returns:
#   the value of the key to stdout, or nothing if not found
#
# usage:
#   load_ini_config "key" "/path/to/config.ini"
# -------------------------------------------------------------------
load_ini_config() {
  local ini_key ini_path

  ini_key="${1:-}"
  ini_path="${2:-}"

  awk -F '=' -v search_key="${ini_key}" '
    /^[[:space:]]*#/ { next }           # Skip comments
    /^[[:space:]]*$/ { next }           # Skip empty lines
    {
      gsub(/^[ \t]+|[ \t]+$/, "", $1)   # Trim whitespace from key
      gsub(/^[ \t]+|[ \t]+$/, "", $2)   # Trim whitespace from value
      if ($1 == search_key) {
        print $2
        exit
      }
    }
  ' "${ini_path}"
}
