#!/bin/bash

# conf.sh - Unsophisticated configuration module for Toolbox
# Copyright (C) 2021 Matthias Kruk
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

__init() {
  local script_name

  if ! include "log"; then
    return 1
  fi

  script_name="${0##*/}"
  script_name="${script_name%.*}"

  if [[ -z "$script_name" ]]; then
    log_error "Could not determine script name"
    return 1
  fi

  declare -xgr __conf_root="$TOOLBOX_HOME/conf/$script_name"
  declare -xgr __conf_default="$__conf_root/default.conf"

  if ! mkdir -p "$__conf_root"; then
    log_error "Could not create config dir"
    return 1
  fi

  return 0
}

conf_get() {
  local name="$1"
  local config="$2"

  local config_file

  if [[ -z "$config" ]]; then
    config_file="$__conf_root/default.conf"
  else
    config_file="${config##*/}"
    # If the extension corresponds to the file name, this means that no
    # extension exists. It must be a domain.
    if [[ "${config_file}" == "${config_file##*.}" ]]; then
      config_file="$__conf_root/${config}.conf"
    fi
  fi

  if ! grep -m 1 -oP "^$name\s*=\s*\\K.*" "${config_file}" 2>/dev/null; then
    return 1
  fi

  return 0
}

conf_unset() {
  local name="$1"
  local config="$2"

  local config_file

  if [[ -z "$config" ]]; then
    config_file="$__conf_root/default.conf"
  else
    config_file="${config##*/}"
    # If the extension corresponds to the file name, this means that no
    # extension exists. It must be a domain.
    if [[ "${config_file}" == "${config_file##*.}" ]]; then
      config_file="$__conf_root/${config}.conf"
    fi
  fi

  if ! sed -i -e "/^$name=.*/d" "${config_file}" &> /dev/null; then
    return 1
  fi

  return 0
}

conf_set() {
  local name="$1"
  local value="$2"
  local config="$3"

  local config_file

  if [[ -z "$config" ]]; then
    # config="default"
    config_file="$__conf_root/default.conf"
  else
    config_file="${config##*/}"
    # If the extension corresponds to the file name, this means that no
    # extension exists. It must be a domain.
    if [[ "${config_file}" == "${config_file##*.}" ]]; then
      config_file="$__conf_root/${config}.conf"
    fi
  fi

  if conf_get "$name" "$config" &> /dev/null; then
    if ! conf_unset "$name" "$config"; then
      return 1
    fi
  fi

  if ! echo "$name=$value" >> "${config_file}"; then
    return 1
  fi

  return 0
}

conf_get_domains() {
  local config

  while read -r config; do
    config="${config##*/}"
    echo "${config%.conf}"
  done < <(find "$__conf_root" -type f -iname "*.conf")

  return 0
}

conf_get_names() {
  local config="$1"

  local config_file

  if [[ -z "$config" ]]; then
    config_file="$__conf_root/default.conf"
  else
    config_file="${config##*/}"
    if [[ "${config_file}" == "${config_file##*.}" ]]; then
      config_file="$__conf_root/${config}.conf"
    fi
  fi

  if ! grep -oP "^\\K[^\s*=\s*]+" < "${config_file}" | grep -v "^#"; then
    return 1
  fi

  return 0
}

conf_read() {
  local -n ref_array="$1" || return 1
  local config="$2"

  local key
  local -a keys=()

  if [[ -z "$config" ]]; then
    config="default"
  fi

  keys=( $(conf_get_names "$config") )

  # overwrite values in ref_array with values from config file
  for key in ${keys[@]}; do
    ref_array["${key}"]=$(conf_get "${key}" "${config}")
  done

  return 0
}
