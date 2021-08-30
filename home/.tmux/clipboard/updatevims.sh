#!/bin/bash

# Sends USR1 signal to running vims/nvims to cause them to pull in a clipboard update

update_nvims() {
	# Make sure nvim exists
	if ! command -v nvim &>/dev/null; then return 0; fi

	# If nvim version is too old, it may crash on USR1, so don't try it
	local NVIM_VER
	NVIM_VER="$(nvim -v | grep '^NVIM' | head -n1 | cut -d ' ' -f 2)"
	if [[ "$NVIM_VER" < "v0.4" ]]; then return 0; fi

	killall -USR1 -u "$(whoami)" -r '^nvi(m|ew)(diff)?$' &>/dev/null
	return 0
}

update_vims() {
	# Make sure vim exists
	if ! command -v vim &>/dev/null; then return 0; fi

	# If vim version is too old, it may crash on USR1, so don't try it
	local VIM_VER
	VIM_VER="$(vim --version | grep '^VIM - Vi IMproved' | head -n1 | cut -d' ' -f 5)"
	# shellcheck disable=SC2072  # this comparison is intentional
	if [[ "$VIM_VER" < "8.2" ]]; then return 0; fi
	# check for actual SigUSR1 support, since it was added in a patch
	# note: --not-a-term requires vim > 8.0.1387
	local cmd='if exists("##SigUSR1")|cq 0|else|cq 1|endif'
	if ! vim -u NONE --not-a-term --cmd "$cmd" >/dev/null; then return 0; fi

	killall -USR1 -u "$(whoami)" -r '^vi(m|ew)(diff)?$' &>/dev/null
	return 0
}

update_nvims
update_vims
