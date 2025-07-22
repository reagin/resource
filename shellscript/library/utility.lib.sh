#!/usr/bin/env bash

# utility.lib.sh
# Author: rehuony
# Description: Template file used to create library shellscript
# GitHub: https://github.com/rehuony/resource

# Enable the following shell options:
# -E: Ensure that ERR trap is also valid in function, subshell, and command replacements
# -e: When any command exits in a non-zero state, exit the script immediately
# -u: When using undefined variables, the script will report an error and exit
# -o pipefail: When any command in the pipeline fails, the entire pipeline returns to a failed state
set -Eeuo pipefail

lib_command_dependency=(awk md5sum)
lib_package_dependency=(gawk coreutils)

# -------------------------------------------------------------------
# install_content
#
# Description:
#   Installs the given content to a specified destination file with
#   defined permissions, owner, and group. Creates a temporary file
#   to hold the content before installing. If the destination
#   already exists, a backup is created with a ".bak" suffix
#
# Arguments:
#   $1 - File mode (e.g. "644")
#   $2 - Owner and group (e.g. "root" or "root:root")
#   $3 - Content to be written to the file
#   $4 - Absolute path to the destination file
#
# Returns:
#   0 - install content success
#   1 - parameter error or operation failed
#   2 - target file already exists and is backed up
#
# Usage:
#   install_content 644 "root:root" "content" "/path/to/destination"
# -------------------------------------------------------------------
install_content() {
  local mode owner group content destination tempfile

  mode="${1}"
  owner="${2%%:*}"
  group="${2##*:}"
  content="${3}"
  destination="${4}"

  # Exit if the key parameter is empty
  [[ -z "${mode}" || -z "${owner}" || -z "${group}" || -z "${destination}" ]] && return 1
  # Ensure file permissions are in 644 format
  [[ "${mode}" =~ ^[0-7]{3}$ ]] || return 1
  # Make sure the target path is an absolute path
  [[ "${destination:0:1}" == "/" ]] || return 1
  # Make sure the target path is not a directory file
  [[ -d "${destination}" ]] && return 1

  tempfile=$(mktemp -t tempfile_XXXXXX 2>/dev/null) || return 1

  printf '%s\n' "${content}" >"${tempfile}"

  install -D --mode="${mode}" --owner="${owner}" --group="${group}" --suffix=".bak" "${tempfile}" "${destination}" 2>/dev/null || {
    rm -rf "${tempfile}"
    return 1
  }

  rm -rf "${tempfile}"

  if [[ -e "${destination}.bak" ]]; then
    return 2
  fi
}

# -------------------------------------------------------------------
# install_content_with_comment
#
# Description:
#   Calls install_content to install the given content to a specified
#   destination file with defined permissions, owner, and group, and
#   prints status messages to the console. If the destination already
#   exists, a backup is created with a ".bak" suffix.
#
# Arguments:
#   $1 - File mode (e.g. "644")
#   $2 - Owner and group (e.g. "root" or "root:root")
#   $3 - Content to be written to the file
#   $4 - Absolute path to the destination file
#
# Usage:
#   install_content_with_comment 644 "root:root" "content" "/path/to/destination"
# -------------------------------------------------------------------
install_content_with_comment() {
  printf "\e[38;2;0;135;215m[INFO]\e[0m \e[2mInstalling content for ${4} ...\n\e[0m"
  if install_content "${@}"; then
    printf "\e[38;2;0;175;0m[SUCCESS]\e[0m \e[2mInstalled content for ${4}\n\e[0m"
  elif [[ "$?" == 2 ]]; then
    printf "\e[38;2;215;215;95m[WARN]\e[0m \e[2mBackup old file to ${4}.bak\n\e[0m"
  else
    printf "\e[38;2;215;0;0m[ERROR]\e[0m \e[2mFailed to install content for ${4}\n\e[0m"
  fi
}

# -------------------------------------------------------------------
# remove_content
#
# Description:
#   Removes the specified file or directory at the given absolute
#   path. If the destination does not exist, the function exits
#   successfully. Prevents accidental removal of the root directory
#
# Arguments:
#   $1 - Absolute path to the file or directory to remove
#
# Returns:
#   0 - remove content success
#   1 - parameter error or operation failed
#
# Usage:
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
# Description:
#   Calls remove_content to remove the specified file or directory at
#   the given absolute path, and prints status messages to the console.
#
# Arguments:
#   $1 - Absolute path to the file or directory to remove
#
# Usage:
#   remove_content_with_comment "/path/to/destination"
# -------------------------------------------------------------------
remove_content_with_comment() {
  printf "\e[38;2;0;135;215m[INFO]\e[0m \e[2mRemoving content for ${1} ...\n\e[0m"
  if remove_content "$1"; then
    printf "\e[38;2;0;175;0m[SUCCESS]\e[0m \e[2mRemoved content for ${1}\n\e[0m"
  else
    printf "\e[38;2;215;0;0m[ERROR]\e[0m \e[2mFailed to remove content for ${1}\n\e[0m"
  fi
}

# -------------------------------------------------------------------
# generate_random_password
#
# Description:
#   Generates a random password by reading 32 bytes from /dev/random,
#   removing null bytes, and then hashing the result with md5sum to
#   produce a fixed-length hexadecimal string
#
# Returns:
#   The generated password (MD5 hash) to stdout
#
# Usage:
#   generate_random_password
# -------------------------------------------------------------------
generate_random_password() {
  local random_password

  random_password=$(dd if=/dev/random bs=32 count=1 status=none | tr -d '\0')
  echo -n "$random_password" | md5sum | awk '{print $1}'
}
