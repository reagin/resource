#!/usr/bin/env bash

# name: sing-box.sh
# author: reagin
# github: https://github.com/reagin/resource
# description: scripts for installing sing-box server agents

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

  command_dependency=('curl' 'openssl' 'sed' 'grep' 'awk' 'mktemp' 'systemctl' 'adduser')
  package_dependency=('curl' 'openssl' 'sed' 'grep' 'gawk' 'coreutils' 'systemd' 'passwd')

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

# Load external script resources
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

# define global variables
declare user_name
declare user_email
declare user_domain
declare user_password
declare global_config_path='/etc/letsencrypt/cloudfalre.ini'

declare certificate_path
declare certificate_key_path

# loading the configuration file
generate_global_config() {
  cat <<EOF
user_name=${user_name}
user_email=${user_email}
user_domain=${user_domain}
user_password=${user_password}
EOF
}

load_global_config() {
  if [[ -f "${global_config_path}" ]]; then
    show_info "loading data from configuration: ${global_config_path}\n"

    user_name=$(load_ini_config 'user_name' "${global_config_path}")
    user_email=$(load_ini_config 'user_email' "${global_config_path}")
    user_domain=$(load_ini_config 'user_domain' "${global_config_path}")
    user_password=$(load_ini_config 'user_password' "${global_config_path}")

    if [[ -z "${user_name}" || -z "${user_email}" || -z "${user_domain}" || -z "${user_password}" ]]; then
      show_error "there is an error in the configuration file, please repair the configuration file: ${global_config_path}\n"
      return 1
    fi
  else
    show_info "please input your personal information as prompted\n"

    user_name=$(get_input_until_success "please input your name: ")
    user_email=$(get_input_until_success "please input your email: ")
    user_domain=$(get_input_until_success "please input your domain: ")
    user_password=$(get_input_until_success "please input your password: ")

    install_content_with_comment 600 "root:root" "$(generate_global_config)" "${global_config_path}" true
  fi

  certificate_path="/etc/letsencrypt/live/${user_domain}/fullchain.pem"
  certificate_key_path="/etc/letsencrypt/live/${user_domain}/privkey.pem"
}

# install sing-box and set up agent services
genetate_sing_box_config() {
  cat <<EOF
{
  "log": {
    "level": "warn",
    "output": "sing-box.log",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "trojan",
      "listen": "::",
      "listen_port": 10080,
      "users": [
        {
          "name": "${user_name}",
          "password": "${user_password}"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${user_domain}",
        "alpn": ["h3", "h2", "http/1.1"],
        "certificate_path": "${certificate_path}",
        "key_path": "${certificate_key_path}"
      },
      "multiplex": {
        "enabled": true
      }
    },
    {
      "type": "hysteria2",
      "listen": "::",
      "listen_port": 10053,
      "users": [
        {
          "name": "${user_name}",
          "password": "${user_password}"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${user_domain}",
        "alpn": ["h3", "h2", "http/1.1"],
        "certificate_path": "${certificate_path}",
        "key_path": "${certificate_key_path}"
      }
    }
  ]
}
EOF
}

install_sing_box_binary() {
  local latest_release latest_version package_name download_url

  show_info "checking the status of sing-box ... "
  type -t sing-box &>/dev/null && {
    show_text "installed\n"
    return 0
  }
  show_text "not installed\n"

  show_info "fetching the latest sing-box repository information\n"
  if ! latest_release=$(curl -fsSL https://api.github.com/repos/SagerNet/sing-box/releases/latest 2>/dev/null); then
    show_error "failed to fetch sing-box repository information\n"
    return 1
  fi
  show_success "successfully fetched sing-box repository information\n"

  show_info "parsing the latest sing-box version information\n"
  if [[ "$(echo "${latest_release}" | grep tag_name | wc -l)" == 0 ]]; then
    show_error "fetched sing-box repository information is invalid\n"
    return 1
  fi
  latest_version=$(echo "$latest_release" | grep tag_name | head -n 1 | awk -F: '{print $2}' | sed 's/[", v]//g')
  show_success "parsed latest sing-box version: ${latest_version}\n"

  show_info "constructing the url of the sing-box package installer\n"
  package_name="sing-box_${latest_version}_${os_type}_${os_arch}${package_suffix}"
  download_url="https://github.com/SagerNet/sing-box/releases/download/v${latest_version}/${package_name}"
  show_success "target download URL: ${download_url}\n"

  show_info "downloading the latest sing-box package installer\n"
  curl -fsSL "${download_url}" -o "${package_name}" 2>/dev/null || {
    show_error "failed to download sing-box package installer\n"
    return 1
  }
  show_success "successfully saved package to ${TEMPDIRECTORY}/${package_name}\n"

  show_info "executing command: ${package_installer} ${package_name}\n"
  sh -c "${package_installer} ${package_name}" &>/dev/null || {
    show_error "failed to install sing-box\n"
    return 1
  }
  show_success "successfully installed sing-box\n"

  show_info "adding system services for sing-box and start services\n"
  systemctl enable sing-box &>/dev/null && systemctl start sing-box &>/dev/null || {
    show_error "failed to add system services for sing-box\n"
    return 1
  }
  show_success "successfully added system services for sing-box\n"
}

modify_sing_box_default() {
  install_content_with_comment 644 "root:root" "$(genetate_sing_box_config)" "/etc/sing-box/config.json" true
  # restart sing-box system service
  show_info "restarting sing-box system service\n"
  systemctl start sing-box &>/dev/null || {
    show_error "failed to restart system services for sing-box\n"
    return 1
  }
  show_success "successfully restarted system services for sing-box\n"
}

debian_installer_sing_box() {
  load_global_config      # loading the configuration file
  install_sing_box_binary # install sing-box binary
  modify_sing_box_default # modify the default configuration file of sing-box
}

# main program entry
case "${os_name}" in
  ubuntu | debian)
    debian_installer_sing_box
    ;;
  *)
    show_error "unsupported system for ${os_name}\n"
    ;;
esac
