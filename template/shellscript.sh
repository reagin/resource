#!/usr/bin/env bash

# shellscript.sh
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
    [[ "$(pwd)" =~ ^"${TEMPDIRECTORY}" ]] && popd &>/dev/null
    rm -rf "${TEMPDIRECTORY}"
  fi
}

TEMPDIRECTORY=$(mktemp -dt rehuony_directory_XXXXXX 2>/dev/null) || {
  printf "\e[38;2;215;0;0mError: failed to create temporary directory\e[0m\n"
  exit 1
}

pushd "${TEMPDIRECTORY}" &>/dev/null || {
  printf "\e[38;2;215;0;0mError: failed to pushd temporary directory\e[0m\n"
  exit 1
}

# Check whether the execution user is root
check_permission() {
  printf "\e[2mCurrent user is: ${USER}\e[0m\n"

  if [[ "${EUID}" != 0 ]]; then
    printf "\e[38;2;215;0;0mError: please run the script with root\e[0m\n"
    exit 1
  fi
}

# Check the environment of the current script
check_environment() {
  [[ -f "/etc/os-release" ]] && source /etc/os-release

  os_name=$(echo -ne "${NAME}" | awk '{print tolower($1)}')
  os_type=$(echo -ne "$(uname -s)" | awk '{print tolower($1)}')

  case "${os_name}" in
    arch)
      os_arch=$(uname -m)
      package_suffix=".zst"
      package_manager="pacman -S --noconfirm"
      package_installer="pacman -U --noconfirm"
      ;;
    openwrt)
      os_arch=$(uname -m)
      package_suffix=".ipk"
      package_manager="opkg install"
      package_installer="opkg install"
      ;;
    ubuntu | debian)
      os_arch=$(dpkg --print-architecture)
      package_suffix=".deb"
      package_manager="apt install -y"
      package_installer="dpkg -i"
      ;;
    red | centos | fedora)
      os_arch=$(uname -m)
      package_suffix=".rpm"
      package_manager="dnf install -y"
      package_installer="rpm -i"
      ;;
    *)
      printf "\e[38;2;215;0;0mError: unsupported system for ${os_name}\e[0m\n"
      exit 1
      ;;
  esac

  printf "\e[2mCurrent system is: ${os_arch}_${os_name}_${os_type}\e[0m\n"
}

# Check whether the instructions used in the current script exist
check_dependencies() {
  local command_dependency package_dependency

  command_dependency=() # CONFIG: commands appearing in script
  package_dependency=() # CONFIG: corresponding package name of the command

  if [[ ${#command_dependency[@]} == 0 ]]; then
    return 0
  fi

  printf "\e[2mChecking command dependencies now ...\e[0m\n"

  for index in "${!command_dependency[@]}"; do
    printf "\e[4C\e[2m${command_dependency[index]} - "

    if type -t "${command_dependency[index]}" &>/dev/null; then
      printf "installed\e[0m\n"
    else
      printf "not installed\e[0m\n"
      printf "\e[8C\e[2m${package_manager} ${package_dependency[index]} ... "

      if sh -c "${package_manager} ${package_dependency[index]}" &>/dev/null; then
        printf "done\e[0m\n"
      else
        printf "error\e[0m\n"
        printf "\e[38;2;215;0;0mError: please run the command manually\e[0m\n"
        exit 1
      fi
    fi
  done
}

# Load external script resources
source_external_scripts() {
  local script_file external_script_links command_dependency package_dependency

  command_dependency=()
  package_dependency=()
  external_script_links=() # CONFIG: the URL address of the external script

  if [[ ${#external_script_links[@]} == 0 ]]; then
    return 0
  fi

  printf "\e[2mLoading external scripts now ...\e[0m\n"

  for link in "${external_script_links[@]}"; do
    printf "\e[4C\e[2mloading ${link} - "

    script_file=$(mktemp -p "${TEMPDIRECTORY}" -t script_XXXXXX.sh 2>/dev/null) || {
      printf "error\e[0m\n"
      printf "\e[38;2;215;0;0mError: failed to create temporary file\e[0m\n"
      exit 1
    }

    curl -fsSL "${link}" -o "${script_file}" 2>/dev/null || {
      printf "error\e[0m\n"
      printf "\e[38;2;215;0;0mError: failed to download external script\e[0m\n"
      exit 1
    }

    source "${script_file}"

    for index in "${!lib_command_dependency[@]}"; do
      local is_exist="false"

      for cmd in "${command_dependency[@]}"; do
        if [[ "${cmd}" == "${lib_command_dependency[index]}" ]]; then
          is_exist="true"
          break
        fi
      done

      if [[ "${is_exist}" == "false" ]]; then
        command_dependency+=("${lib_command_dependency[index]}")
        package_dependency+=("${lib_package_dependency[index]}")
      fi
    done

    printf "done\e[0m\n"
  done

  if [[ ${#command_dependency[@]} == 0 ]]; then
    return 0
  fi

  printf "\e[2mInstalling external command dependencies ...\e[0m\n"

  for index in "${!command_dependency[@]}"; do
    printf "\e[4C\e[2m${command_dependency[index]} - "

    if type -t "${command_dependency[index]}" &>/dev/null; then
      printf "installed\e[0m\n"
    else
      printf "not installed\e[0m\n"
      printf "\e[8C\e[2m${package_manager} ${package_dependency[index]} ... "

      if sh -c "${package_manager} ${package_dependency[index]}" &>/dev/null; then
        printf "done\e[0m\n"
      else
        printf "error\e[0m\n"
        printf "\e[38;2;215;0;0mError: please run the command manually\e[0m\n"
        exit 1
      fi
    fi
  done
}

# Check whether the execution user is root
# check_permission # TODO: Delete comments to enable functions
# Check the environment of the current script
# check_environment # TODO: Delete comments to enable functions
# Check whether the instructions used in the current script exist
# check_dependencies # TODO: Delete comments to enable functions
# Source external script resources
# source_external_scripts # TODO: Delete comments to enable functions

# TODO: Please write the main program of the script below
