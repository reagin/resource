#!/usr/bin/env bash

# template.sh
# Author: rehuony
# Description: Template file used to create shellscript
# GitHub: https://github.com/rehuony/resource

# Enable the following shell options:
# -E: Ensure that ERR trap is also valid in function, subshell, and command replacements
# -e: When any command exits in a non-zero state, exit the script immediately
# -u: When using undefined variables, the script will report an error and exit
# -x: The command and its parameters will be printed when executing the command (for debugging)
# -o pipefail: When any command in the pipeline fails, the entire pipeline returns to a failed state
set -Eeuxo pipefail

# Setting up temporary working directory when script runs
trap remove_temp_directory EXIT

remove_temp_directory() {
  if [[ -n "${TEMPDIRECTORY:-}" && -e "${TEMPDIRECTORY}" ]]; then
    # Exit temporary working directory
    [[ "$(pwd)" =~ ^"${TEMPDIRECTORY}" ]] && popd &>/dev/null
    # Delete all temporary files
    rm -rf "${TEMPDIRECTORY}"
  fi
}

TEMPDIRECTORY=$(mktemp -dt rehuony_directory_XXXXXX 2>/dev/null) || {
  printf "\e[38;2;215;0;0mError: failed to create temporary directory\e[0m\n"
  exit 1
}

pushd "${TEMPDIRECTORY}" &>/dev/null || {
  printf "\e[38;2;215;0;0mError: failed to enter temporary directory\e[0m\n"
  exit 1
}

# Check whether the execution user is root
check_root_user() {
  if [[ $(id -u) != 0 ]]; then
    printf "\e[38;2;215;0;0mError: please run the script with root permissions\e[0m\n"
    exit 1
  fi
}

# Check whether the instructions used in the current script exist
check_command_dependencies() {
  local lacking_packages=()
  # CONFIG: commands appearing in script
  local command_dependency=()
  # CONFIG: corresponding package name of the command
  local package_dependency=()

  for i in "${!command_dependency[@]}"; do
    if !(type -t "${command_dependency[i]}" &> /dev/null); then
      lacking_packages+=(${package_dependency[i]})
    fi
  done

  if ((${#lacking_packages[@]} != 0)); then
    printf "\e[38;2;215;0;0mError: command not found, please execute the following command first\n"
    printf "\e[38;2;128;128;128msudo apt update && sudo apt install -y %s\e[0m\n" "${lacking_packages[*]}"
    exit 1
  fi
}

# Load external script resources
load_external_scripts() {
  # CONFIG: the URL address of the external script
  local external_script_links=()

  for link in "${external_script_links[@]}"; do
    script_file=$(mktemp -p "${TEMPDIRECTORY}" -t script_XXXXXX.sh) || {
      printf "\e[38;2;215;0;0mError: failed to create temporary file for ${link}\e[0m\n"
      continue
    }
    curl -fsSL "${link}" -o "${script_file}" 2>/dev/null
    source "${script_file}"
  done
}

# Check whether the execution user is root
check_root_user
# Check whether the instructions used in the current script exist
check_command_dependencies
# Load external script resources
load_external_scripts

# TODO: Please write the main program of the script below
