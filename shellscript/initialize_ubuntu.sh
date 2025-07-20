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
check_is_root() {
  if [[ $(id -u) != 0 ]]; then
    printf "\e[38;2;215;0;0mError: please run the script with root permissions\e[0m\n"
    exit 1
  fi
}

# Check whether the instructions used in the current script exist
check_command_dependencies() {
  local lacking_packages command_dependency package_dependency

  lacking_packages=()
  command_dependency=('sed' 'curl')
  package_dependency=('sed' 'curl')

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
  local script_file external_script_links

  external_script_links=(
    'https://cdn.jsdelivr.net/gh/rehuony/resource@main/shellscript/lib_message.sh'
  )

  for link in "${external_script_links[@]}"; do
    script_file=$(mktemp -p "${TEMPDIRECTORY}" -t script_XXXXXX.sh 2>/dev/null) || {
      printf "\e[38;2;215;0;0mError: failed to create temporary file for %s\e[0m\n" "${link}"
      exit 1
    }
    if curl -fsSL "${link}" -o "${script_file}" 2>/dev/null; then
      source "${script_file}"
    else
      printf "\e[38;2;215;0;0mError: failed to download external script: %s\e[0m\n" "${link}"
      exit 1
    fi
  done
}

# Check whether the execution user is root
check_is_root
# Check whether the instructions used in the current script exist
check_command_dependencies
# Load external script resources
load_external_scripts

install_content() {
  local mode owner group content destination tempfile

  mode="${1}"
  owner="${2%%:*}"
  group="${2##*:}"
  content="${3}"
  destination="${4}"

  if [[ -z "${mode}" || "${#mode}" != 3 ]]; then
    show_text "${foreground_color_red}Error: pass permission parameters in 644 format${sgr_reset}\n"
    return 1
  elif [[ -z "${owner}" || -z "${group}" ]]; then
    show_text "${foreground_color_red}Error: pass parameter in owner:group format${sgr_reset}\n"
    return 1
  elif [[ -z "${destination}" || "${destination:0:1}" != "/" ]]; then
    show_text "${foreground_color_red}Error: destination must be passed as an absolute path${sgr_reset}\n"
    return 1
  fi

  show_text "${sgr_faint}install content for ${destination} - "

  if [[ -e "${destination}" ]]; then
    show_text "${foreground_color_yellow}"
  fi

  if ! tempfile=$(mktemp -p "${TEMPDIRECTORY}" -t tempfile_XXXXXX 2>/dev/null); then
    show_text "${foreground_color_red}failed to create temporary file${sgr_reset}\n"
    return 1
  fi

  printf '%s\n' "${content}" >"${tempfile}"

  if install -D --mode="${mode}" --owner="${owner}" --group="${group}" --suffix=".bak" "${tempfile}" "${destination}" 2>/dev/null; then
    show_text "done${sgr_reset}\n"
  else
    show_text "${foreground_color_red}"
    show_text "error${sgr_reset}\n"
  fi
}

remove_content() {
  local destination

  destination="${1}"

  if [[ -z "${destination}" || "${destination:0:1}" != "/" ]]; then
    show_text "${foreground_color_red}Error: destination must be passed as an absolute path${sgr_reset}\n"
    return 1
  fi

  show_text "${sgr_faint}remove content for ${destination} - "

  if ! [[ -e "${destination}" ]]; then
    show_text "${foreground_color_yellow}not exist${sgr_reset}\n"
    return 0
  fi

  if [[ "$destination" == '/' ]]; then
    show_text "${foreground_color_red}failed to remove /${sgr_reset}\n"
    return 1
  fi

  rm -rf "${destination}"
  show_text "done${sgr_reset}\n"
}

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
