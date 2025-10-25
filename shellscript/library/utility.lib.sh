#!/usr/bin/env bash

# name: utility.lib.sh
# author: rehuony
# github: https://github.com/rehuony/resource
# description: template file used to create library shellscript

# enable the following shell options:
# -E: ensure that err trap is also valid in function, subshell, and command replacements
# -e: when any command exits in a non-zero state, exit the script immediately
# -u: when using undefined variables, the script will report an error and exit
# -o: pipefail: when any command in the pipeline fails, the entire pipeline returns to a failed state
set -Eeuo pipefail

lib_command_dependency=('grep' 'awk' 'md5sum' 'uuidgen')
lib_package_dependency=('grep' 'gawk' 'coreutils' 'uuid-runtime')

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
#   2 - target file already exists and is backed up
#
# usage:
#   install_content 644 "root:root" "content" "/path/to/destination"
# -------------------------------------------------------------------
install_content() {
  local mode owner group content destination remove_flag tempfile

  mode="${1}"
  owner="${2%%:*}"
  group="${2##*:}"
  content="${3}"
  destination="${4}"
  remove_flag="${5:-false}"

  # Exit if the key parameter is empty
  [[ -z "${mode}" || -z "${owner}" || -z "${group}" || -z "${destination}" ]] && return 1
  # Ensure file permissions are in 644 format
  [[ "${mode}" =~ ^[0-7]{3}$ ]] || return 1
  # Make sure the target path is an absolute path
  [[ "${destination:0:1}" == "/" ]] || return 1
  # Make sure the target path is not a directory file
  [[ -d "${destination}" ]] && return 1

  tempfile=$(mktemp -t tempfile_XXXXXX 2>/dev/null) || return 1

  printf '%s' "${content}" >"${tempfile}"

  install -D --mode="${mode}" --owner="${owner}" --group="${group}" --suffix=".bak" "${tempfile}" "${destination}" 2>/dev/null || {
    rm -rf "${tempfile}"
    return 1
  }

  rm -rf "${tempfile}"
  [[ "${remove_flag}" == "true" ]] && rm -rf "${destination}.bak"

  if [[ -e "${destination}.bak" ]]; then
    return 2
  fi
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
  printf "\x1B[38;2;0;135;215m[INFO]\x1B[0m \x1B[2minstalling content for ${4}\n\x1B[0m"
  if install_content "${@}"; then
    printf "\x1B[38;2;0;175;0m[SUCCESS]\x1B[0m \x1B[2minstalled content for ${4}\n\x1B[0m"
  elif [[ "$?" == 2 ]]; then
    printf "\x1B[38;2;215;215;95m[WARN]\x1B[0m \x1B[2mbackup old file to ${4}.bak\n\x1B[0m"
  else
    printf "\x1B[38;2;215;0;0m[ERROR]\x1B[0m \x1B[2mfailed to install content for ${4}\n\x1B[0m"
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
  local destination

  destination="${1}"

  # Make sure the target path is an absolute path
  [[ -n "${destination}" && "${destination:0:1}" == "/" ]] || return 1

  case "${destination}" in
    '/' | '/.' | '/..' | '/./' | '/../') return 1 ;;
  esac

  rm -rf "${destination}" 2>/dev/null || return 1
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
  printf "\x1B[38;2;0;135;215m[INFO]\x1B[0m \x1B[2mremoving content for ${1}\n\x1B[0m"
  if remove_content "$1"; then
    printf "\x1B[38;2;0;175;0m[SUCCESS]\x1B[0m \x1B[2mremoved content for ${1}\n\x1B[0m"
  else
    printf "\x1B[38;2;215;0;0m[ERROR]\x1B[0m \x1B[2mfailed to remove content for ${1}\n\x1B[0m"
  fi
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
  printf "$(curl -fsSL https://api.ip.sb/ip -A Mozilla 2>/dev/null)"
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

  read -e -p "${prompt}" input_message </dev/tty
  printf "%s" "${input_message}"
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
  local prompt validate error_msg input_message

  prompt="${1:-}"
  validate="${2:-}"
  error_msg="${3:-}"

  while read -e -p "${prompt}" input_message </dev/tty; do
    if [[ -z "${input_message}" ]]; then
      printf "\x1B[38;2;215;215;95minput cannot be empty, please try again\n\x1B[0m" >&2
      continue
    elif [[ -n "${validate}" ]]; then
      if ! echo "$input_message" | grep -Pq "$validate"; then
        printf "\x1B[38;2;215;215;95m${error_msg}\n\x1B[0m" >&2
        continue
      fi
    fi

    break
  done

  printf "%s" "${input_message}"
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
  printf "%s" "$(uuidgen -r)"
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

  random_password=$(dd if=/dev/random bs=32 count=1 status=none | tr -d '\0')
  printf "%s" "$random_password" | md5sum | awk '{print $1}'
}
