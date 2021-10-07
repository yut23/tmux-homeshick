# Bashrc SSH-tmux wrapper | Spencer Tipping
# Licensed under the terms of the MIT source code license

# Source this just after the PS1-check to enable auto-tmuxing of your SSH
# sessions. See https://github.com/spencertipping/bashrc-tmux for usage
# information.

# Modified for zsh by yut23

should_autotmux() {
  local yes=0 no=1  # for my sanity
  if (( ! $+commands[tmux] )); then
    return $no
  fi
  # check tmux version: tpm only supports 1.9+
  # from ~/.tmux/plugins/tpm/scripts/check_tmux_version.sh
  local min_version="1.9"
  local min_version_int=$(tr -dC '[:digit:]' <<<"$min_version")
  local curr_version=$(tmux -V | cut -d' ' -f2)
  local curr_version_int=$(tr -dC '[:digit:]' <<<"$curr_version")
  if [[ $curr_version_int -lt $min_version_int ]]; then
    echo "tmux version must be at least $min_version; currently have $curr_version"
    reason='outdated tmux'
    return $no
  fi
  if [[ -z "${SSH_CONNECTION+x}" || -n "${TMUX+x}" ]]; then
    # not an ssh login or already in tmux
    return $no
  fi

  case ${AUTOTMUX-x} in
    y)
      reason='$AUTOTMUX=y'
      return $yes
      ;;
    n)
      # propagate to subshells
      export AUTOTMUX=sub
      reason='$AUTOTMUX=n'
      return $no
      ;;
    sub)
      return $no
      ;;
  esac

  local -a _ssh_connection
  # space-separated values: client IP, client port, server IP, server port
  _ssh_connection=(${=SSH_CONNECTION})
  #if [[ $_ssh_connection[1] == $_ssh_connection[3] ]]; then
  if [[ $_ssh_connection[1] == ::1 ]]; then
    reason='local connection'
    return $no
  fi

  if [[ -f "$HOME/.notmux" ]]; then
    rm "$HOME/.notmux"
    reason='~/.notmux'
    return $no
  fi

  return $yes
}

if should_autotmux; then
  if [[ -n ${reason+x} ]]; then
    >&2 echo "Forcing auto-tmux due to $reason"
    unset reason
  fi
  unset AUTOTMUX
  export TMUX_SSH=1
  # this will run in the current shell, rather than a subshell
  source ~/bin/tmx
else
  if [[ -n ${reason+x} ]]; then
    >&2 echo "Skipping auto-tmux due to $reason"
    unset reason
  fi
  if [[ ${AUTOTMUX-x} != sub ]]; then
    unset AUTOTMUX
  fi
fi
