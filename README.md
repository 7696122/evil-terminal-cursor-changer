# evil-terminal-cursor-changer - Change cursor shape and color by evil state in terminal

*Author:* 7696122<br>
*Version:* 0.0.4<br>
*URL:* [https://github.com/7696122/evil-terminal-cursor-changer](https://github.com/7696122/evil-terminal-cursor-changer)<br>

[![MELPA](http://melpa.org/packages/evil-terminal-cursor-changer-badge.svg)](http://melpa.org/#/evil-terminal-cursor-changer)

## Introduce ##

evil-terminal-cursor-changer is changing cursor shape and color by evil state for evil-mode.

When running in terminal, It's especially helpful to recognize evil's state.

## Install ##

1. Config melpa: http://melpa.org/#/getting-started

2. M-x package-install RET evil-terminal-cursor-changer RET

3. Add code to your emacs config file:（for example: ~/.emacs）：

         (unless (display-graphic-p)
                 (require 'evil-terminal-cursor-changer)
                 (evil-terminal-cursor-changer-activate) ; or (etcc-on)
                 )

If want change cursor shape type, add below line. This is evil's setting.

         (setq evil-motion-state-cursor 'box)  ; █
         (setq evil-visual-state-cursor 'box)  ; █
         (setq evil-normal-state-cursor 'box)  ; █
         (setq evil-insert-state-cursor 'bar)  ; ⎸
         (setq evil-emacs-state-cursor  'hbar) ; _

Now, works in XTerm, Gnome Terminal(Gnome Desktop), iTerm(Mac OS
X), Konsole(KDE Desktop), dumb(etc. mintty), Apple
Terminal.app(restrictive supporting). If using Apple Terminal.app,
must install SIMBL(http://www.culater.net/software/SIMBL/SIMBL.php)
and MouseTerm
plus(https://github.com/saitoha/mouseterm-plus/releases) to use
evil-terminal-cursor-changer. That makes to support VT's DECSCUSR
sequence.

## Change Log

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation; either version 3, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; see the file COPYING.  If not, write to
the Free Software Foundation, Inc., 51 Franklin Street, Fifth
Floor, Boston, MA 02110-1301, USA.

Code:


---
Converted from `evil-terminal-cursor-changer.el` by [*el2markdown*](https://github.com/Lindydancer/el2markdown).
