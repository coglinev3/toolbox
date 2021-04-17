#!/bin/bash

#
# sem - POSIX-like semaphores for bash scripts
# Copyright (C) 2021 - Matthias Kruk <m@m10k.eu>
#

__init() {
	if ! include "mutex"; then
		return 1
	fi

	declare -xgr __sem_path="$TOOLBOX_HOME/sem"

	return 0
}


_sem_mutexpath() {
	local sem

	sem="$1"

	if [[ "$sem" == *"/"* ]]; then
		echo "$sem.mutex"
	else
		echo "$__sem_path/$sem.mutex"
	fi
}

_sem_ownerpath() {
	local sem

	sem="$1"

	if [[ "$sem" == *"/"* ]]; then
		echo "$sem.owner"
	else
		echo "$__sem_path/$sem.owner"
	fi
}

_sem_sempath() {
	local sem

	sem="$1"

	if [[ "$sem" == *"/"* ]]; then
		echo "$sem"
	else
		echo "$__sem_path/$sem"
	fi
}

_sem_inc() {
	local sem
	local value

	sem="$1"

	if ! value=$(cat "$sem"); then
		return 1
	fi

	((value++))

	if ! echo "$value" > "$sem"; then
		return 1
	fi

	return 0
}

_sem_dec() {
	local sem
	local value

	sem="$1"

	if ! value=$(cat "$sem"); then
		return 1
	fi

	if (( value == 0 )); then
		return 1
	fi

	((value--))

	if ! echo "$value" > "$sem"; then
		return 1
	fi

	return 0
}

sem_init() {
	local name
	local value

	local mutex
	local sem
	local owner
	local err

	name="$1"
	value="$2"
	err=0

	mutex=$(_sem_mutexpath "$name")
	sem=$(_sem_sempath "$name")
	owner=$(_sem_ownerpath "$name")

	if ! [[ "$value" =~ ^[0-9]+$ ]]; then
		return 1
	fi

	if ! mkdir -p "${sem%/*}"; then
		return 1
	fi

	# If the semaphore is new, locking must succeed,
	# otherwise it was not a new semaphore
	if ! mutex_trylock "$mutex"; then
		log_error "Could not acquire $mutex"
		return 1
	fi

	if ! mutex_trylock "$owner"; then
		log_error "Could not acquire $mutex"
		err=1
	elif ! echo "$value" > "$sem"; then
		err=1
	fi

	mutex_unlock "$mutex"
	return "$err"
}

sem_destroy() {
	local name

	local mutex
	local sem
	local owner

	name="$1"

	mutex=$(_sem_mutexpath "$name")
	sem=$(_sem_sempath "$name")
	owner=$(_sem_ownerpath "$name")

	# Make sure only the owner can destroy the semaphore
	if ! mutex_unlock "$owner"; then
		return 1
	fi

	if ! rm -f "$mutex" "$sem"; then
		return 1
	fi

	return 0
}

sem_wait() {
	local name

	local mutex
	local sem
	local passed

	name="$1"

	mutex=$(_sem_mutexpath "$name")
	sem=$(_sem_sempath "$name")
	passed=false

	while ! "$passed"; do
		mutex_lock "$mutex"

		if _sem_dec "$sem"; then
			passed=true
		fi

		mutex_unlock "$mutex"

		# Workaround to prevent busy-waiting. The semaphore
		# might get increased before we get to the inotifywait,
		# in which case we'd wait for a whole second, during
		# which another process might pass the semaphore. This
		# is not ideal, but to prevent this we'd need something
		# like pthread_cond_wait().
		if ! "$passed"; then
			inotifywait -qq -t 1 "$sem"
		fi
	done

	return 0
}

sem_trywait() {
	local name

	local mutex
	local sem
	local res

	name="$1"

	mutex=$(_sem_mutexpath "$name")
	sem=$(_sem_sempath "$name")
	res=1

	mutex_lock "$mutex"

	if _sem_dec "$sem"; then
		res=0
	fi

	mutex_unlock "$mutex"

	return "$res"
}

sem_post() {
	local name

	local mutex
	local sem
	local err
	local value

	name="$1"

	mutex=$(_sem_mutexpath "$name")
	sem=$(_sem_sempath "$name")
	err=0

	mutex_lock "$mutex"

	if ! _sem_inc "$sem"; then
		err=1
	fi

	mutex_unlock "$mutex"

	return "$err"
}

sem_peek() {
	local name="$1"

	local mutex
	local sem
	local value
	local err

	mutex=$(_sem_mutexpath "$name")
	sem=$(_sem_sempath "$name")
	err=false

	mutex_lock "$mutex"

	if ! value=$(<"$sem"); then
		err=true
	fi

	mutex_unlock "$mutex"

	if "$err"; then
		return 1
	fi

	echo "$value"
	return 0
}
