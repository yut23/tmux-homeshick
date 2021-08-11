# Bashrc SSH-tmux wrapper | Spencer Tipping
# Licensed under the terms of the MIT source code license

# Source this just after the PS1-check to enable auto-tmuxing of your SSH
# sessions. See https://github.com/spencertipping/bashrc-tmux for usage
# information.

# Modified for zsh by yut23

if [[ -z "${SSH_CLIENT+1}" || "${SSH_CLIENT}" =~ 127\.0\.0\.1 || "${SSH_CLIENT}" =~ ::1 ]]; then
  return
fi

if [[ -f "$HOME/.notmux" ]]; then
  rm "$HOME/.notmux"
  echo 'Skipping auto-tmux due to ~/.notmux'
  return
fi

if [[ -n "${NO_AUTOTMUX:+x}" ]]; then
  unset NO_AUTOTMUX
  echo 'Skipping auto-tmux due to $NO_AUTOTMUX'
  return
fi

if [[ -z "$TMUX" && -n "$SSH_CONNECTION" ]] && which tmux &> /dev/null; then
  export TMUX_SSH=1
  if ! tmux ls -F '#{session_name}' 2> /dev/null | grep "^ssh-$USER$" &> /dev/null; then
    system_name="$system_name" tmux -f ~/.tmux/ssh.conf new-session -s ssh-$USER -d
  fi

  # anonymous shell function, for local option scoping
  () {
    emulate -L zsh
    setopt extendedglob
    local -a sessions
    local prefix="ssh-$USER-"
    sessions=(${(n)${(@M)"${(f)$(tmux ls -F '#{session_name}')}":#(#s)${prefix}[1-9][0-9]#(#e)}#$prefix})
    #            ^     ^     ^                                  ^ ^----------+-----------^ ^---+---^
    #            |     |     +- split output by lines           |            |                 |
    #            |     +----- delete non-matching elements -----+     /^${prefix}\d+$/         |
    #            |                                                             delete $prefix -+
    #            +- sort by numeric value
    # Equivalent to: ($(tmux ... | grep "^ssh-$USER-[1-9][0-9]*$" | sed "s/^ssh-$USER-//" | sort -n))

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
fi
#if [[ -n "$TMUX" ]] ; then
#  export DISPLAY=$(cat ~/.ssh/display.txt)
#fi
