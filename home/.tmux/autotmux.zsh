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

  # Allocating a session ID.
  # There are two possibilities here. First, we could have a list of session
  # IDs that is densely packed; e.g. [0, 1, 2, 3, 4]. In this case, we want to
  # allocate 5.
  #
  # If, on the other hand, there is a gap, then it becomes unsafe to just use
  # #sessions as the new ID. So instead, we search through the list to see if
  # the difference between any pair is greater than one. (e.g. for [0, 1, 3, 5]
  # we would use 2)

  sessions=($(tmux ls -F '#{session_name}' \
              | egrep "^ssh-$USER-[0-9]+$" \
              | sed "s/^ssh-$USER-//" \
              | sort -n))
  session_index=${#sessions[@]}

  for ((i = 1; i < ${#sessions[@]}; i++)); do
    if (( $sessions[i+1] - $sessions[i] > 1 )); then
      session_index=$(($sessions[i] + 1))
      break
    fi
  done

  exec tmux -f ~/.tmux/ssh.conf new-session -s ssh-$USER-$session_index -t ssh-$USER
fi
#if [[ -n "$TMUX" ]] ; then
#  export DISPLAY=$(cat ~/.ssh/display.txt)
#fi
