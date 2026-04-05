;;; evil-terminal-cursor-changer.el --- Change cursor shape and color in terminal  -*- lexical-binding: t; coding: utf-8; -*-
;;
;; Filename: evil-terminal-cursor-changer.el
;; Description: Change cursor shape and color in terminal Emacs.
;; Author: 7696122
;; Maintainer: 7696122
;; Created: Sat Nov  2 12:17:13 2013 (+0900)
;; Version: 0.0.5
;; Package-Requires: ()
;; URL: https://github.com/7696122/evil-terminal-cursor-changer
;; Keywords: terminal, cursor, evil
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
;;     (etcc-on))
;;
;; With evil-mode, it works out of the box since evil sets `cursor-type'
;; per state.  Without evil, just set `cursor-type' directly:
;;
;;   (setq cursor-type 'bar)   ; ⎸
;;   (setq cursor-type 'box)   ; █
;;   (setq cursor-type 'hbar)  ; _
;;
;; Supported terminals: xterm, iTerm2, Kitty, Konsole, Apple Terminal,
;; dumb (mintty, etc.), and anything supporting DECSCUSR sequences.
;;
;;; Code:

(require 'color)

;; ---- Customize -------------------------------------------------------

(defgroup evil-terminal-cursor-changer nil
  "Change cursor shape and color in terminal Emacs."
  :group 'cursor
  :prefix "etcc-")

(defcustom etcc-use-color nil
  "Whether to change cursor color."
  :type 'boolean
  :group 'evil-terminal-cursor-changer)

(defcustom etcc-use-blink t
  "Whether to use blinking cursor sequences."
  :type 'boolean
  :group 'evil-terminal-cursor-changer)

(defcustom etcc-term-type-override nil
  "Override automatic terminal detection.

Set this if your terminal is not correctly detected but you know
which escape sequences it supports."
  :type '(choice (const :tag "Autodetect" nil)
                 (const :tag "Dumb" dumb)
                 (const :tag "Xterm" xterm)
                 (const :tag "iTerm" iterm)
                 (const :tag "Konsole" konsole)
                 (const :tag "Apple Terminal" apple)
                 (const :tag "Kitty" kitty))
  :group 'evil-terminal-cursor-changer)

;; ---- Terminal detection ----------------------------------------------

(defvar etcc--term-detectors
  `((xterm   . ,(lambda () (getenv "XTERM_VERSION")))
    (iterm   . ,(lambda () (string= (getenv "TERM_PROGRAM") "iTerm.app")))
    (kitty   . ,(lambda () (getenv "KITTY_PID")))
    (konsole . ,(lambda () (getenv "KONSOLE_PROFILE_NAME")))
    (apple   . ,(lambda () (string= (getenv "TERM_PROGRAM") "Apple_Terminal")))
    (gnome   . ,(lambda () (let ((ct (getenv "COLORTERM")))
                             (and ct (string-match-p "gnome-terminal\\|kgx\\|terminator" ct)))))
    (dumb    . ,(lambda () (string= (getenv "TERM") "dumb"))))
  "Alist of (TYPE . DETECT-FN) for terminal detection.")

(defun etcc--detect-terminal ()
  "Return detected terminal type as a symbol, or nil."
  (or etcc-term-type-override
      (cl-loop for (type . detect) in etcc--term-detectors
               when (funcall detect) return type)))

;; ---- Escape sequences: shape -----------------------------------------

(defconst etcc--decscusr-codes
  '((box  . ((nil . "2") (t . "1")))
    (bar  . ((nil . "6") (t . "5")))
    (hbar . ((nil . "4") (t . "3"))))
  "DECSCUSR shape codes: ((BLINK . CODE) ...).")

(defun etcc--decscusr-seq (shape)
  "Return DECSCUSR escape sequence for SHAPE."
  (let* ((entry (or (assq shape etcc--decscusr-codes)
                    (assq 'box etcc--decscusr-codes)))
         (codes (cdr entry))
         (code  (cdr (assq (and etcc-use-blink blink-cursor-mode) codes))))
    (concat "\e[" code " q")))

(defconst etcc--konsole-codes
  '((box . "0") (bar . "1") (hbar . "2"))
  "Konsole cursor shape codes.")

(defun etcc--konsole-seq (shape)
  "Return Konsole escape sequence for SHAPE."
  (let ((code (cdr (or (assq shape etcc--konsole-codes)
                       (assq 'box etcc--konsole-codes)))))
    (concat "\e]50;CursorShape=" code "\x7")))

(defun etcc--make-cursor-shape-seq (shape)
  "Return the escape sequence for SHAPE on the current terminal."
  (pcase (etcc--detect-terminal)
    ('konsole (etcc--konsole-seq shape))
    ('nil     nil)
    (_        (etcc--decscusr-seq shape))))

;; ---- Escape sequences: color -----------------------------------------

(defun etcc--color-name-to-hex (color)
  "Convert COLOR name to hex string, or nil if invalid."
  (let ((rgb (color-name-to-rgb color)))
    (when rgb
      (apply #'color-rgb-to-hex rgb))))

(defun etcc--make-cursor-color-seq (color)
  "Return escape sequence to set cursor COLOR."
  (let ((hex (etcc--color-name-to-hex color)))
    (when hex
      (if (eq (etcc--detect-terminal) 'iterm)
          (concat "\e]Pl"
                  (if (string-prefix-p "#" hex) (substring hex 1) hex)
                  "\e\\")
        (concat "\e]12;" hex "\a")))))

;; ---- Apply to terminal -----------------------------------------------

(defun etcc--apply-to-terminal (seq)
  "Send escape sequence SEQ to the terminal."
  (when (and seq (stringp seq) (not (display-graphic-p)))
    (send-string-to-terminal seq)))

;; ---- Main logic ------------------------------------------------------

(defun etcc--set-cursor ()
  "Set cursor shape based on `cursor-type'."
  (unless (display-graphic-p)
    (let ((shape (if (listp cursor-type) (car cursor-type) cursor-type)))
      (etcc--apply-to-terminal (etcc--make-cursor-shape-seq shape)))))

;; ---- Public API ------------------------------------------------------

;;;###autoload
(defun evil-terminal-cursor-changer-activate ()
  "Enable terminal cursor changer."
  (interactive)
  (when etcc-use-blink
    (add-hook 'blink-cursor-mode-hook #'etcc--set-cursor))
  (add-hook 'pre-command-hook  #'etcc--set-cursor)
  (add-hook 'post-command-hook #'etcc--set-cursor))

;;;###autoload
(defalias 'etcc-on #'evil-terminal-cursor-changer-activate)

;;;###autoload
(defun evil-terminal-cursor-changer-deactivate ()
  "Disable terminal cursor changer."
  (interactive)
  (remove-hook 'blink-cursor-mode-hook #'etcc--set-cursor)
  (remove-hook 'pre-command-hook  #'etcc--set-cursor)
  (remove-hook 'post-command-hook #'etcc--set-cursor))

;;;###autoload
(defalias 'etcc-off #'evil-terminal-cursor-changer-deactivate)

(provide 'evil-terminal-cursor-changer)
;;; evil-terminal-cursor-changer.el ends here
