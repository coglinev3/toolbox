#!/bin/bash

# log.sh - Toolbox module for logging and debugging
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

	script_name="${0##*/}"

	if [[ -z "$script_name" ]]; then
		echo "Could not determine script name" 1>&2
		return 1
	fi

	declare -xgri __log_debug=4
    declare -xgri __log_verbose=3
	declare -xgri __log_info=2
	declare -xgri __log_warning=1
	declare -xgri __log_error=0

	declare -xgi __log_verbosity="$__log_warning"
	declare -xgr __log_path="$TOOLBOX_HOME/log"
	declare -xgr __log_file="$__log_path/$script_name.log"

    declare -xg __log_color_default="$(tput sgr0)"

	if ! mkdir -p "$__log_path"; then
		return 1
	fi

	return 0
}

log_set_verbosity() {
	local verb="$1"

	if (( verb < __log_error )); then
		verb="$__log_error"
	elif (( verb > __log_debug )); then
	        verb="$__log_debug"
	fi

	__log_verbosity="$verb"

	return 0
}

log_get_verbosity() {
	echo "$__log_verbosity"
}

log_increase_verbosity() {
	local verb

	verb=$(log_get_verbosity)
	((verb++))
	log_set_verbosity "$verb"

	return 0
}

log_decrease_verbosity() {
	local verb

	verb=$(log_get_verbosity)
	((verb--))
	log_set_verbosity "$verb"

	return 0
}

_log_write() {
	local level="$1"
    local color="$2"
	local prefix="$3"

	local line

	if (( __log_verbosity < level )); then
		local drain
		[[ $# == 3 ]] &&  IFS="" read -r -d "" drain
		return 0
	fi

	if (( $# > 3 )); then
		for line in "${@:4}"; do
			local timestamp

			if ! timestamp=$(date +"%F %T %z"); then
				echo "Could not get timestamp" 1>&2
				return 1
			fi

			if ! echo "$timestamp $$ $prefix $line" >> "$__log_file"; then
				echo "Could not write to $__log_file" 1>&2
			fi

			echo "${color}$timestamp $$ $prefix $line${__log_color_default}" 1>&2
		done
	else
		while IFS="" read -r line; do
			_log_write "$level" "$color" "$prefix" "$line"
		done
	fi

	return 0
}

log_stacktrace() {
	local i
	local indent

	echo "Stacktrace:"
	indent="  "

	for (( i = "${#FUNCNAME[@]}"; i > 1; )); do
		((i--))
		echo "$indent${BASH_SOURCE[$i]}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}"
		indent+=" "
	done

	return 0
}

log_highlight() {
	local tag="$1"
	local lines=("${@:2}")

	echo "===== BEGIN $tag ====="
	if (( ${#lines[@]} > 0 )); then
		local arg

		for arg in "${lines[@]}"; do
			echo "$arg"
		done
	else
		cat /dev/stdin
	fi
	echo "===== END $tag ====="
}

log_debug() {
	local lines=("$@")
    local log_color_blue="$(tput setaf 4)"

	local dbgtag

	dbgtag="${BASH_SOURCE[1]}:${BASH_LINENO[1]} ${FUNCNAME[1]}:"

	_log_write "$__log_debug" "$log_color_blue" "[DBG] $dbgtag" "${lines[@]}"
}

log_verbose() {
	local lines=("$@")

	_log_write "$__log_verbose" "$__log_color_default" "[INF]" "${lines[@]}"
}

log_info() {
	local lines=("$@")

	_log_write "$__log_info" "$__log_color_default" "[INF]" "${lines[@]}"
}

log_warn() {
  local lines=("$@")
  local log_color_yellow="$(tput setaf 3)"

  _log_write "$__log_warning" "$log_color_yellow" "[WRN]" "${lines[@]}"
}

log_error() {
	local lines=("$@")
    local log_color_red="$(tput setaf 1)"

	_log_write "$__log_error" "$log_color_red" "[ERR]" "${lines[@]}"
}
