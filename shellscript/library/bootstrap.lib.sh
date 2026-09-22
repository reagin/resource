#!/usr/bin/env bash

# name: bootstrap.lib.sh
# author: reagin
# github: https://github.com/reagin/resource
# description: shared bootstrap for entry scripts: temporary directory,
#              environment detection, dependency installation and library
#              loading. entry scripts download this file and eval it.
#
# globals provided after detect_environment:
#   TEMPDIRECTORY  - temporary working directory, removed on exit
#   os_id          - value of ID in /etc/os-release (e.g. "debian", "ubuntu")
#   os_family      - "debian" or "ubuntu", derived from ID / ID_LIKE
#   os_codename    - UBUNTU_CODENAME or VERSION_CODENAME
#   os_arch        - dpkg architecture (e.g. "amd64", "arm64")
#
# required by the entry script before loading this file:
#   RESOURCE_LIB_BASE - base url of the library directory (http(s):// or file://)

# -------------------------------------------------------------------
# internal helpers (message.lib.sh is not loaded yet at this stage)
# -------------------------------------------------------------------
bootstrap_text() {
  printf '\x1B[2m%b\x1B[0m' "${*}"
}

bootstrap_error() {
  printf '\x1B[38;2;215;0;0mError: %b\x1B[0m\n' "${*}" >&2
}

bootstrap_die() {
  bootstrap_error "${@}"
  exit 1
}

# -------------------------------------------------------------------
# setup_temp_directory
#
# description:
#   creates a temporary working directory, enters it and registers an
#   exit trap that removes it
# -------------------------------------------------------------------
remove_temp_directory() {
  if [[ -n "${TEMPDIRECTORY:-}" && -e "${TEMPDIRECTORY}" ]]; then
    [[ "$(pwd)" == "${TEMPDIRECTORY}"* ]] && { popd &>/dev/null || true; }
    rm -rf "${TEMPDIRECTORY}"
  fi
}

setup_temp_directory() {
  [[ -n "${TEMPDIRECTORY:-}" ]] && return 0

  trap remove_temp_directory EXIT

  TEMPDIRECTORY=$(mktemp -d -t reagin_directory_XXXXXX 2>/dev/null) ||
    bootstrap_die "failed to create temporary directory"
  pushd "${TEMPDIRECTORY}" &>/dev/null ||
    bootstrap_die "failed to enter temporary directory ${TEMPDIRECTORY}"
}

# -------------------------------------------------------------------
# require_root
#
# description:
#   exits when the effective user is not root
# -------------------------------------------------------------------
require_root() {
  if [[ "${EUID}" != 0 ]]; then
    bootstrap_die "please run the script with root (current user: ${USER:-$(id -un)})"
  fi
}

# -------------------------------------------------------------------
# run_privileged
#
# description:
#   runs the given command as root, prefixing sudo when necessary
#
# usage:
#   run_privileged apt-get install -y zsh
# -------------------------------------------------------------------
run_privileged() {
  if [[ "${EUID}" == 0 ]]; then
    "${@}"
  else
    command -v sudo &>/dev/null || bootstrap_die "sudo is required to run: ${*}"
    sudo "${@}"
  fi
}

# -------------------------------------------------------------------
# detect_environment
#
# description:
#   reads /etc/os-release and only accepts debian / ubuntu and their
#   derivatives. sets os_id, os_family, os_codename and os_arch
# -------------------------------------------------------------------
detect_environment() {
  local os_like

  [[ -r /etc/os-release ]] || bootstrap_die "/etc/os-release not found, unsupported system"

  # shellcheck disable=SC1091
  source /etc/os-release

  os_id="${ID:-unknown}"
  os_like="${ID_LIKE:-}"
  os_codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

  case " ${os_id} ${os_like} " in
    *" ubuntu "*) os_family="ubuntu" ;;
    *" debian "*) os_family="debian" ;;
    *) bootstrap_die "unsupported system: ${os_id} (only debian / ubuntu are supported)" ;;
  esac

  command -v dpkg &>/dev/null || bootstrap_die "dpkg not found, unsupported system"
  os_arch=$(dpkg --print-architecture)

  bootstrap_text "current user is: ${USER:-$(id -un)}\n"
  bootstrap_text "current system is: ${os_id} ${os_codename} (${os_family} family, ${os_arch})\n"
}

# -------------------------------------------------------------------
# apt_update_once
#
# description:
#   refreshes the apt index the first time it is called
# -------------------------------------------------------------------
apt_update_once() {
  [[ -n "${BOOTSTRAP_APT_UPDATED:-}" ]] && return 0

  bootstrap_text "updating apt package index ...\n"
  run_privileged env DEBIAN_FRONTEND=noninteractive apt-get update -qq &>/dev/null ||
    bootstrap_die "failed to run: apt-get update"

  BOOTSTRAP_APT_UPDATED=1
}

# -------------------------------------------------------------------
# package_installed
#
# description:
#   returns 0 when the given apt package is installed
#
# usage:
#   package_installed nginx && echo "yes"
# -------------------------------------------------------------------
package_installed() {
  [[ "$(dpkg-query -W -f='${Status}' "${1}" 2>/dev/null)" == "install ok installed" ]]
}

# -------------------------------------------------------------------
# install_packages
#
# description:
#   installs the given apt packages non-interactively
#
# usage:
#   install_packages nginx certbot
# -------------------------------------------------------------------
install_packages() {
  [[ ${#} -gt 0 ]] || return 0

  apt_update_once
  bootstrap_text "installing packages: ${*} ...\n"
  run_privileged env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${@}" &>/dev/null ||
    bootstrap_die "failed to install packages, please run manually: apt-get install -y ${*}"
}

# -------------------------------------------------------------------
# ensure_commands
#
# description:
#   checks that the given commands exist and installs the missing
#   packages. each argument is "command:package"; when ":package" is
#   omitted the package name is assumed to equal the command name
#
# usage:
#   ensure_commands curl openssl:openssl awk:gawk
# -------------------------------------------------------------------
ensure_commands() {
  local pair cmd pkg missing=()

  [[ ${#} -gt 0 ]] || return 0

  bootstrap_text "checking command dependencies ...\n"

  for pair in "${@}"; do
    cmd="${pair%%:*}"
    pkg="${pair#*:}"
    [[ "${pair}" == *:* ]] || pkg="${cmd}"

    if command -v "${cmd}" &>/dev/null; then
      bootstrap_text "    ${cmd} - installed\n"
    else
      bootstrap_text "    ${cmd} - not installed (package: ${pkg})\n"
      missing+=("${pkg}")
    fi
  done

  [[ ${#missing[@]} -gt 0 ]] || return 0

  install_packages "${missing[@]}"

  for pair in "${@}"; do
    cmd="${pair%%:*}"
    command -v "${cmd}" &>/dev/null || bootstrap_die "command ${cmd} still missing after installation"
  done
}

# -------------------------------------------------------------------
# load_libraries
#
# description:
#   downloads and sources library files from RESOURCE_LIB_BASE. each
#   library may declare lib_dependencies=('command:package' ...) which
#   is fed into ensure_commands after sourcing
#
# usage:
#   load_libraries message utility
# -------------------------------------------------------------------
load_libraries() {
  local name file

  [[ -n "${TEMPDIRECTORY:-}" ]] || setup_temp_directory
  [[ -n "${RESOURCE_LIB_BASE:-}" ]] || bootstrap_die "RESOURCE_LIB_BASE is not set"

  for name in "${@}"; do
    bootstrap_text "loading library ${name}.lib.sh - "

    file=$(mktemp -p "${TEMPDIRECTORY}" "${name}_XXXXXX.sh" 2>/dev/null) || {
      bootstrap_text "error\n"
      bootstrap_die "failed to create temporary file"
    }

    curl -fsSL "${RESOURCE_LIB_BASE}/${name}.lib.sh" -o "${file}" 2>/dev/null || {
      bootstrap_text "error\n"
      bootstrap_die "failed to download ${RESOURCE_LIB_BASE}/${name}.lib.sh"
    }

    lib_dependencies=()
    # shellcheck disable=SC1090
    source "${file}"
    bootstrap_text "done\n"

    if [[ ${#lib_dependencies[@]} -gt 0 ]]; then
      ensure_commands "${lib_dependencies[@]}"
    fi
  done
}
