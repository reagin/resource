#!/usr/bin/env bash

# name: initialize.sh
# author: reagin
# github: https://github.com/reagin/resource
# description: script file for personalizing ubuntu configurations

# enable the following shell options:
# -E: ensure that err trap is also valid in function, subshell, and command replacements
# -e: when any command exits in a non-zero state, exit the script immediately
# -u: when using undefined variables, the script will report an error and exit
# -o: pipefail: when any command in the pipeline fails, the entire pipeline returns to a failed state
set -Eeuo pipefail

# setting up temporary working directory when script runs
trap remove_temp_directory EXIT

remove_temp_directory() {
  if [[ -n "${TEMPDIRECTORY:-}" && -e "${TEMPDIRECTORY}" ]]; then
    [[ "$(pwd)" =~ ^"${TEMPDIRECTORY}" ]] && popd &>/dev/null
    rm -rf "${TEMPDIRECTORY}"
  fi
}

TEMPDIRECTORY=$(mktemp -dt reagin_directory_XXXXXX 2>/dev/null) || {
  printf "\x1B[38;2;215;0;0mError: failed to create temporary directory\x1B[0m\n"
  exit 1
}

pushd "${TEMPDIRECTORY}" &>/dev/null || {
  printf "\x1B[38;2;215;0;0mError: failed to pushd temporary directory\x1B[0m\n"
  exit 1
}

# check whether the execution user is root
check_permission() {
  printf "\x1B[2mcurrent user is: ${USER}\x1B[0m\n"

  if [[ "${EUID}" != 0 ]]; then
    printf "\x1B[38;2;215;0;0mError: please run the script with root\x1B[0m\n"
    exit 1
  fi
}

# check the environment of the current script
check_environment() {
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
      printf "\x1B[38;2;215;0;0mError: unsupported system for ${os_name}\x1B[0m\n"
      exit 1
      ;;
  esac

  printf "\x1B[2mcurrent system is: ${os_arch}_${os_name}_${os_type}\x1B[0m\n"
}

# check whether the instructions used in the current script exist
check_dependencies() {
  local command_dependency package_dependency

  command_dependency=('sed' 'curl')
  package_dependency=('sed' 'curl')

  if [[ ${#command_dependency[@]} == 0 ]]; then
    return 0
  fi

  printf "\x1B[2mchecking command dependencies now ...\x1B[0m\n"

  for index in "${!command_dependency[@]}"; do
    printf "\x1B[4C\x1B[2m${command_dependency[index]} - "

    if type -t "${command_dependency[index]}" &>/dev/null; then
      printf "installed\x1B[0m\n"
    else
      printf "not installed\x1B[0m\n"
      printf "\x1B[8C\x1B[2m${package_manager} ${package_dependency[index]} ... "

      if sh -c "${package_manager} ${package_dependency[index]}" &>/dev/null; then
        printf "done\x1B[0m\n"
      else
        printf "error\x1B[0m\n"
        printf "\x1B[38;2;215;0;0mError: please run the command manually\x1B[0m\n"
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
  external_script_links=(
    'https://raw.githubusercontent.com/reagin/resource/refs/heads/main/shellscript/library/utility.lib.sh'
  )

  if [[ ${#external_script_links[@]} == 0 ]]; then
    return 0
  fi

  printf "\x1B[2mloading external scripts now ...\x1B[0m\n"

  for link in "${external_script_links[@]}"; do
    printf "\x1B[4C\x1B[2mloading ${link} - "

    script_file=$(mktemp -p "${TEMPDIRECTORY}" -t script_XXXXXX.sh 2>/dev/null) || {
      printf "error\x1B[0m\n"
      printf "\x1B[38;2;215;0;0mError: failed to create temporary file\x1B[0m\n"
      exit 1
    }

    curl -fsSL "${link}" -o "${script_file}" 2>/dev/null || {
      printf "error\x1B[0m\n"
      printf "\x1B[38;2;215;0;0mError: failed to download external script\x1B[0m\n"
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

    printf "done\x1B[0m\n"
  done

  if [[ ${#command_dependency[@]} == 0 ]]; then
    return 0
  fi

  printf "\x1B[2minstalling external command dependencies ...\x1B[0m\n"

  for index in "${!command_dependency[@]}"; do
    printf "\x1B[4C\x1B[2m${command_dependency[index]} - "

    if type -t "${command_dependency[index]}" &>/dev/null; then
      printf "installed\x1B[0m\n"
    else
      printf "not installed\x1B[0m\n"
      printf "\x1B[8C\x1B[2m${package_manager} ${package_dependency[index]} ... "

      if sh -c "${package_manager} ${package_dependency[index]}" &>/dev/null; then
        printf "done\x1B[0m\n"
      else
        printf "error\x1B[0m\n"
        printf "\x1B[38;2;215;0;0mError: please run the command manually\x1B[0m\n"
        exit 1
      fi
    fi
  done
}

# check whether the execution user is root
check_permission
# check the environment of the current script
check_environment
# check whether the instructions used in the current script exist
check_dependencies
# source external script resources
source_external_scripts

generate_authorized_keys() {
  cat <<EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAaMdAO2khj6esWPJk9CI9s/xBE82SmwbgHgfHgEiPUX reagin's personal key for universal usage
EOF
}

generate_alias_config() {
  cat <<EOF
alias cls='clear'
alias quit='rm -f ~/.bash_history && history -c && exit'
EOF
}

generate_vim_config() {
  cat <<EOF
syntax on
set number
set nobackup
set noswapfile
set nocompatible
set expandtab
set tabstop=4
set softtabstop=4
set shiftwidth=4
set smarttab
set autoindent
set smartindent
set encoding=utf-8
EOF
}

debian_custom_initialize() {
  for user_dir in /root /home/*; do
    [[ -d "${user_dir}" ]] || {
      continue
    }

    user_name=$(basename "${user_dir}")
    junk_files=('.bash_history' '.cloud-locale-test.skip' '.viminfo' '.wget-hsts')

    install_content_with_comment 600 "${user_name}:${user_name}" "$(generate_authorized_keys)" "${user_dir}/.ssh/authorized_keys" true
    install_content_with_comment 644 "${user_name}:${user_name}" "$(generate_alias_config)" "${user_dir}/.bash_aliases" true
    install_content_with_comment 644 "${user_name}:${user_name}" "$(generate_vim_config)" "${user_dir}/.vimrc" true
    install_content_with_comment 644 "${user_name}:${user_name}" "" "${user_dir}/.hushlogin" true

    # modify the .bashrc file in the home directory
    sed -Ei 's/^#?(force_color_prompt).*/\1=yes/Ig' "${user_dir}/.bashrc"
    sed -Ei '/^# some more ls aliases/{n;N;N;d;}' "${user_dir}/.bashrc"
    sed -Ei "/^# some more ls aliases/a\alias l='ls -CF'" "${user_dir}/.bashrc"
    sed -Ei "/^# some more ls aliases/a\alias la='ls -AF'" "${user_dir}/.bashrc"
    sed -Ei "/^# some more ls aliases/a\alias ll='ls -lAF'" "${user_dir}/.bashrc"

    if [[ "${user_name}" == "root" ]]; then
      sed -Ei '/\$color_prompt/I{N;s/(ps1)=(.).*\2/\1=\2${debian_chroot:+($debian_chroot)}\\[\\033[01;31m\\]\\u@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w \\$\\[\\033[00m\\] \2/Ig;}' "${user_dir}/.bashrc"
    else
      sed -Ei '/\$color_prompt/I{N;s/(ps1)=(.).*\2/\1=\2${debian_chroot:+($debian_chroot)}\\[\\033[01;32m\\]\\u@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w \\$\\[\\033[00m\\] \2/Ig;}' "${user_dir}/.bashrc"
    fi

    # clean junk files in home path
    for file in "${junk_files[@]}"; do
      remove_content_with_comment "${user_dir}/${file}"
    done
  done

  # modify /etc/ssh/sshd_config configuration
  sed -Ei 's/^#?(port).*/\1 22/Ig' /etc/ssh/sshd_config
  sed -Ei 's/^#?(permitrootlogin).*/\1 prohibit-password/Ig' /etc/ssh/sshd_config
  sed -Ei 's/^#?(passwordauthentication).*/\1 no/Ig' /etc/ssh/sshd_config
  sed -Ei 's/^#?(permitemptypasswords).*/\1 no/Ig' /etc/ssh/sshd_config
  sed -Ei 's/^#?(clientaliveinterval).*/\1 60/Ig' /etc/ssh/sshd_config
  sed -Ei 's/^#?(clientalivecountmax).*/\1 3/Ig' /etc/ssh/sshd_config

  # restart the ssh service
  systemctl daemon-reload && systemctl restart sshd.service

  # clean junk files in root path
  rm -rf /*.usr-is-merged
  rm -rf /lost+found
}

# main program entry
case "${os_name}" in
  ubuntu | debian)
    debian_custom_initialize
    ;;
  *)
    show_error "unsupported system for ${os_name}\n"
    ;;
esac
