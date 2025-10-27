#!/usr/bin/env bash

# name: oh-my-zsh.sh
# author: reagin
# github: https://github.com/reagin/resource
# description: customize the terminal using oh-my-zsh

# enable the following shell options:
# -E: ensure that err trap is also valid in function, subshell, and command replacements
# -e: when any command exits in a non-zero state, exit the script immediately
# -u: when using undefined variables, the script will report an error and exit
# -o pipefail: when any command in the pipeline fails, the entire pipeline returns to a failed state
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

  command_dependency=(awk curl mktemp runuser)
  package_dependency=(gawk curl coreutils util-linux)

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
    'https://raw.githubusercontent.com/reagin/resource/refs/heads/main/shellscript/library/message.lib.sh'
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

# check the environment of the current script
check_environment
# check whether the instructions used in the current script exist
check_dependencies
# source external script resources
source_external_scripts

backup_bash_config() {
  local backup patterns file

  # create a timestamped backup directory in the user's home
  backup="${HOME}/.bash_backup_$(date +%Y%m%d%H%M%S)"
  # patterns to clean (will match exact name and variants like .bash_completion*)
  patterns=(".bashrc" ".bash_profile" ".bash_login" ".profile" ".bash_logout" ".bash_history" ".bash_aliases" ".bash_functions" ".bash_completion" ".bash_completion.d" ".bashrc.d")

  show_info "backing bash-related files for ${USER}\n"
  mkdir -p -- "${backup}" || {
    show_error "failed to create backup directory: ${backup}\n"
    return 1
  }

  # enable globbing for hidden files and nullglob so non-matching globs disappear
  shopt -s nullglob dotglob 2>/dev/null || true

  for pattern in "${patterns[@]}"; do
    for file in "${HOME}/${pattern}"*; do
      [[ -e "${file}" ]] || continue
      show_info "backing up ${file} - "
      if mv -- "${file}" "${backup}/" &>/dev/null; then
        show_text "done\n"
      else
        show_text "error\n"
      fi
    done
  done

  # restore shell options to previous state
  shopt -u nullglob dotglob 2>/dev/null || true

  show_success "bash-related files backed up to: ${backup}\n"
}

generate_zsh_env() {
  cat <<'EOF'
# ~/.zshenv - user environment settings

# Disable system-wide compinit to avoid duplicate runs
skip_global_compinit=1

# Example: set ZDOTDIR if you keep configs elsewhere
# export ZDOTDIR="$HOME/.config/zsh"
EOF
}

install_zsh_shell() {
  local zsh_path

  show_info "checking the status of zsh - "
  zsh_path="$(command -v zsh || true)"
  if [[ -n "${zsh_path}" ]]; then
    show_text "installed\n"
  else
    show_text "not installed\n"
    show_info "executing command ${package_manager} zsh\n"
    if sh -c "${package_manager} zsh" &>/dev/null; then
      show_success "successfully installed zsh\n"
    else
      show_error "please run command manually: ${package_manager} zsh\n"
      return 1
    fi
  fi

  show_info "changing default shell for ${USER} to ${zsh_path} (maybe need password)\n"
  if chsh -s "${zsh_path}"; then
    show_success "default shell changed to zsh for ${USER}\n"
  else
    show_error "failed to change default shell automatically\n"
    return 1
  fi

  install_content_with_comment 644 "${USER}:${USER}" "$(generate_zsh_env)" "${HOME}/.zshenv" true
}

install_ohmyzsh_plugin() {
  local installer_url installer_file

  installer_url="https://raw.githubusercontent.com/reagin/ohmyzsh/custom/tools/install.sh"

  installer_file=$(mktemp -p "${TEMPDIRECTORY}" -t ohmyzsh_installer_XXXX.sh 2>/dev/null) || {
    show_error "failed to create temporary installer file\n"
    return 1
  }

  show_info "downloading oh-my-zsh installer - "
  if curl -fsSL "${installer_url}" -o "${installer_file}"; then
    show_text "done\n"
  else
    show_text "error\n"
    return 1
  fi

  show_info "running oh-my-zsh installer for ${USER} (REPO=${REPO:-reagin/ohmyzsh} BRANCH=${BRANCH:-custom})\n\n"

  env REPO="${REPO:-reagin/ohmyzsh}" BRANCH="${BRANCH:-custom}" RUNZSH=no CHSH=no sh "${installer_file}"
}

debian_installer_ohmyzsh() {
  backup_bash_config
  install_zsh_shell
  install_ohmyzsh_plugin
}

# Main program entry
case "${os_name}" in
  ubuntu | debian)
    debian_installer_ohmyzsh
    ;;
  *)
    show_error "unsupported system for ${os_name}\n"
    ;;
esac
