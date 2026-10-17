;;; evil-terminal-cursor-changer.el --- Change cursor shape and color in terminal  -*- lexical-binding: t; coding: utf-8; -*-
;;
;; Filename: evil-terminal-cursor-changer.el
;; Description: Change cursor shape and color in terminal Emacs.
;; Author: 7696122
;; Maintainer: 7696122
;; Created: Sat Nov  2 12:17:13 2013 (+0900)
;; Version: 0.0.5
;; Package-Requires: ((emacs "25.1"))
;; URL: https://github.com/7696122/evil-terminal-cursor-changer
;; Keywords: terminals, faces
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
;;; Commentary:
;;
;; Change cursor shape and color when running Emacs in a terminal.
;; Works with any package that sets `cursor-type' (evil, meow, etc.)
;; or standalone.
;;
;; Usage:
;;
;;   (unless (display-graphic-p)
;;     (require 'evil-terminal-cursor-changer)
;;     (evil-terminal-cursor-changer-activate))
;;
;; With evil-mode, it works out of the box since evil sets `cursor-type'
;; per state.  Without evil, just set `cursor-type' directly:
;;
;;   (setq cursor-type 'bar)   ; ⎸
;;   (setq cursor-type 'box)   ; █
;;   (setq cursor-type 'hbar)  ; _
;;
;; Supported terminals: xterm, iTerm2, Kitty, Konsole, Apple Terminal,
;; Alacritty, WezTerm, Windows Terminal, foot, Ghostty, Hyper, Rio,
;; Tabby, dumb (mintty, etc.), and anything supporting DECSCUSR sequences.
;;
;;; Code:

(require 'color)
(require 'cl-lib)

;; ---- Customize -------------------------------------------------------

(defgroup evil-terminal-cursor-changer nil
  "Change cursor shape and color in terminal Emacs."
  :group 'cursor
  :prefix "evil-terminal-cursor-changer-")

(defcustom evil-terminal-cursor-changer-use-color nil
  "Whether to change cursor color."
  :type 'boolean
  :group 'evil-terminal-cursor-changer)

(defcustom evil-terminal-cursor-changer-use-blink t
  "Whether to use blinking cursor sequences."
  :type 'boolean
  :group 'evil-terminal-cursor-changer)

(defcustom evil-terminal-cursor-changer-term-type-override nil
  "Override automatic terminal detection.

Set this if your terminal is not correctly detected but you know
which escape sequences it supports."
  :type '(choice (const :tag "Autodetect" nil)
                 (const :tag "Dumb" dumb)
                 (const :tag "Xterm" xterm)
                 (const :tag "iTerm" iterm)
                 (const :tag "Konsole" konsole)
                 (const :tag "Apple Terminal" apple)
                 (const :tag "Kitty" kitty)
                 (const :tag "Alacritty" alacritty)
                 (const :tag "WezTerm" wezterm)
                 (const :tag "Windows Terminal" wterm)
                 (const :tag "foot" foot)
                 (const :tag "Ghostty" ghostty)
                 (const :tag "Hyper" hyper)
                 (const :tag "Rio" rio)
                 (const :tag "Tabby" tabby)
                 (const :tag "Gnome Terminal" gnome))
  :group 'evil-terminal-cursor-changer)

;; ---- Terminal detection ----------------------------------------------

(defun evil-terminal-cursor-changer--detect-by-term-program (name)
  "Return non-nil if `TERM_PROGRAM' equals NAME."
  (string= (getenv "TERM_PROGRAM") name))

(defun evil-terminal-cursor-changer--detect-by-env (var)
  "Return non-nil if environment variable VAR is set and non-empty."
  (let ((value (getenv var)))
    (and value (not (equal value "")))))

(defun evil-terminal-cursor-changer--detect-by-term-prefix (prefix)
  "Return non-nil if `TERM' starts with PREFIX."
  (let ((term (getenv "TERM")))
    (and term (string-prefix-p prefix term))))

(defvar evil-terminal-cursor-changer--term-detectors
  `((xterm     . ,(lambda () (evil-terminal-cursor-changer--detect-by-env "XTERM_VERSION")))
    (iterm     . ,(lambda () (evil-terminal-cursor-changer--detect-by-term-program "iTerm.app")))
    (kitty     . ,(lambda () (evil-terminal-cursor-changer--detect-by-env "KITTY_PID")))
    (konsole   . ,(lambda () (evil-terminal-cursor-changer--detect-by-env "KONSOLE_PROFILE_NAME")))
    (apple     . ,(lambda () (evil-terminal-cursor-changer--detect-by-term-program "Apple_Terminal")))
    (alacritty . ,(lambda () (or (evil-terminal-cursor-changer--detect-by-term-prefix "alacritty")
                                 (evil-terminal-cursor-changer--detect-by-env "ALACRITTY_WINDOW_ID"))))
    (wezterm   . ,(lambda () (evil-terminal-cursor-changer--detect-by-term-program "WezTerm")))
    (wterm     . ,(lambda () (evil-terminal-cursor-changer--detect-by-env "WT_SESSION")))
    (foot      . ,(lambda () (evil-terminal-cursor-changer--detect-by-term-prefix "foot")))
    (ghostty   . ,(lambda () (or (evil-terminal-cursor-changer--detect-by-term-program "ghostty")
                                 (evil-terminal-cursor-changer--detect-by-env "GHOSTTY_BIN_DIR"))))
    (hyper     . ,(lambda () (evil-terminal-cursor-changer--detect-by-term-program "Hyper")))
    (rio       . ,(lambda () (evil-terminal-cursor-changer--detect-by-term-program "Rio")))
    (tabby     . ,(lambda () (evil-terminal-cursor-changer--detect-by-term-program "Tabby")))
    (gnome     . ,(lambda () (let ((ct (getenv "COLORTERM")))
                               (and ct (string-match-p "gnome-terminal\\|kgx\\|terminator" ct)))))
    (dumb      . ,(lambda () (string= (getenv "TERM") "dumb"))))
  "Alist of (TYPE . DETECT-FN) for terminal detection.")

(defun evil-terminal-cursor-changer--detect-terminal ()
  "Return the detected terminal type, or nil.
Cache the environment snapshot, detector table, and result on the terminal.
An explicit override always takes precedence over the cached detection."
  (or evil-terminal-cursor-changer-term-type-override
      (let ((cache (terminal-parameter
                    nil 'evil-terminal-cursor-changer--detection-cache)))
        (if (and cache
                 (equal process-environment (aref cache 0))
                 (eq evil-terminal-cursor-changer--term-detectors (aref cache 1)))
            (aref cache 2)
          (let ((type
                 (cl-loop for (type . detect) in evil-terminal-cursor-changer--term-detectors
                          when (funcall detect) return type)))
            (set-terminal-parameter
             nil 'evil-terminal-cursor-changer--detection-cache
             (vector (mapcar #'copy-sequence process-environment)
                     evil-terminal-cursor-changer--term-detectors type))
            type)))))

;; ---- Escape sequences: shape (DECSCUSR) ------------------------------

(defconst evil-terminal-cursor-changer--decscusr-codes
  '((box  . ((nil . "2") (t . "1")))
    (bar  . ((nil . "6") (t . "5")))
    (hbar . ((nil . "4") (t . "3"))))
  "DECSCUSR shape codes: ((BLINK . CODE) ...).")

(defun evil-terminal-cursor-changer--make-cursor-shape-seq (shape)
  "Return DECSCUSR escape sequence for SHAPE on the current terminal.
Returns nil if terminal is undetected or SHAPE is nil (hidden cursor)."
  (when (and shape (evil-terminal-cursor-changer--detect-terminal))
    (let* ((entry (or (assq shape evil-terminal-cursor-changer--decscusr-codes)
                      (assq 'box evil-terminal-cursor-changer--decscusr-codes)))
           (codes (cdr entry))
           (code  (cdr (assq (and evil-terminal-cursor-changer-use-blink blink-cursor-mode) codes))))
      (concat "\e[" code " q"))))

;; ---- Escape sequences: color (OSC 12) --------------------------------

(defun evil-terminal-cursor-changer--make-cursor-color-seq (color)
  "Return OSC 12 escape sequence for COLOR, or nil if absent or invalid.
Cache the last color and its sequence on the selected frame."
  (when color
    (let ((cache (frame-parameter
                  nil 'evil-terminal-cursor-changer--color-cache)))
      (if (and cache (equal color (aref cache 0)))
          (aref cache 1)
        (let* ((rgb (color-name-to-rgb color))
               (seq (when rgb
                      (concat "\e]12;" (apply #'color-rgb-to-hex rgb) "\a"))))
          (set-frame-parameter nil 'evil-terminal-cursor-changer--color-cache
                               (vector (copy-sequence color) seq))
          seq)))))

;; ---- Main logic ------------------------------------------------------

(defun evil-terminal-cursor-changer--set-cursor (&optional window)
  "Set the selected terminal's cursor from its selected window's buffer.
Ignore redisplay calls for a nonselected WINDOW.  Non-window arguments
from older Emacs versions are accepted.  The current buffer may be a
background buffer, so always read the selected window's buffer."
  (unless (display-graphic-p)
    (let ((selected (selected-window)))
      (when (or (not (windowp window)) (eq window selected))
        (with-current-buffer (window-buffer selected)
          (let ((seq (evil-terminal-cursor-changer--make-cursor-shape-seq
                      (if (consp cursor-type) (car cursor-type) cursor-type))))
            (when seq
              (send-string-to-terminal seq)))
          (when evil-terminal-cursor-changer-use-color
            (let ((seq (evil-terminal-cursor-changer--make-cursor-color-seq
                        (frame-parameter nil 'cursor-color))))
              (when seq
                (send-string-to-terminal seq)))))))))

;; ---- Public API ------------------------------------------------------

(defconst evil-terminal-cursor-changer--cursor-hooks
  '(pre-command-hook post-command-hook pre-redisplay-functions)
  "Hooks that synchronize the cursor during commands and redisplay.")

;;;###autoload
(defun evil-terminal-cursor-changer-activate ()
  "Enable terminal cursor changer and refresh the selected display's caches."
  (interactive)
  (set-terminal-parameter nil 'evil-terminal-cursor-changer--detection-cache nil)
  (set-frame-parameter nil 'evil-terminal-cursor-changer--color-cache nil)
  (when evil-terminal-cursor-changer-use-blink
    (add-hook 'blink-cursor-mode-hook #'evil-terminal-cursor-changer--set-cursor))
  (dolist (hook evil-terminal-cursor-changer--cursor-hooks)
    (add-hook hook #'evil-terminal-cursor-changer--set-cursor))
  (evil-terminal-cursor-changer--set-cursor))

;;;###autoload
(defun evil-terminal-cursor-changer-deactivate ()
  "Disable terminal cursor changer."
  (interactive)
  (remove-hook 'blink-cursor-mode-hook #'evil-terminal-cursor-changer--set-cursor)
  (dolist (hook evil-terminal-cursor-changer--cursor-hooks)
    (remove-hook hook #'evil-terminal-cursor-changer--set-cursor)))

(provide 'evil-terminal-cursor-changer)
;;; evil-terminal-cursor-changer.el ends here
