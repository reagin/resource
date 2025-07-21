#!/usr/bin/env bash

# shellscript.lib.sh
# Author: rehuony
# Description: Template file used to create library shellscript
# GitHub: https://github.com/rehuony/resource

# Enable the following shell options:
# -E: Ensure that ERR trap is also valid in function, subshell, and command replacements
# -e: When any command exits in a non-zero state, exit the script immediately
# -u: When using undefined variables, the script will report an error and exit
# -o pipefail: When any command in the pipeline fails, the entire pipeline returns to a failed state
set -Eeuo pipefail

lib_command_dependency=(md5sum awk)
lib_package_dependency=(coreutils gawk)

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
#   $1 - File mode/permissions (e.g., "644")
#   $2 - Owner and group in "owner" or "owner:group" format (e.g.,
#       "root" or "root:root")
#   $3 - Content to be written to the file
#   $4 - Absolute path to the destination file
#
# Returns:
#   0 on success
#   1 on error
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

  if [[ -z "${mode}" || "${#mode}" != 3 ]]; then
    printf "\e[38;2;215;0;0mError: pass permission parameters in 644 format\e[0m\n"
    return 1
  elif [[ -z "${owner}" || -z "${group}" ]]; then
    printf "\e[38;2;215;0;0mError: pass parameter in owner:group format\e[0m\n"
    return 1
  elif [[ -z "${destination}" || "${destination:0:1}" != "/" ]]; then
    printf "\e[38;2;215;0;0mError: destination must be passed as an absolute path\e[0m\n"
    return 1
  fi

  printf "\e[2mInstalling content for ${destination} - "

  if [[ -e "${destination}" ]]; then
    printf "\e[38;2;215;215;95m"
  fi

  if ! tempfile=$(mktemp -p "${TEMPDIRECTORY}" -t tempfile_XXXXXX 2>/dev/null); then
    printf "\e[38;2;215;0;0mfailed to create temporary file\e[0m\n"
    return 1
  fi

  printf '%s\n' "${content}" >"${tempfile}"

  if install -D --mode="${mode}" --owner="${owner}" --group="${group}" --suffix=".bak" "${tempfile}" "${destination}" 2>/dev/null; then
    printf "done\e[0m\n"
  else
    printf "\e[38;2;215;0;0m"
    printf "error\e[0m\n"
  fi

  rm -rf "${tempfile}"
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
#   0 on success
#   1 on error
#
# Usage:
#   remove_content "/path/to/destination"
# -------------------------------------------------------------------
remove_content() {
  local destination

  destination="${1}"

  if [[ -z "${destination}" || "${destination:0:1}" != "/" ]]; then
    printf "\e[38;2;215;0;0mError: destination must be passed as an absolute path\e[0m\n"
    return 1
  fi

  printf "\e[2mRemoving content for ${destination} - "

  if ! [[ -e "${destination}" ]]; then
    printf "\e[38;2;215;215;95mnot exist\e[0m\n"
    return 0
  fi

  if [[ "$destination" == '/' ]]; then
    printf "\e[38;2;215;0;0mfailed to remove /\e[0m\n"
    return 1
  fi

  rm -rf "${destination}"
  printf "done\e[0m\n"
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
