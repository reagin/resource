#!/usr/bin/env bash

# name: shellscript.sh
# author: reagin
# github: https://github.com/reagin/resource
# description: template file used to create shellscript

# enable the following shell options:
# -E: ensure that err trap is also valid in function, subshell, and command replacements
# -e: when any command exits in a non-zero state, exit the script immediately
# -u: when using undefined variables, the script will report an error and exit
# -x: the command and its parameters will be printed when executing the command (for debugging)
# -o: pipefail: when any command in the pipeline fails, the entire pipeline returns to a failed state
set -Eeuxo pipefail

# setting up temporary working directory when script runs
trap remove_temp_directory EXIT

remove_temp_directory() {
  if [[ -n "${TEMPDIRECTORY:-}" && -e "${TEMPDIRECTORY}" ]]; then
    [[ "$(pwd)" =~ ^"${TEMPDIRECTORY}" ]] && popd &>/dev/null
    rm -rf "${TEMPDIRECTORY}"
  fi
}

TEMPDIRECTORY=$(mktemp -dt reagin_directory_XXXXXX 2>/dev/null) || {
  echo -ne "\x1B[38;2;215;0;0mError: failed to create temporary directory\x1B[0m\n"
  exit 1
}

pushd "${TEMPDIRECTORY}" &>/dev/null || {
  echo -ne "\x1B[38;2;215;0;0mError: failed to pushd temporary directory\x1B[0m\n"
  exit 1
}

# check whether the current user's permission is root
check_permission() {
  echo -ne "\x1B[38;2;128;128;128mcurrent user is: ${USER}\x1B[0m\n"

  if [[ "${EUID}" != 0 ]]; then
    echo -ne "\x1B[38;2;215;0;0mError: please run the script with root\x1B[0m\n"
    exit 1
  fi
}

# check the environment of the current script
check_environment() {
  # shellcheck disable=SC1091
  [[ -f "/etc/os-release" ]] && source /etc/os-release

  os_name=$(echo -ne "${NAME}" | awk '{print tolower($1)}')
  os_type=$(echo -ne "$(uname -s)" | awk '{print tolower($1)}')

  case "${os_name}" in
    arch)
      os_arch=$(uname -m)
      package_suffix=".pkg.tar.zst"
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
      echo -ne "\x1B[38;2;215;0;0mError: unsupported system for ${os_name}\x1B[0m\n"
      exit 1
      ;;
  esac

  echo -ne "\x1B[38;2;128;128;128mcurrent system is: ${os_name}_${os_arch}_${os_type}\x1B[0m\n"
}

# check whether the instructions used in the current script exist
check_dependencies() {
  local command_dependency package_dependency

  command_dependency=() # CONFIG: commands appearing in script
  package_dependency=() # CONFIG: corresponding package name of the command

  if [[ ${#command_dependency[@]} == 0 ]]; then
    return 0
  fi

  echo -ne "\x1B[2mchecking command dependencies now ...\x1B[0m\n"

  for index in "${!command_dependency[@]}"; do
    echo -ne "\x1B[4C\x1B[2m${command_dependency[index]} - "

    if type -t "${command_dependency[index]}" &>/dev/null; then
      echo -ne "installed\x1B[0m\n"
    else
      echo -ne "not installed\x1B[0m\n"
      echo -ne "\x1B[8C\x1B[2m${package_manager} ${package_dependency[index]} ... "

      if sh -c "${package_manager} ${package_dependency[index]}" &>/dev/null; then
        echo -ne "done\x1B[0m\n"
      else
        echo -ne "error\x1B[0m\n"
        echo -ne "\x1B[38;2;215;0;0mError: please run the command manually\x1B[0m\n"
        exit 1
      fi
    fi
  done
}

# load external script resources
source_external_scripts() {
  local script_file external_script_links command_dependency package_dependency

  command_dependency=()
  package_dependency=()
  external_script_links=() # CONFIG: the URL address of the external script

  if [[ ${#external_script_links[@]} == 0 ]]; then
    return 0
  fi

  echo -ne "\x1B[2mloading external scripts now ...\x1B[0m\n"

  for link in "${external_script_links[@]}"; do
    echo -ne "\x1B[4C\x1B[2mloading ${link} - "

    script_file=$(mktemp -p "${TEMPDIRECTORY}" -t script_XXXXXX.sh 2>/dev/null) || {
      echo -ne "error\x1B[0m\n"
      echo -ne "\x1B[38;2;215;0;0mError: failed to create temporary file\x1B[0m\n"
      exit 1
    }

    curl -fsSL "${link}" -o "${script_file}" 2>/dev/null || {
      echo -ne "error\x1B[0m\n"
      echo -ne "\x1B[38;2;215;0;0mError: failed to download external script\x1B[0m\n"
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

    echo -ne "done\x1B[0m\n"
  done

  if [[ ${#command_dependency[@]} == 0 ]]; then
    return 0
  fi

  echo -ne "\x1B[2minstalling external command dependencies ...\x1B[0m\n"

  for index in "${!command_dependency[@]}"; do
    echo -ne "\x1B[4C\x1B[2m${command_dependency[index]} - "

    if type -t "${command_dependency[index]}" &>/dev/null; then
      echo -ne "installed\x1B[0m\n"
    else
      echo -ne "not installed\x1B[0m\n"
      echo -ne "\x1B[8C\x1B[2m${package_manager} ${package_dependency[index]} ... "

      if sh -c "${package_manager} ${package_dependency[index]}" &>/dev/null; then
        echo -ne "done\x1B[0m\n"
      else
        echo -ne "error\x1B[0m\n"
        echo -ne "\x1B[38;2;215;0;0mError: please run the command manually\x1B[0m\n"
        exit 1
      fi
    fi
  done
}

# check whether the execution user is root
# check_permission # TODO: delete comments to enable functions
# check the environment of the current script
# check_environment # TODO: delete comments to enable functions
# check whether the instructions used in the current script exist
# check_dependencies # TODO: delete comments to enable functions
# source external script resources
# source_external_scripts # TODO: delete comments to enable functions

# TODO: please write the main program of the script below
