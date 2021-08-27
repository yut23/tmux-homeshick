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
  if ! tmux ls -F '#{session_name}' 2> /dev/null | grep "^ssh-$USER$" &> /dev/null; then
    system_name="$system_name" tmux -f ~/.tmux/ssh.conf new-session -s ssh-$USER -d
  fi

  # anonymous shell function, for local option scoping
  () {
    emulate -L zsh
    setopt extendedglob
    local -a sessions
    # Inner expansion:
    #   split tmux output into an array by lines
    #   quote to prevent further whitespace splitting
    # Outer expansion:
    #   PCRE: s/^(?:${prefix}([1-9][0-9]*)|.*)$/\1/
    #   (n): sort by numeric value
    #   no quotes to discard empty elements (i.e. those that didn't match)
    # Roughly equivalent to: ($(tmux ... | sed -nE "s/ssh-$USER-([1-9][0-9]*)$/\1/p" | sort -n))
    sessions=(${(n)"${(@f)$(tmux ls -F '#{session_name}')}"/(#s)(ssh-$USER-(#b)([1-9][0-9]#)|*)(#e)/$match[1]})

    # Allocating a session ID.
    # There are two possibilities here. First, we could have a list of session
    # IDs that is densely packed; e.g. [1, 2, 3, 4]. In this case, we want to
    # allocate 5.
    #
    # If, on the other hand, there is a gap, then it becomes unsafe to just use
    # #sessions as the new ID. So instead, we search through the list to find the
    # first mismatch between the session ID and its position in the list.
    #
    # Examples:
    #   [1, 2, 4, 6] vs. [1, 2, 3, 4] -> i=3 and s[i]=4 don't match, use 3
    #   [2, 3, 4]    vs. [1, 2, 3]    -> i=1 and s[i]=2 don't match, use 1
    session_index=$(($#sessions + 1))
    for ((i = 1; i <= $#sessions; i++)); do
      if (($sessions[i] != i)); then
        session_index=$i
        break
      fi
    done
  }

  exec tmux -f ~/.tmux/ssh.conf new-session -s ssh-$USER-$session_index -t ssh-$USER
else
  if [[ -n ${reason+x} ]]; then
    >&2 echo "Skipping auto-tmux due to $reason"
    unset reason
  fi
  if [[ ${AUTOTMUX-x} != sub ]]; then
    unset AUTOTMUX
  fi
fi
