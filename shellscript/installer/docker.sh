#!/usr/bin/env bash

# name: docker.sh
# author: reagin
# github: https://github.com/reagin/resource
# description: install docker engine for linux

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

  command_dependency=('gpg' 'curl' 'update-ca-certificates')
  package_dependency=('gpg' 'curl' 'ca-certificates')

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

# check whether the execution user is root
check_permission
# check the environment of the current script
check_environment
# check whether the instructions used in the current script exist
check_dependencies
# source external script resources
source_external_scripts

# ubuntu/debian installer
generate_debian_docker_source() {
  cat <<EOF
Types: deb
URIs: https://download.docker.com/linux/${os_name}
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: ${docker_gpg_path}
EOF
}

debian_installer_docker() {
  docker_gpg_name="docker-engine.asc"
  docker_gpg_path="/etc/apt/keyrings/docker-engine.gpg"
  docker_apt_sources="/etc/apt/sources.list.d/docker-engine.sources"

  show_info "downloading the gpg key from https://download.docker.com/linux/${os_name}/gpg\n"
  curl -fsSL https://download.docker.com/linux/${os_name}/gpg -o "${docker_gpg_name}" &>/dev/null || {
    show_error "failed to download the gpg key from https://download.docker.com/linux/${os_name}/gpg\n"
    return 1
  }
  show_success "successfully download the gpg key from https://download.docker.com/linux/${os_name}/gpg\n"

  rm -rf "${docker_gpg_path}"

  show_info "converting gpg file format by gpg --dearmor -o ${docker_gpg_path} ${docker_gpg_name}\n"
  gpg --dearmor -o "${docker_gpg_path}" "${docker_gpg_name}" &>/dev/null || {
    show_error "failed to convert gpg file format\n"
    return 1
  }
  show_success "successfully convert gpg file format\n"

  install_content_with_comment 644 "root:root" "$(generate_debian_docker_source)" "${docker_apt_sources}" true

  show_info "updating apt repository information\n"
  apt-get update &>/dev/null || {
    show_error "failed to update apt repository information\n"
    return 1
  }
  show_success "successfully update apt repository information\n"

  show_info "installing docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin\n"
  apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y &>/dev/null || {
    show_error "failed to install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin\n"
    return 1
  }
  show_success "successfully install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin\n"

  for user_dir in /home/*; do
    [[ -d "${user_dir}" ]] || {
      continue
    }

    user_name=$(basename "${user_dir}")

    show_info "adding ${user_name} to the docker group\n"
    usermod -aG docker "${user_name}" &>/dev/null || {
      show_error "failed to add ${user_name} to the docker group\n"
      return 1
    }
    show_success "successfully add ${user_name} to the docker group\n"
  done
}

# main program entry
case "${os_name}" in
  ubuntu | debian)
    debian_installer_docker
    ;;
  *)
    show_error "unsupported system for ${os_name}\n"
    ;;
esac
