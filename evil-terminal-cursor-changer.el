;;; evil-terminal-cursor-changer.el --- Change cursor by evil state on terminal.
;;
;; Filename: evil-terminal-cursor-changer.el
;; Description: Change cursor by evil state on terminal.
;; Author: 7696122
;; Maintainer:
;; Created: Sat Nov  2 12:17:13 2013 (+0900)
;; Version:
;; Package-Requires: ()
;; Last-Updated: Wed Apr 23 16:00:38 2014 (+0900)
;;           By: 7696122
;;     Update #: 144
;; URL:
;; Doc URL:
;; Keywords:
;; Compatibility:
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;
;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Change Log:
;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Code:


;; https://code.google.com/p/iterm2/wiki/ProprietaryEscapeCodes
;; http://unix.stackexchange.com/questions/3759/how-to-stop-cursor-from-blinking
;; http://www.joinc.co.kr/modules/moniwiki/wiki.php/man/1/echo
;; http://vim.wikia.com/wiki/Change_cursor_shape_in_different_modes
(defvar box-cursor-string "\e]50;CursorShape=0\x7")
(defvar bar-cursor-string "\e]50;CursorShape=1\x7")
(defvar hbar-cursor-string "\e]50;CursorShape=2\x7")
(defvar tmux-box-cursor-string "\ePtmux;\e\e]50;CursorShape=0\x7\e\\")
(defvar tmux-bar-cursor-string "\ePtmux;\e\e]50;CursorShape=1\x7\e\\")
(defvar tmux-hbar-cursor-string "\ePtmux;\e\e]50;CursorShape=2\x7\e\\")
(defvar gnome-terminal-bar-cursor-string
  "gconftool-2 --type string --set /apps/gnome-terminal/profiles/Profile0/cursor_shape ibeam")
(defvar gnome-terminal-box-cursor-string
  "gconftool-2 --type string --set /apps/gnome-terminal/profiles/Profile0/cursor_shape block")
(defvar gnome-terminal-hbar-cursor-string
  "gconftool-2 --type string --set /apps/gnome-terminal/profiles/Profile0/cursor_shape underline")

;; konsole
;; "\e]50;CursorShape=2\x7"
;; "\e]50;CursorShape=1\x7"
;; "\e]50;CursorShape=0\x7"
;; (send-string-to-terminal "\e]50;CursorShape=2\x7")

(defun is-iterm ()
  "Running on iTerm."
  (string= (getenv "TERM_PROGRAM") "iTerm.app"))

(defun is-gnome-terminal ()
  "Running on gnome-terminal."
  (string= (getenv "COLORTERM") "gnome-terminal"))

(defun is-tmux ()
  "Running on tmux."
  (if (getenv "TMUX")
      t
    nil))

(defun set-bar-cursor ()
  "Set cursor type bar(ibeam)."
  (if (is-iterm)
      (if (is-tmux)
          (send-string-to-terminal tmux-bar-cursor-string)
        (send-string-to-terminal bar-cursor-string)))

  (if (is-gnome-terminal)
      (with-temp-buffer
        (shell-command gnome-terminal-bar-cursor-string t))))

(defun set-hbar-cursor ()
  "Set cursor type hbar(underline)."
  (if (is-iterm)
      (if (is-tmux)
          (send-string-to-terminal tmux-hbar-cursor-string)
        (send-string-to-terminal hbar-cursor-string)))

  (if (is-gnome-terminal)
      (with-temp-buffer
        (shell-command gnome-terminal-hbar-cursor-string t))))

(defun set-box-cursor ()
  "Set cursor type box(block)."
  (if (is-iterm)
      (if (is-tmux)
          (send-string-to-terminal tmux-box-cursor-string)
        (send-string-to-terminal box-cursor-string)))

  (if (is-gnome-terminal)
      (with-temp-buffer
        (shell-command gnome-terminal-box-cursor-string t))))

(require 'evil)
(defun set-evil-cursor ()
  "Set cursor type for Evil."
  (if (evil-emacs-state-p)
      (progn
        (cond ((eq evil-emacs-state-cursor 'hbar)
               (set-hbar-cursor))
              ((eq evil-emacs-state-cursor 'box)
               (set-box-cursor))
              ((eq evil-emacs-state-cursor 'bar)
               (set-bar-cursor)))))
  (if (evil-insert-state-p)
      (progn
        (cond ((eq evil-insert-state-cursor 'hbar)
               (set-hbar-cursor))
              ((eq evil-insert-state-cursor 'box)
               (set-box-cursor))
              ((eq evil-insert-state-cursor 'bar)
               (set-bar-cursor)))))
  (if (evil-normal-state-p)
      (progn
        (cond ((eq evil-visual-state-cursor 'hbar)
               (set-hbar-cursor))
              ((eq evil-visual-state-cursor 'box)
               (set-box-cursor))
              ((eq evil-visual-state-cursor 'bar)
               (set-bar-cursor))))))

(unless (display-graphic-p)
  (add-hook 'evil-normal-state-entry-hook 'set-box-cursor)
  (add-hook 'evil-insert-state-entry-hook 'set-bar-cursor)
  (add-hook 'evil-emacs-state-entry-hook 'set-hbar-cursor)

  (add-hook 'post-command-hook 'set-evil-cursor))

;; (add-hook 'evil-local-mode-hook 'set-evil-cursor)
;; (add-hook 'evil-visual-state-entry-hook 'set-evil-cursor)
;; (add-hook 'evil-motion-state-entry-hook 'set-evil-cursor)

(provide 'evil-terminal-cursor-changer)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; evil-terminal-cursor-changer.el ends here
