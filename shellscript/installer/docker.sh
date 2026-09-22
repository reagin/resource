#!/usr/bin/env bash

# name: docker.sh
# author: reagin
# github: https://github.com/reagin/resource
# description: install docker engine for debian / ubuntu from the official
#              apt repository

# -E: err trap is inherited by functions, subshells and substitutions
# -e: exit immediately when a command fails
# -u: treat unset variables as an error
# -o pipefail: a pipeline fails when any of its commands fails
set -Eeuo pipefail

# base url of the shared libraries. override for local testing, e.g.
#   RESOURCE_LIB_BASE=file:///path/to/shellscript/library bash docker.sh
RESOURCE_LIB_BASE="${RESOURCE_LIB_BASE:-https://raw.githubusercontent.com/reagin/resource/refs/heads/main/shellscript/library}"

command -v curl &>/dev/null || {
  printf '\x1B[38;2;215;0;0mError: curl is required, please install it first\x1B[0m\n' >&2
  exit 1
}
bootstrap_source=$(curl -fsSL "${RESOURCE_LIB_BASE}/bootstrap.lib.sh") || {
  printf '\x1B[38;2;215;0;0mError: failed to download %s/bootstrap.lib.sh\x1B[0m\n' "${RESOURCE_LIB_BASE}" >&2
  exit 1
}
eval "${bootstrap_source}"
unset bootstrap_source

setup_temp_directory
require_root
detect_environment
load_libraries message utility
ensure_commands update-ca-certificates:ca-certificates systemctl:systemd

# -------------------------------------------------------------------
# global variables (os_family / os_arch / os_codename come from bootstrap)
# -------------------------------------------------------------------
# shellcheck disable=SC2154
readonly docker_repo_url="https://download.docker.com/linux/${os_family}"
readonly docker_keyring_dir='/etc/apt/keyrings'
readonly docker_keyring_path="${docker_keyring_dir}/docker.asc"
readonly docker_apt_sources='/etc/apt/sources.list.d/docker.sources'
readonly docker_packages=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
readonly conflicting_packages=(docker.io docker-doc docker-compose podman-docker containerd runc)

# -------------------------------------------------------------------
# steps
# -------------------------------------------------------------------
remove_conflicting_packages() {
  local package installed=()

  for package in "${conflicting_packages[@]}"; do
    package_installed "${package}" && installed+=("${package}")
  done

  [[ ${#installed[@]} -gt 0 ]] || return 0

  show_warn "removing packages that conflict with docker-ce: ${installed[*]}\n"
  env DEBIAN_FRONTEND=noninteractive apt-get remove -y "${installed[@]}" &>/dev/null || {
    show_error "failed to remove conflicting packages, please run manually: apt-get remove ${installed[*]}\n"
    return 1
  }
  show_success "removed conflicting packages\n"
}

install_docker_keyring() {
  show_info "installing docker gpg key to ${docker_keyring_path}\n"

  install -dm755 "${docker_keyring_dir}"
  curl -fsSL "${docker_repo_url}/gpg" -o "${docker_keyring_path}" || {
    show_error "failed to download ${docker_repo_url}/gpg\n"
    return 1
  }
  chmod a+r "${docker_keyring_path}"

  show_success "installed docker gpg key\n"
}

generate_docker_sources() {
  cat <<EOF
Types: deb
URIs: ${docker_repo_url}
Suites: ${os_codename}
Components: stable
Architectures: ${os_arch:?}
Signed-By: ${docker_keyring_path}
EOF
}

install_docker_sources() {
  [[ -n "${os_codename}" ]] || {
    show_error "could not determine the distribution codename from /etc/os-release\n"
    return 1
  }

  install_content_with_comment 644 "root:root" "$(generate_docker_sources)" "${docker_apt_sources}" true

  show_info "updating apt package index\n"
  env DEBIAN_FRONTEND=noninteractive apt-get update -qq &>/dev/null || {
    show_error "failed to update apt package index, check ${docker_apt_sources}\n"
    return 1
  }
  show_success "updated apt package index\n"
}

install_docker_packages() {
  show_info "installing ${docker_packages[*]}\n"
  env DEBIAN_FRONTEND=noninteractive apt-get install -y "${docker_packages[@]}" &>/dev/null || {
    show_error "failed to install docker packages, please run manually: apt-get install ${docker_packages[*]}\n"
    return 1
  }
  show_success "installed ${docker_packages[*]}\n"
}

start_docker_service() {
  show_info "enabling and starting docker.service\n"
  systemctl enable --now docker.service &>/dev/null || {
    show_error "failed to start docker.service, check: journalctl -u docker.service\n"
    return 1
  }
  show_success "docker.service is running\n"
}

verify_docker() {
  local version

  version=$(docker --version 2>/dev/null) || {
    show_error "docker command is not available after installation\n"
    return 1
  }
  show_success "${version}\n"
}

print_group_hint() {
  local example_user="${SUDO_USER:-<username>}"

  echo
  show_info "docker was installed without granting any user access to the daemon.\n"
  show_info "membership of the docker group is equivalent to root, grant it deliberately:\n"
  show_text "    usermod -aG docker ${example_user}\n"
  show_text "    newgrp docker    # or log out and back in to apply the new group\n"
}

# -------------------------------------------------------------------
# main program entry
# -------------------------------------------------------------------
remove_conflicting_packages
install_docker_keyring
install_docker_sources
install_docker_packages
start_docker_service
verify_docker
print_group_hint
