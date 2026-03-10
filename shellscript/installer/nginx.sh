#!/usr/bin/env bash

# name: nginx.sh
# author: reagin
# github: https://github.com/reagin/resource
# description: install nginx for linux

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

# define global variables
declare user_name
declare user_email
declare user_domain
declare user_password
declare cloudflare_token
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
dns_cloudflare_api_token=${cloudflare_token}
EOF
}

load_global_config() {
  if [[ -f "${global_config_path}" ]]; then
    show_info "loading data from configuration: ${global_config_path}\n"

    user_name=$(load_ini_config 'user_name' "${global_config_path}")
    user_email=$(load_ini_config 'user_email' "${global_config_path}")
    user_domain=$(load_ini_config 'user_domain' "${global_config_path}")
    user_password=$(load_ini_config 'user_password' "${global_config_path}")
    cloudflare_token=$(load_ini_config 'dns_cloudflare_api_token' "${global_config_path}")

    if [[ -z "${user_name}" || -z "${user_email}" || -z "${user_domain}" || -z "${user_password}" || -z "${cloudflare_token}" ]]; then
      show_error "there is an error in the configuration file, please repair the configuration file: ${global_config_path}\n"
      return 1
    fi
  else
    show_info "please input your personal information as prompted\n"

    user_name=$(get_input_until_success "please input your name: ")
    user_email=$(get_input_until_success "please input your email: ")
    user_domain=$(get_input_until_success "please input your domain: ")
    user_password=$(get_input_until_success "please input your password: ")
    cloudflare_token=$(get_input_until_success "please input your cloudflare token: ")

    install_content_with_comment 600 "root:root" "$(generate_global_config)" "${global_config_path}" true
  fi

  certificate_path="/etc/letsencrypt/live/${user_domain}/fullchain.pem"
  certificate_key_path="/etc/letsencrypt/live/${user_domain}/privkey.pem"
}

# install certbot and apply for a certificate for user's domain
install_certbot_binary() {
  show_info "checking the status of certbot - "
  type -t certbot &>/dev/null && {
    show_text "installed\n"
    return 0
  }
  show_text "not installed\n"

  show_info "executing command ${package_manager} certbot python3-certbot-dns-cloudflare\n"
  if sh -c "${package_manager} certbot python3-certbot-dns-cloudflare" &>/dev/null; then
    show_success "installed certbot python3-certbot-dns-cloudflare\n"
    return 0
  else
    show_error "please run command manually: ${package_manager} certbot python3-certbot-dns-cloudflare\n"
    return 1
  fi
}

apply_domain_certificate() {
  show_info "checking whether /etc/letsencrypt/live/${user_domain} exist\n"
  [[ -e "/etc/letsencrypt/live/${user_domain}" ]] && {
    show_warn "/etc/letsencrypt/live/${user_domain} is exist\n"
    return 0
  }
  show_info "/etc/letsencrypt/live/${user_domain} not exist\n"

  show_info "applying certificate for ${user_domain}: certbot certonly --dns-cloudflare --email ${user_email} --dns-cloudflare-credentials ${global_config_path} -d ${user_domain}\n"
  certbot certonly --dns-cloudflare --email "${user_email}" --dns-cloudflare-credentials "${global_config_path}" -d "${user_domain}" &>/dev/null <<<'Y' || {
    show_error "please run command manually: certbot certonly --dns-cloudflare --email ${user_email} --dns-cloudflare-credentials ${global_config_path} -d ${user_domain}\n"
    return 1
  }
  show_success "successfully applyed and saved at /etc/letsencrypt/live/${user_domain}\n"
}

# install nginx and modify default config
generate_nginx_conf() {
  cat <<EOF
user                 nginx;
pid                  /run/nginx.pid;
worker_processes     auto;
worker_rlimit_nofile 65535;

# Load modules
include              /etc/nginx/modules-enabled/*.conf;

events {
    multi_accept       on;
    worker_connections 65535;
}

http {
    charset                utf-8;
    sendfile               on;
    tcp_nopush             on;
    tcp_nodelay            on;
    server_tokens          off;
    log_not_found          off;
    types_hash_max_size    2048;
    types_hash_bucket_size 64;
    client_max_body_size   0;

    # MIME
    include                mime.types;
    default_type           application/octet-stream;

    # Logging
    access_log             off;
    error_log              /dev/null;

    # SSL
    ssl_session_timeout    1d;
    ssl_session_cache      shared:SSL:10m;
    ssl_session_tickets    off;

    # diffie-hellman parameter for DHE ciphersuites
    ssl_dhparam            /etc/nginx/dhparam.pem;

    # Mozilla Intermediate configuration
    ssl_protocols          TLSv1.2 TLSv1.3;
    ssl_ciphers            ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;

    # OCSP Stapling
    ssl_stapling           off;
    ssl_stapling_verify    off;
    resolver               1.1.1.1 8.8.8.8 valid=60s;
    resolver_timeout       2s;

    # Define server location conf map
    map \$http_upgrade \$connection_upgrade {
        default upgrade;
        ''      close;
    }

    # Define default server below
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;

        return 301 https://${user_domain}\$request_uri;
    }

    server {
        listen 443 ssl http2 default_server;
        listen [::]:443 ssl http2 default_server;
        server_name _;

        ssl_certificate     ${certificate_path};
        ssl_certificate_key ${certificate_key_path};

        # security
        include             nginxconfig.io/security.conf;

        # logging
        access_log          /var/log/nginx/access.log combined buffer=512k flush=1m;
        error_log           /var/log/nginx/error.log warn;

        # additional config
        include             nginxconfig.io/general.conf;

        return 301 https://${user_domain}\$request_uri;
    }

    # Load configs
    include                /etc/nginx/conf.d/*.conf;
    include                /etc/nginx/sites-enabled/*;
}
EOF
}

generate_domain_conf() {
  cat <<EOF
# HTTP redirect
server {
    listen      80;
    listen      [::]:80;
    server_name ${user_domain};
    return      301 https://${user_domain}\$request_uri;
}

server {
    listen              443 ssl http2;
    listen              [::]:443 ssl http2;
    server_name         ${user_domain};
    root                /var/www/${user_domain}/public;

    # SSL
    ssl_certificate     ${certificate_path};
    ssl_certificate_key ${certificate_key_path};

    # additional location config
    include             /etc/nginx/conf.d/${user_domain}/*.conf;
}
EOF
}

generate_security_conf() {
  cat <<EOF
# security headers
add_header X-XSS-Protection          "1; mode=block" always;
add_header X-Content-Type-Options    "nosniff" always;
add_header Referrer-Policy           "strict-origin-when-cross-origin" always;
add_header Permissions-Policy        "interest-cohort=()" always;
add_header Content-Security-Policy   "default-src 'self' http: https: ws: wss: data: blob: 'unsafe-inline'; frame-ancestors 'self';" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

# . files
location ~ /\.(?!well-known) {
    deny all;
}
EOF
}

generate_general_conf() {
  cat <<EOF
# favicon.ico
location = /favicon.ico {
    log_not_found off;
}

# robots.txt
location = /robots.txt {
    log_not_found off;
}

# assets, media
location ~* \.(?:css(\.map)?|js(\.map)?|jpe?g|png|gif|ico|cur|heic|webp|tiff?|mp3|m4a|aac|ogg|midi?|wav|mp4|mov|webm|mpe?g|avi|ogv|flv|wmv)$ {
    expires 7d;
}

# svg, fonts
location ~* \.(?:svgz?|ttf|ttc|otf|eot|woff2?)$ {
    add_header Access-Control-Allow-Origin "*";
    expires    7d;
}

# gzip
gzip            on;
gzip_vary       on;
gzip_proxied    any;
gzip_comp_level 6;
gzip_types      text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;
EOF
}

generate_index_html() {
  cat <<EOF
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Welcome to NGINX</title>
    <style>
      body {
        margin: 0;
        background-color: #0f172a;
        font-family: system-ui, sans-serif;
        color: #e2e8f0;
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
        min-height: 100vh;
        text-align: center;
      }
      h1 {
        font-size: 3rem;
        margin-bottom: 0.5rem;
      }
      p {
        color: #94a3b8;
        font-size: 1.1rem;
      }
      a {
        color: #38bdf8;
        text-decoration: none;
      }
      .badge {
        margin-top: 1rem;
        display: inline-block;
        padding: 0.4rem 1rem;
        background-color: #1e293b;
        border-radius: 9999px;
        font-size: 0.9rem;
        color: #38bdf8;
      }
    </style>
  </head>
  <body>
    <h1>Welcome to NGINX</h1>
    <p>If you see this page, the NGINX web server is successfully installed and working.</p>
    <div class="badge">Server Ready</div>
    <p><a href="https://nginx.org" target="_blank">Learn more at nginx.org</a></p>
  </body>
</html>
EOF
}

debian_install_nginx() {
  show_info "checking the status of nginx - "
  type -t nginx &>/dev/null && {
    show_text "installed\n"
    return 0
  }
  show_text "not installed\n"

  show_info "executing command ${package_manager} nginx\n"
  if sh -c "${package_manager} nginx" &>/dev/null; then
    show_success "successfully installed nginx\n"
    return 0
  else
    show_error "please run command manually: ${package_manager} nginx\n"
    return 1
  fi
}

debian_modify_nginx_default() {
  local user_id group_id nginx_name

  # get the name of the old nginx user
  nginx_name=$(awk -F: '$1~/(nginx|www-data)/ {print $1; exit}' /etc/passwd)

  # get old uid and gid by old name
  user_id=$(awk -F: -v name="$nginx_name" '$1==name {print $3; exit}' /etc/passwd)
  group_id=$(awk -F: -v name="$nginx_name" '$1==name {print $4; exit}' /etc/passwd)

  if [[ -z "$nginx_name" || -z "$user_id" || -z "$group_id" ]]; then
    show_error "nginx or www-data user not found in /etc/passwd\n"
    return 1
  fi

  show_info "stopping nginx.service\n"
  systemctl stop nginx.service &>/dev/null || {
    show_error "failed to stop nginx.service\n"
    return 1
  }
  show_success "successfully closed nginx.service\n"

  show_info "deleting old user named ${nginx_name}\n"
  deluser --remove-all-files ${nginx_name} &>/dev/null || {
    show_error "delete ${nginx_name} error\n"
    return 1
  }
  show_success "successfully deleted user named ${nginx_name}\n"

  show_info "creating new group named nginx\n"
  addgroup --system --gid "${group_id}" nginx &>/dev/null || {
    show_error "failed to create group named nginx\n"
    return 1
  }
  show_success "successfully created group named nginx\n"

  show_info "creating new user named nginx\n"
  adduser --system --uid "${user_id}" --gid "${group_id}" --home /var/www --shell /usr/sbin/nologin nginx &>/dev/null || {
    show_error "failed to create user named nginx\n"
    return 1
  }
  show_success "successfully created user named nginx\n"

  remove_content_with_comment "/var/www/html"
  remove_content_with_comment "/etc/nginx/sites-enabled"
  remove_content_with_comment "/etc/nginx/sites-available"

  show_info "checking for diffie-hellman key at /etc/nginx/dhparam.pem\n"
  if [[ -f "/etc/nginx/dhparam.pem" ]]; then
    if openssl dhparam -check -in /etc/nginx/dhparam.pem &>/dev/null; then
      show_success "valid diffie-hellman key already exists at /etc/nginx/dhparam.pem\n"
    else
      show_warn "existing /etc/nginx/dhparam.pem is invalid, regenerating...\n"
      if openssl dhparam -out /etc/nginx/dhparam.pem 2048 &>/dev/null; then
        show_success "successfully regenerated diffie-hellman key\n"
      else
        show_error "failed to regenerate diffie-hellman key\n"
        return 1
      fi
    fi
  else
    show_info "diffie-hellman key not found, generating...\n"
    if openssl dhparam -out /etc/nginx/dhparam.pem 2048 &>/dev/null; then
      show_success "successfully generated diffie-hellman key\n"
    else
      show_error "failed to generate diffie-hellman key\n"
      return 1
    fi
  fi

  if [[ -f /etc/logrotate.d/nginx ]]; then
    sed -Ei 's/www-data/nginx/g' /etc/logrotate.d/nginx
    systemctl daemon-reload && systemctl restart logrotate.service
  fi

  install_content_with_comment 644 "root:root" "$(generate_nginx_conf)" "/etc/nginx/nginx.conf" true
  install_content_with_comment 644 "root:root" "$(generate_domain_conf)" "/etc/nginx/sites-available/${user_domain}.conf" true
  install_content_with_comment 644 "root:root" "$(generate_security_conf)" "/etc/nginx/nginxconfig.io/security.conf" true
  install_content_with_comment 644 "root:root" "$(generate_general_conf)" "/etc/nginx/nginxconfig.io/general.conf" true
  install_content_with_comment 644 "root:root" "$(generate_index_html)" "/var/www/${user_domain}/public/index.html" true

  show_info "creating directory /etc/nginx/conf.d/${user_domain}\n"
  install -dm755 "/etc/nginx/conf.d/${user_domain}"

  show_info "creating directory /etc/nginx/sites-enabled\n"
  install -dm755 "/etc/nginx/sites-enabled"

  show_info "creating link /etc/nginx/sites-available/${user_domain}.conf to /etc/nginx/sites-enabled/${user_domain}.conf\n"
  ln -s "/etc/nginx/sites-available/${user_domain}.conf" "/etc/nginx/sites-enabled/${user_domain}.conf" &>/dev/null

  show_info "starting nginx.service\n"
  systemctl daemon-reload && systemctl start nginx.service &>/dev/null || {
    show_error "failed to start nginx.service\n"
    return 1
  }
  show_success "successfully started nginx.service\n"
}

debian_installer_nginx() {
  load_global_config          # loading the configuration file
  install_certbot_binary      # install certbot binary
  apply_domain_certificate    # apply for a certificate for the domain name
  debian_install_nginx        # install nginx binary
  debian_modify_nginx_default # modify the default configuration of nginx
}

# main program entry
case "${os_name}" in
  ubuntu | debian)
    debian_installer_nginx
    ;;
  *)
    show_error "unsupported system for ${os_name}\n"
    ;;
esac
