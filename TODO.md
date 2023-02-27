# Nested tmux session improvements

The current solution (Ctrl-Up & Ctrl-Down) works alright, but switching between
windows with and without a nested session is rather annoying. It would be nice
if the nesting state could be saved per-window/pane. EDIT: only per-window,
since having it change between panes would break ctrl-hjkl navigation

Other stuff: It doesn't allow any deeper nesting, and it would be neat if we
could (properly) autodetect whether a nested tmux session is present.

## Per-window state

* 2 custom window options: `@has-nested-session` and `@forward-to-inner`
* `@has-nested-session` is set for any window containing a nested tmux session (local or over ssh)
  * figure out how to unset after exiting nested session
* `@forward-to-inner` actually controls where key sequences go
  * boolean currently, but might be an int later if I want to allow deeper nesting

* Ctrl-up/down set/unset `@forward-to-inner` if `@has-nested-session` is 1
* ~~See https://github.com/tmux/tmux/issues/3361 (`send-key -K`) to reduce code duplication~~
  Nope, just use `set-hook -R` to run the hook immediately.

+ What should happen if there are multiple panes with nested sessions in one window?

## Automatic detection

1. When an inner session is launched, the new inner session sets the outer
   window title to something recognizable.
   - set to `__TMUX_NESTED_SESSION__ $system_name`, then `$system_name`
   Can either send escape sequence via tmux passthrough, (`DCS tmux;${escape_sequence//\033/\033\033}ST`)
   or maybe writing directly to the ssh pty (`tmux display -p '#{client_tty}'`)
2. Outer session catches this with a hook on `%window-renamed`
   - maybe it sends a custom key binding to the inner session to tell it it's nested?
3. Inner session sets outer window title to something cleaner? Or outer session
   restores the previous title somehow
   - can go back to automatic-rename by setting the title to the empty string

4. Inner session informs the outer session when it exits, or outer session
   watches for changes to `#{pane_current_command}` or so


Having the inner session change the title is nice because tmux already has a hook
for it, and terminal emulators handle it fine in case it's not nested.

+ to test: xterm window title/icon stack (`CSI 22;0 t` to push, `CSI 23;0 t` to pop)
  * tmux/input.c: `input_csi_dispatch_winops()`, `screen_{push,pop}_title()`
  * `OSC 2;title ST`: tmux calls `screen_set_title()`
  * `ESC k title ST`: handled in `input_exit_rename()`
* doesn't work, unfortunately (they only change the pane title, not the window title)


---

Whenever `#{pane_current_command}` changes:

* if `#{pane_current_command}` is tmux, then definitely a nested session
* if `#{pane_current_command}` is ssh, then maybe a nested session:
  * send a custom `user-keys` binding from outer session
  * in inner session, change outer window title to a sentinel value
  * in a hook on %window-renamed, check if the sentinel value is present

check if window name is automatic
set window name to something unique and recognizable
