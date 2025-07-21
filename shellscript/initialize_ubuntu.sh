#!/usr/bin/env bash

# initialize_ubuntu.sh
# Author: rehuony
# Description: Script files for personalizing Ubuntu configurations
# GitHub: https://github.com/rehuony/resource

# Enable the following shell options:
# -E: Ensure that ERR trap is also valid in function, subshell, and command replacements
# -e: When any command exits in a non-zero state, exit the script immediately
# -u: When using undefined variables, the script will report an error and exit
# -o pipefail: When any command in the pipeline fails, the entire pipeline returns to a failed state
set -Eeuo pipefail

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

  command_dependency=('sed' 'curl')
  package_dependency=('sed' 'curl')

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
  local script_file lacking_packages external_script_links

  lacking_packages=()
  external_script_links=(
    'https://cdn.jsdelivr.net/gh/rehuony/resource@main/shellscript/library/message.lib.sh'
    'https://cdn.jsdelivr.net/gh/rehuony/resource@main/shellscript/library/utility.lib.sh'
  )

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
      type -t "${lib_command_dependency[index]}" &>/dev/null && continue

      local is_exist="false"

      for package in "${lacking_packages[@]}"; do
        if [[ "${package}" == "${lib_package_dependency[index]}" ]]; then
          is_exist="true"
          break
        fi
      done

      if [[ "${is_exist}" == "false" ]]; then
        lacking_packages+=("${lib_package_dependency[index]}")
      fi
    done

    printf "done\e[0m\n"
  done

  printf "\e[2mInstalling external command dependencies ...\e[0m\n"

  if [[ ${#lacking_packages[@]} != 0 ]]; then
    printf "\e[4C\e[2m${package_manager} ${lacking_packages[*]} ... "

    if sh -c "${package_manager} ${lacking_packages[*]}" &>/dev/null; then
      printf "done\e[0m\n"
    else
      printf "error\e[0m\n"
      printf "\e[38;2;215;0;0mError: please run the installation command manually\e[0m\n"
      exit 1
    fi
  fi
}

# Check whether the execution user is root
check_permission
# Check the environment of the current script
check_environment
# Check whether the instructions used in the current script exist
check_dependencies
# Source external script resources
source_external_scripts

generate_authorized_keys() {
  cat <<EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIERsE9a2KV0yOn9ZN+KSYYP0p+km1dslOaUAzAsJ6hEa rehug's universal key
EOF
}

generate_alias_config() {
  cat <<EOF
alias cls='clear'
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

for user_dir in /root /home/*; do
  [[ -d "${user_dir}" ]] || {
    continue
  }

  user_name=$(basename "${user_dir}")
  junk_files=('.bash_history' '.cloud-locale-test.skip' '.viminfo' '.wget-hsts')

  install_content 600 "${user_name}:${user_name}" "$(generate_authorized_keys)" "${user_dir}/.ssh/authorized_keys"
  install_content 644 "${user_name}:${user_name}" "$(generate_alias_config)" "${user_dir}/.bash_aliases"
  install_content 644 "${user_name}:${user_name}" "$(generate_vim_config)" "${user_dir}/.vimrc"
  install_content 644 "${user_name}:${user_name}" "" "${user_dir}/.hushlogin"

  # Modify the .bashrc file in the home directory
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

  # Clean junk files in home path
  for file in "${junk_files[@]}"; do
    remove_content "${user_dir}/${file}"
  done
done

# Modify /etc/ssh/sshd_config configuration
sed -Ei 's/^#?(port).*/\1 22/Ig' /etc/ssh/sshd_config
sed -Ei 's/^#?(permitrootlogin).*/\1 prohibit-password/Ig' /etc/ssh/sshd_config
sed -Ei 's/^#?(passwordauthentication).*/\1 no/Ig' /etc/ssh/sshd_config
sed -Ei 's/^#?(permitemptypasswords).*/\1 no/Ig' /etc/ssh/sshd_config
sed -Ei 's/^#?(clientaliveinterval).*/\1 60/Ig' /etc/ssh/sshd_config
sed -Ei 's/^#?(clientalivecountmax).*/\1 3/Ig' /etc/ssh/sshd_config

# Restart the ssh service
systemctl daemon-reload && systemctl restart ssh.socket

# Clean junk files in root path
rm -rf /*.usr-is-merged
rm -rf /lost+found
