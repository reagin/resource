#!/usr/bin/env bash

# opengfw_installer.sh
# Author: rehuony
# Description: Scripts for installing sing-box server agents
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
      printf "\e[38;2;215;0;0mError: unsupported system for ${os_name}\e[0m\n"
      exit 1
      ;;
  esac

  printf "\e[2mCurrent system is: ${os_arch}_${os_name}_${os_type}\e[0m\n"
}

# Check whether the instructions used in the current script exist
check_dependencies() {
  local command_dependency package_dependency

  command_dependency=("curl" "openssl" "sed" "grep" "awk" "mktemp" "systemctl" "adduser")
  package_dependency=("curl" "openssl" "sed" "grep" "gawk" "coreutils" "systemd" "passwd")

  if [[ ${#command_dependency[@]} == 0 ]]; then
    return 0
  fi

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
  local script_file external_script_links command_dependency package_dependency

  command_dependency=()
  package_dependency=()
  external_script_links=(
    'https://cdn.jsdelivr.net/gh/rehuony/resource@main/shellscript/library/message.lib.sh'
    'https://cdn.jsdelivr.net/gh/rehuony/resource@main/shellscript/library/utility.lib.sh'
  )

  if [[ ${#external_script_links[@]} == 0 ]]; then
    return 0
  fi

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

    printf "done\e[0m\n"
  done

  if [[ ${#command_dependency[@]} == 0 ]]; then
    return 0
  fi

  printf "\e[2mInstalling external command dependencies ...\e[0m\n"

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

# Check whether the execution user is root
check_permission
# Check the environment of the current script
check_environment
# Check whether the instructions used in the current script exist
check_dependencies
# Source external script resources
source_external_scripts

# NOTE: Install certbot and apply for a certificate for user's domain
install_certbot_binary() {
  show_info "detecting the status of certbot - "
  type -t certbot &>/dev/null && {
    show_text "installed\n"
    return 0
  }
  show_text "not installed\n"

  show_info "executing command ${package_manager} certbot python3-certbot-dns-cloudflare\n"
  if sh -c "${package_manager} certbot python3-certbot-dns-cloudflare" &>/dev/null; then
    show_success "successfully installed certbot python3-certbot-dns-cloudflare\n"
    return 0
  else
    show_error "please run command manually: ${package_manager} certbot python3-certbot-dns-cloudflare\n"
    return 1
  fi
}

certbot_apply_certificate() {
  local dns_token_path

  # apply certificate using cloudflare's dns verification
  dns_token_path="/etc/letsencrypt/cloudflare.ini"

  install_content_with_comment 600 "root:root" "dns_cloudflare_api_token=${user_token}" "${dns_token_path}" true

  show_info "register ${user_email} for certbot\n"
  certbot register --email "${user_email}" --no-eff-email &>/dev/null <<<'Y' || {
    show_warn "certbot register --email "${user_email}" --no-eff-email failed to execute\n"
    show_warn "unregister old user for certbot\n"
    certbot unregister &>/dev/null <<<'D' || {
      show_error "please run command manually: certbot certbot register --email ${user_email} --no-eff-email <<<'Y'\n"
      return 1
    }
  }
  show_success "successfully registered ${user_email}\n"

  show_info "applying certificate for ${user_domain} *.${user_domain}\n"
  certbot certonly --dns-cloudflare --dns-cloudflare-credentials "${dns_token_path}" -d "${user_domain}" -d "*.${user_domain}" --dry-run &>/dev/null || {
    show_error "please run command manually: certbot certonly --dns-cloudflare --dns-cloudflare-credentials "${dns_token_path}" -d "${user_domain}" -d "*.${user_domain}"\n"
    return 1
  }
  show_success "successfully applyed and saved at /etc/letsencrypt/live/${user_domain}\n"
}

# NOTE: Install nginx and modify default config
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
    client_max_body_size   16M;

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

    # Diffie-Hellman parameter for DHE ciphersuites
    ssl_dhparam            /etc/nginx/dhparam.pem;

    # Mozilla Intermediate configuration
    ssl_protocols          TLSv1.2 TLSv1.3;
    ssl_ciphers            ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;

    # OCSP Stapling
    ssl_stapling           on;
    ssl_stapling_verify    on;
    resolver               1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4 valid=60s;
    resolver_timeout       2s;

    # Load configs
    include                /etc/nginx/conf.d/*.conf;
    include                /etc/nginx/sites-enabled/*;
}
EOF
}

generate_domain_conf() {
  cat <<EOF
server {
    listen              443 ssl http2;
    listen              [::]:443 ssl http2;
    server_name         ${user_domain};
    root                /var/www/${user_domain}/public;

    # SSL
    ssl_certificate     ${certificate_path};
    ssl_certificate_key ${certificate_key_path};

    # security
    include             nginxconfig.io/security.conf;

    # logging
    access_log          /var/log/nginx/access.log combined buffer=512k flush=1m;
    error_log           /var/log/nginx/error.log warn;

    # additional config
    include             nginxconfig.io/general.conf;
}

# subdomains redirect
server {
    listen              443 ssl http2;
    listen              [::]:443 ssl http2;
    server_name         *.${user_domain};

    # SSL
    ssl_certificate     ${certificate_path};
    ssl_certificate_key ${certificate_key_path};
    return              301 https://${user_domain}\$request_uri;
}

# HTTP redirect
server {
    listen      80;
    listen      [::]:80;
    server_name .${user_domain};
    return      301 https://${user_domain}\$request_uri;
}
EOF
}

generate_security_conf() {
  cat <<EOF
# security headers
add_header X-XSS-Protection          "1; mode=block" always;
add_header X-Content-Type-Options    "nosniff" always;
add_header Referrer-Policy           "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy   "default-src 'self' http: https: ws: wss: data: blob: 'unsafe-inline'; frame-ancestors 'self';" always;
add_header Permissions-Policy        "interest-cohort=()" always;
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

generate_nginxconfig_href() {
  cat <<EOF
https://www.digitalocean.com/community/tools/nginx?domains.0.https.certType=custom&domains.0.https.sslCertificate=%2Fetc%2Fletsencrypt%2Flive%2Fexample.com%2Ffullchain.pem&domains.0.https.sslCertificateKey=%2Fetc%2Fletsencrypt%2Flive%2Fexample.com%2Fprivkey.pem&domains.0.php.php=false&domains.0.routing.index=index.html&domains.0.routing.fallbackPhp=false&global.https.ocspOpenDns=false&global.security.referrerPolicy=strict-origin-when-cross-origin&global.nginx.user=nginx&global.app.lang=zhCN
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
      .badge {
        margin-top: 1rem;
        display: inline-block;
        padding: 0.4rem 1rem;
        background-color: #1e293b;
        border-radius: 9999px;
        font-size: 0.9rem;
        color: #38bdf8;
      }
      a {
        color: #38bdf8;
        text-decoration: none;
      }
    </style>
  </head>
  <body>
    <h1>Welcome to NGINX</h1>
    <p>
      If you see this page, the NGINX web server is successfully installed and working.
    </p>
    <div class="badge">Server Ready</div>
    <p><a href="https://nginx.org" target="_blank">Learn more at nginx.org</a></p>
  </body>
</html>
EOF
}

install_nginx_binary() {
  show_info "detecting the status of nginx - "
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

modofy_nginx_default() {
  local user_id group_id

  # Get old uid and gid from /etc/passwd
  user_id=$(awk -F: '$1~/(nginx|www-data)/ {print $3}' /etc/passwd)
  group_id=$(awk -F: '$1~/(nginx|www-data)/ {print $4}' /etc/passwd)

  show_info "stopping nginx.service\n"
  systemctl stop nginx.service &>/dev/null || {
    show_error "failed to stop nginx.service\n"
    return 1
  }
  show_success "successfully closed nginx.service\n"

  show_info "deleting old user named nginx\n"
  if deluser --remove-all-files nginx &>/dev/null; then
    show_success "successfully deleted user named nginx\n"
  else
    show_warn "user named nginx does not exist\n"
  fi

  show_info "deleting old user named www-data\n"
  if deluser --remove-all-files www-data &>/dev/null; then
    show_success "successfully deleted user named www-data\n"
  else
    show_warn "user named www-data does not exist\n"
  fi

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

  show_info "generating diffie-hellman keys at /etc/nginx/dhparam.pem\n"
  openssl dhparam -out /etc/nginx/dhparam.pem 2048 &>/dev/null || {
    show_error "failed to generate diffie-hellman keys\n"
    return 1
  }
  show_success "successfully generated diffie-hellman keys\n"

  install_content_with_comment 644 "root:root" "$(generate_nginx_conf)" "/etc/nginx/nginx.conf" true
  install_content_with_comment 644 "root:root" "$(generate_domain_conf)" "/etc/nginx/sites-available/${user_domain}.conf" true
  install_content_with_comment 644 "root:root" "$(generate_security_conf)" "/etc/nginx/nginxconfig.io/security.conf" true
  install_content_with_comment 644 "root:root" "$(generate_general_conf)" "/etc/nginx/nginxconfig.io/general.conf" true
  install_content_with_comment 644 "root:root" "$(generate_nginxconfig_href)" "/etc/nginx/nginxconfig.txt" true
  install_content_with_comment 644 "root:root" "$(generate_index_html)" "/var/www/${user_domain}/public/index.html" true

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

# NOTE: Install sing-box and set up agent services
genetate_sing-box_config() {
  cat <<EOF
{
  "log": {
    "level": "warn",
    "output": "sing-box.log",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": 8443,
      "users": [
        {
          "name": "${user_name}",
          "uuid": "${user_uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${user_domain}",
        "alpn": ["h3", "h2", "http/1.1"],
        "certificate_path": "${certificate_path}",
        "key_path": "${certificate_key_path}"
      }
    },
    {
      "type": "hysteria2",
      "listen": "::",
      "listen_port": 8080,
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

install_sing-box_binary() {
  local latest_release latest_version package_name download_url

  show_info "detecting the status of sing-box ... "
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
  if sh -c "${package_installer} ${package_name}" &>/dev/null; then
    show_success "successfully installed sing-box\n"
    return 0
  else
    show_error "failed to install sing-box\n"
    return 1
  fi
}

modofy_sing-box_default() {
  install_content_with_comment 644 "root:root" "$(genetate_sing-box_config)" "/etc/sing-box/config.json" true
  # Add system services for sing-box and start services
  show_info "adding system services for sing-box and start services\n"
  systemctl enable sing-box &>/dev/null && systemctl start sing-box &>/dev/null || {
    show_error "failed to add system services for sing-box\n"
    return 1
  }
  show_success "successfully added system services for sing-box\n"
}

# NOTE: Main program entry
# Input personal information
read -e -p "email: " user_email
read -e -p "username: " user_name
read -e -p "domain name: " user_domain
read -e -p "cloudflare token: " user_token

# Generate global configuration information
user_uuid=$(sing-box generate uuid)
user_password=$(generate_random_password)
certificate_path="/etc/letsencrypt/live/${user_domain}/fullchain.pem",
certificate_key_path="/etc/letsencrypt/live/${user_domain}/privkey.pem"

# Install certbot using package manager
install_certbot_binary
# Apply for let's encrypt certificate using cloudfalre's dns service
certbot_apply_certificate

# Install nginx using package manager
install_nginx_binary
# Delete nginx's default user, group and modify the default configuration of nginx
modofy_nginx_default

# Install sing-box using package installer
install_sing-box_binary
# Overwrite sing-box configuration file
modofy_sing-box_default
