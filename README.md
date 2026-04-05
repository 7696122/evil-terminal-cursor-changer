# evil-terminal-cursor-changer - Change cursor shape and color in terminal Emacs

*Author:* 7696122<br>
*Version:* 0.0.5<br>
*URL:* [https://github.com/7696122/evil-terminal-cursor-changer](https://github.com/7696122/evil-terminal-cursor-changer)<br>

[![MELPA](http://melpa.org/packages/evil-terminal-cursor-changer-badge.svg)](http://melpa.org/#/evil-terminal-cursor-changer)

## Overview ##

evil-terminal-cursor-changer changes cursor shape and color when running
Emacs in a terminal. It reads the standard `cursor-type` variable and sends
the appropriate escape sequences to your terminal emulator.

It works with any package that sets `cursor-type` — including evil-mode, meow,
ryo-modal, and others — or can be used standalone.

## Install ##

1. Configure MELPA: http://melpa.org/#/getting-started

2. `M-x package-install RET evil-terminal-cursor-changer RET`

3. Add to your Emacs config (e.g. `~/.emacs`):

```elisp
(unless (display-graphic-p)
  (require 'evil-terminal-cursor-changer)
  (evil-terminal-cursor-changer-activate))  ;; or (etcc-on)
```

## With evil-mode ##

evil-mode sets `cursor-type` automatically per state, so etcc works out of the
box. You can customize the shapes via evil's variables:

```elisp
(setq evil-motion-state-cursor 'box)  ; █
(setq evil-visual-state-cursor 'box)  ; █
(setq evil-normal-state-cursor 'box)  ; █
(setq evil-insert-state-cursor 'bar)  ; ⎸
(setq evil-emacs-state-cursor  'hbar) ; _
```

## Without evil-mode ##

Set `cursor-type` directly and etcc will apply the corresponding terminal
escape sequence:

```elisp
(setq cursor-type 'bar)   ; ⎸ vertical bar
(setq cursor-type 'box)   ; █ block
(setq cursor-type 'hbar)  ; _ underline
```

## Supported Terminals ##

All terminals use standard DECSCUSR escape sequences for cursor shape,
and OSC 12 for cursor color.

| Terminal | Detection |
|---|---|
| XTerm | `$XTERM_VERSION` |
| iTerm2 | `$TERM_PROGRAM = iTerm.app` |
| Kitty | `$KITTY_PID` |
| Konsole | `$KONSOLE_PROFILE_NAME` |
| Apple Terminal | `$TERM_PROGRAM = Apple_Terminal` |
| Gnome Terminal | `$COLORTERM` (gnome-terminal, kgx, terminator) |
| Alacritty | `$TERM` starts with `alacritty` or `$ALACRITTY_WINDOW_ID` |
| WezTerm | `$TERM_PROGRAM = WezTerm` |
| Windows Terminal | `$WT_SESSION` |
| foot | `$TERM` starts with `foot` |
| Ghostty | `$TERM_PROGRAM = ghostty` |
| Hyper | `$TERM_PROGRAM = Hyper` |
| Rio | `$TERM_PROGRAM = Rio` |
| Tabby | `$TERM_PROGRAM = Tabby` |
| Dumb (mintty, etc.) | `$TERM = dumb` |

If your terminal is not correctly detected, you can override the detection:

`M-x customize-group RET evil-terminal-cursor-changer RET`

Set `etcc-term-type-override` to the appropriate terminal type.

## Customization ##

| Variable | Default | Description |
|---|---|---|
| `etcc-use-color` | `nil` | Whether to change cursor color (reads `cursor-color` frame parameter) |
| `etcc-use-blink` | `t` | Whether to use blinking cursor sequences |

## License

GPL v3 or later.
