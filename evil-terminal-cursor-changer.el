;;; evil-terminal-cursor-changer.el --- Change cursor shape and color in terminal  -*- lexical-binding: t; coding: utf-8; -*-
;;
;; Filename: evil-terminal-cursor-changer.el
;; Description: Change cursor shape and color in terminal Emacs.
;; Author: 7696122
;; Maintainer: 7696122
;; Created: Sat Nov  2 12:17:13 2013 (+0900)
;; Version: 0.0.4
;; Package-Version: 20150819.907
;; Package-Requires: ()
;; Last-Updated: Sat May 14 11:56:23 2022 (+0900)
;;           By: 7696122
;;     Update #: 393
;; URL: https://github.com/7696122/evil-terminal-cursor-changer
;; Doc URL: https://github.com/7696122/evil-terminal-cursor-changer/blob/master/README.md
;; Keywords: terminal, cursor, evil
;; Compatibility: GNU Emacs: 24.x
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:

;; [![MELPA](http://melpa.org/packages/evil-terminal-cursor-changer-badge.svg)](http://melpa.org/#/evil-terminal-cursor-changer)

;; ## Introduce ##
;;
;; evil-terminal-cursor-changer changes cursor shape and color in terminal Emacs.
;; It works with any package that sets `cursor-type' (e.g. evil-mode, meow, etc.)
;; or can be used standalone.
;;
;; When running in terminal, it's especially helpful to recognize the current
;; editing state.
;;
;; ## Install ##
;;
;; 1. Config melpa: http://melpa.org/#/getting-started
;;
;; 2. M-x package-install RET evil-terminal-cursor-changer RET
;;
;; 3. Add code to your emacs config file (e.g. ~/.emacs):
;;
;;      (unless (display-graphic-p)
;;              (require 'evil-terminal-cursor-changer)
;;              (evil-terminal-cursor-changer-activate) ; or (etcc-on)
;;              )
;;
;; ## With evil-mode ##
;;
;; evil-mode sets `cursor-type' automatically per state, so etcc works out of
;; the box. You can customize the shapes via evil's variables:
;;
;;      (setq evil-motion-state-cursor 'box)  ; █
;;      (setq evil-visual-state-cursor 'box)  ; █
;;      (setq evil-normal-state-cursor 'box)  ; █
;;      (setq evil-insert-state-cursor 'bar)  ; ⎸
;;      (setq evil-emacs-state-cursor  'hbar) ; _
;;
;; ## Without evil-mode ##
;;
;; Set `cursor-type' directly and etcc will apply it in the terminal:
;;
;;      (setq cursor-type 'bar)   ; ⎸ insert-style
;;      (setq cursor-type 'box)   ; █ normal-style
;;      (setq cursor-type 'hbar)  ; _ underline-style
;;
;; Now, works in XTerm, Gnome Terminal, iTerm2, Konsole, dumb (e.g. mintty),
;; Kitty, and Apple Terminal.
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

(require 'color)

(defgroup evil-terminal-cursor-changer nil
  "Cursor changer for terminal Emacs."
  :group 'cursor
  :prefix "etcc-")

(defcustom etcc-use-color nil
  "Whether to cursor color."
  :type 'boolean
  :group 'evil-terminal-cursor-changer)

(defcustom etcc-use-blink t
  "Whether to cursor blink."
  :type 'boolean
  :group 'evil-terminal-cursor-changer)

(defcustom etcc-term-type-override nil
  "The type of terminal sequence to send.

Set this if your terminal is not correctly detected."
  :type `(choice (const :tag "(Autodetect)" ,nil)
                 (const :tag "Dumb" dumb)
                 (const :tag "Xterm" xterm)
                 (const :tag "iTerm" iterm)
                 (const :tag "Gnome Terminal" gnome)
                 (const :tag "Konsole" konsole)
                 (const :tag "Apple Terminal" apple)
		 (const :tag "Kitty" kitty))
  :group 'evil-terminal-cursor-changer)

(defun etcc--in-dumb? ()
  "Running in dumb."
  (or (eq etcc-term-type-override 'dumb)
      (string= (getenv "TERM") "dumb")))

(defun etcc--in-iterm? ()
  "Running in iTerm."
  (or (eq etcc-term-type-override 'iterm)
      (string= (getenv "TERM_PROGRAM") "iTerm.app")))

(defun etcc--in-xterm? ()
  "Runing in xterm."
  (or (eq etcc-term-type-override 'xterm)
      (getenv "XTERM_VERSION")))

(defun etcc--in-gnome-terminal? ()
  "Running in gnome-terminal."
  (or (eq etcc-term-type-override 'gnome)
      (string= (getenv "COLORTERM") "gnome-terminal")))

(defun etcc--in-konsole? ()
  "Running in konsole."
  (or (eq etcc-term-type-override 'konsole)
      (getenv "KONSOLE_PROFILE_NAME")))

(defun etcc--in-apple-terminal? ()
  "Running in Apple Terminal."
  (or (eq etcc-term-type-override 'apple)
      (string= (getenv "TERM_PROGRAM") "Apple_Terminal")))

(defun etcc--in-kitty? ()
  "Running in Kitty."
  (or (eq etcc-term-type-override 'kitty)
      (getenv "KITTY_PID")))

(defun etcc--get-current-gnome-profile-name ()
  "Return Current profile name of Gnome Terminal."
  ;; https://github.com/helino/current-gnome-terminal-profile/blob/master/current-gnome-terminal-profile.sh
  (if (etcc--in-gnome-terminal?)
      (let ((cmd "#!/bin/sh
FNAME=$HOME/.current_gnome_profile
gnome-terminal --save-config=$FNAME
ENTRY=`grep ProfileID < $FNAME`
rm $FNAME
TERM_PROFILE=${ENTRY#*=}
echo -n $TERM_PROFILE"))
        (shell-command-to-string cmd))
    "Default"))

(defun etcc--color-name-to-hex (color)
  "Convert color name to hex value."
  (let ((rgb (color-name-to-rgb color)))
    (when rgb
      (apply 'color-rgb-to-hex rgb))))

(defun etcc--make-konsole-cursor-shape-seq (shape)
  "Make escape sequence for konsole."
  (let ((prefix  "\e]50;CursorShape=")
        (suffix  "\x7")
        (box     "0")
        (bar     "1")
        (hbar    "2")
        (seq     nil))
    (unless (member shape '(box bar hbar))
      (setq shape 'box))
    (cond ((eq shape 'box)
           (setq seq (concat prefix box suffix)))
          ((eq shape 'bar)
           (setq seq (concat prefix bar suffix)))
          ((eq shape 'hbar)
           (setq seq (concat prefix hbar suffix))))
    seq))

(defun etcc--make-gnome-terminal-cursor-shape-seq (shape)
  "Make escape sequence for gnome terminal."
  (let* ((profile (etcc--get-current-gnome-profile-name))
         (prefix  (format "gconftool-2 --type string --set /apps/gnome-terminal/profiles/%s/cursor_shape "
                          profile))
         (box     "block")
         (bar     "ibeam")
         (hbar    "underline"))
    (unless (member shape '(box bar hbar))
      (setq shape 'box))
    (cond ((eq shape 'box)
           (concat prefix box))
          ((eq shape 'bar)
           (concat prefix bar))
          ((eq shape 'hbar) hbar))))

(defun etcc--make-xterm-cursor-shape-seq (shape)
  "Make escape sequence for XTerm."
  (let ((prefix      "\e[")
        (suffix      " q")
        (box-blink   "1")
        (box         "2")
        (hbar-blink  "3")
        (hbar        "4")
        (bar-blink   "5")
        (bar         "6"))
    (unless (member shape '(box bar hbar))
      (setq shape 'box))
    (cond ((eq shape 'box)
           (setq seq (concat prefix (if (and etcc-use-blink blink-cursor-mode) box-blink box) suffix)))
          ((eq shape 'bar)
           (setq seq (concat prefix (if (and etcc-use-blink blink-cursor-mode) bar-blink bar) suffix)))
          ((eq shape 'hbar)
           (setq seq (concat prefix (if (and etcc-use-blink blink-cursor-mode) hbar-blink hbar) suffix))))
    seq))

(defun etcc--make-cursor-shape-seq (shape)
  "Make escape sequence for cursor shape."
  (cond ((or (etcc--in-xterm?)
             (etcc--in-apple-terminal?)
             (etcc--in-iterm?)
	     (etcc--in-kitty?))
         (etcc--make-xterm-cursor-shape-seq shape))
        ((etcc--in-konsole?)
         (etcc--make-konsole-cursor-shape-seq shape))
        ((etcc--in-dumb?)
         (etcc--make-xterm-cursor-shape-seq shape))))

(defun etcc--make-cursor-color-seq (color)
  "Make escape sequence for cursor color."
  (let ((hex-color (etcc--color-name-to-hex color)))
    (if hex-color
        ;; https://www.iterm2.com/documentation-escape-codes.html
        (let ((prefix (if (etcc--in-iterm?)
                          "\e]Pl"
                        "\e]12;"))
              (suffix (if (etcc--in-iterm?)
                          "\e\\"
                        "\a")))
          (concat prefix
                  ;; https://www.iterm2.com/documentation-escape-codes.html
                  ;; Remove #, rr, gg, bb are 2-digit hex value for iTerm.
                  (if (and (etcc--in-iterm?)
                           (string-prefix-p "#" hex-color))
                      (substring hex-color 1)
                    hex-color)
                  suffix)))))

(defun etcc--apply-to-terminal (seq)
  "Send to escape sequence to terminal."
  (when (and seq
             (stringp seq)
             (not (display-graphic-p)))
    (send-string-to-terminal seq)))

(defun etcc--set-cursor-color (color)
  "Set cursor color."
  (etcc--apply-to-terminal (etcc--make-cursor-color-seq color)))

(defun etcc--set-cursor ()
  "Set cursor shape based on `cursor-type'."
  (unless (display-graphic-p)
    (if (symbolp cursor-type)
        (etcc--apply-to-terminal (etcc--make-cursor-shape-seq cursor-type))
      (if (listp cursor-type)
          (etcc--apply-to-terminal (etcc--make-cursor-shape-seq (car cursor-type)))))))

;; Hook references updated to use etcc--set-cursor.

;;;###autoload
(defun evil-terminal-cursor-changer-activate ()
  "Enable terminal cursor changer."
  (interactive)
  (if etcc-use-blink (add-hook 'blink-cursor-mode-hook #'etcc--set-cursor))
  (add-hook 'pre-command-hook 'etcc--set-cursor)
  (add-hook 'post-command-hook 'etcc--set-cursor))

;;;###autoload
(defalias 'etcc-on 'evil-terminal-cursor-changer-activate)

;;;###autoload
(defun evil-terminal-cursor-changer-deactivate ()
  "Disable terminal cursor changer."
  (interactive)
  (if etcc-use-blink (remove-hook 'blink-cursor-mode-hook 'etcc--set-cursor))
  (remove-hook 'pre-command-hook 'etcc--set-cursor)
  (remove-hook 'post-command-hook 'etcc--set-cursor))

;;;###autoload
(defalias 'etcc-off 'evil-terminal-cursor-changer-deactivate)

(provide 'evil-terminal-cursor-changer)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; evil-terminal-cursor-changer.el ends here
