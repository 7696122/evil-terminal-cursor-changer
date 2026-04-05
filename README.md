# evil-terminal-cursor-changer - Change cursor shape and color in terminal Emacs

*Author:* 7696122<br>
*Version:* 0.0.4<br>
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

| Terminal | Detection | Notes |
|---|---|---|
| XTerm | `$XTERM_VERSION` | DECSCUSR sequences |
| iTerm2 | `$TERM_PROGRAM = iTerm.app` | DECSCUSR + color |
| Kitty | `$KITTY_PID` | DECSCUSR sequences |
| Konsole | `$KONSOLE_PROFILE_NAME` | Custom sequences |
| Apple Terminal | `$TERM_PROGRAM = Apple_Terminal` | DECSCUSR (requires MouseTerm Plus) |
| Gnome Terminal | `$COLORTERM = gnome-terminal` | **Note:** uses legacy `gconftool-2` |
| Dumb (mintty, etc.) | `$TERM = dumb` | DECSCUSR fallback |

If your terminal is not correctly detected, you can override the detection:

`M-x customize-group RET evil-terminal-cursor-changer RET`

Set `etcc-term-type-override` to the appropriate terminal type.

## Customization ##

| Variable | Default | Description |
|---|---|---|
| `etcc-use-color` | `nil` | Whether to change cursor color |
| `etcc-use-blink` | `t` | Whether to use blinking cursor sequences |

## License

GPL v3 or later.
