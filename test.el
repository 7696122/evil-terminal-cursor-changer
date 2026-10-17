;;; test.el --- ERT tests for evil-terminal-cursor-changer  -*- lexical-binding: t; -*-

(require 'ert)
(add-to-list 'load-path (file-name-directory (or load-file-name buffer-file-name)))
(require 'evil-terminal-cursor-changer)

(defmacro evil-terminal-cursor-changer-test--with-visible-input (&rest body)
  "Run BODY with a visible input buffer and a separate callback buffer."
  (declare (indent 0))
  `(save-window-excursion
     (let ((visible (generate-new-buffer " *cursor-changer-input*"))
           (background (generate-new-buffer " *cursor-changer-callback*"))
           (evil-terminal-cursor-changer-term-type-override 'xterm)
           (evil-terminal-cursor-changer-use-blink nil)
           (evil-terminal-cursor-changer-use-color nil)
           (blink-cursor-mode nil)
           (pre-command-hook nil)
           (post-command-hook nil)
           (blink-cursor-mode-hook nil)
           (pre-redisplay-functions nil)
           (detection-cache
            (terminal-parameter nil 'evil-terminal-cursor-changer--detection-cache))
           (color-cache
            (frame-parameter nil 'evil-terminal-cursor-changer--color-cache))
           sent)
       (unwind-protect
           (progn
             (set-terminal-parameter nil 'evil-terminal-cursor-changer--detection-cache nil)
             (set-frame-parameter nil 'evil-terminal-cursor-changer--color-cache nil)
             (switch-to-buffer visible)
             (setq-local cursor-type 'bar)
             (with-current-buffer background
               (setq-local cursor-type 'box))
             (cl-letf (((symbol-function 'send-string-to-terminal)
                        (lambda (seq &optional _terminal) (push seq sent))))
               ,@body))
         (evil-terminal-cursor-changer-deactivate)
         (set-terminal-parameter nil 'evil-terminal-cursor-changer--detection-cache
                                 detection-cache)
         (set-frame-parameter nil 'evil-terminal-cursor-changer--color-cache color-cache)
         (kill-buffer visible)
         (kill-buffer background)))))

;;; ------------------------------------------------------------------
;;; Terminal detection
;;; ------------------------------------------------------------------

(ert-deftest evil-terminal-cursor-changer-detect-terminal-from-environment ()
  "Detect each supported environment without inheriting the host terminal."
  (dolist (case '((xterm "XTERM_VERSION=XTerm(390)")
                  (iterm "TERM_PROGRAM=iTerm.app")
                  (kitty "KITTY_PID=123")
                  (konsole "KONSOLE_PROFILE_NAME=Default")
                  (apple "TERM_PROGRAM=Apple_Terminal")
                  (alacritty "TERM=alacritty-direct")
                  (alacritty "ALACRITTY_WINDOW_ID=123")
                  (wezterm "TERM_PROGRAM=WezTerm")
                  (wterm "WT_SESSION=session")
                  (foot "TERM=foot-extra")
                  (ghostty "TERM_PROGRAM=ghostty")
                  (ghostty "GHOSTTY_BIN_DIR=/opt/ghostty")
                  (hyper "TERM_PROGRAM=Hyper")
                  (rio "TERM_PROGRAM=Rio")
                  (tabby "TERM_PROGRAM=Tabby")
                  (gnome "COLORTERM=gnome-terminal")
                  (gnome "COLORTERM=kgx")
                  (gnome "COLORTERM=terminator")
                  (dumb "TERM=dumb")
                  (nil)
                  (nil "TERM=unknown")))
    (let ((evil-terminal-cursor-changer-term-type-override nil)
          (process-environment (cdr case)))
      (ert-info ((format "Environment: %S" process-environment))
        (should (eq (evil-terminal-cursor-changer--detect-terminal) (car case)))))))

(ert-deftest evil-terminal-cursor-changer-detect-terminal-precedence ()
  "Explicit overrides win; otherwise retain detector order for mixed hints."
  (let ((process-environment '("XTERM_VERSION=390" "TERM_PROGRAM=ghostty"))
        (evil-terminal-cursor-changer-term-type-override 'foot))
    (should (eq (evil-terminal-cursor-changer--detect-terminal) 'foot))
    (setq evil-terminal-cursor-changer-term-type-override nil)
    (should (eq (evil-terminal-cursor-changer--detect-terminal) 'xterm))))

(ert-deftest evil-terminal-cursor-changer-empty-environment-hints-do-not-mask-terminal ()
  "Empty environment hints must not take precedence over a valid TERM."
  (dolist (var '("XTERM_VERSION" "KITTY_PID" "KONSOLE_PROFILE_NAME"
                 "ALACRITTY_WINDOW_ID" "WT_SESSION" "GHOSTTY_BIN_DIR"))
    (let ((process-environment (list (concat var "=") "TERM=dumb"))
          (evil-terminal-cursor-changer-term-type-override nil))
      (ert-info ((format "Empty hint: %s" var))
        (should (eq (evil-terminal-cursor-changer--detect-terminal) 'dumb))))))

(ert-deftest evil-terminal-cursor-changer-detection-follows-environment-changes ()
  "Warm detection must follow in-place environment edits and override changes."
  (let ((process-environment (list (copy-sequence "TERM_PROGRAM=ghostty")
                                   "TERM=unknown"))
        (evil-terminal-cursor-changer-term-type-override nil))
    (should (eq (evil-terminal-cursor-changer--detect-terminal) 'ghostty))
    (store-substring (car process-environment) 13 "WezTerm")
    (should (eq (evil-terminal-cursor-changer--detect-terminal) 'wezterm))
    (setcar process-environment "TERM_PROGRAM=ghostty")
    (should (eq (evil-terminal-cursor-changer--detect-terminal) 'ghostty))
    (setq evil-terminal-cursor-changer-term-type-override 'foot)
    (should (eq (evil-terminal-cursor-changer--detect-terminal) 'foot))
    (setenv "TERM_PROGRAM" nil)
    (setq evil-terminal-cursor-changer-term-type-override nil)
    (should-not (evil-terminal-cursor-changer--detect-terminal))
    (setenv "KITTY_PID" "123")
    (should (eq (evil-terminal-cursor-changer--detect-terminal) 'kitty))))

(ert-deftest evil-terminal-cursor-changer-detection-follows-buffer-environments ()
  "Buffers sharing a terminal may have different process environments."
  (evil-terminal-cursor-changer-test--with-visible-input
    (let ((evil-terminal-cursor-changer-term-type-override nil))
      (setq-local process-environment '("TERM_PROGRAM=ghostty"))
      (should (eq (evil-terminal-cursor-changer--detect-terminal) 'ghostty))
      (with-current-buffer background
        (setq-local process-environment '("TERM_PROGRAM=WezTerm"))
        (should (eq (evil-terminal-cursor-changer--detect-terminal) 'wezterm)))
      (should (eq (evil-terminal-cursor-changer--detect-terminal) 'ghostty)))))

;;; ------------------------------------------------------------------
;;; DECSCUSR sequences
;;; ------------------------------------------------------------------

(ert-deftest evil-terminal-cursor-changer-decscusr-box-blink ()
  (let ((evil-terminal-cursor-changer-term-type-override 'xterm) (evil-terminal-cursor-changer-use-blink t) (blink-cursor-mode t))
    (should (equal (evil-terminal-cursor-changer--make-cursor-shape-seq 'box) "\e[1 q"))))

(ert-deftest evil-terminal-cursor-changer-decscusr-box-steady ()
  (let ((evil-terminal-cursor-changer-term-type-override 'xterm) (evil-terminal-cursor-changer-use-blink t) (blink-cursor-mode nil))
    (should (equal (evil-terminal-cursor-changer--make-cursor-shape-seq 'box) "\e[2 q"))))

(ert-deftest evil-terminal-cursor-changer-decscusr-bar-blink ()
  (let ((evil-terminal-cursor-changer-term-type-override 'xterm) (evil-terminal-cursor-changer-use-blink t) (blink-cursor-mode t))
    (should (equal (evil-terminal-cursor-changer--make-cursor-shape-seq 'bar) "\e[5 q"))))

(ert-deftest evil-terminal-cursor-changer-decscusr-bar-steady ()
  (let ((evil-terminal-cursor-changer-term-type-override 'xterm) (evil-terminal-cursor-changer-use-blink t) (blink-cursor-mode nil))
    (should (equal (evil-terminal-cursor-changer--make-cursor-shape-seq 'bar) "\e[6 q"))))

(ert-deftest evil-terminal-cursor-changer-decscusr-hbar-blink ()
  (let ((evil-terminal-cursor-changer-term-type-override 'xterm) (evil-terminal-cursor-changer-use-blink t) (blink-cursor-mode t))
    (should (equal (evil-terminal-cursor-changer--make-cursor-shape-seq 'hbar) "\e[3 q"))))

(ert-deftest evil-terminal-cursor-changer-decscusr-hbar-steady ()
  (let ((evil-terminal-cursor-changer-term-type-override 'xterm) (evil-terminal-cursor-changer-use-blink t) (blink-cursor-mode nil))
    (should (equal (evil-terminal-cursor-changer--make-cursor-shape-seq 'hbar) "\e[4 q"))))

(ert-deftest evil-terminal-cursor-changer-decscusr-blink-disabled ()
  "Disabling blink support always selects steady cursor sequences."
  (let ((evil-terminal-cursor-changer-term-type-override 'xterm) (evil-terminal-cursor-changer-use-blink nil) (blink-cursor-mode t))
    (should (equal (evil-terminal-cursor-changer--make-cursor-shape-seq 'box) "\e[2 q"))
    (should (equal (evil-terminal-cursor-changer--make-cursor-shape-seq 'bar) "\e[6 q"))
    (should (equal (evil-terminal-cursor-changer--make-cursor-shape-seq 'hbar) "\e[4 q"))))

(ert-deftest evil-terminal-cursor-changer-decscusr-invalid-fallback-box ()
  "Invalid shape falls back to box."
  (let ((evil-terminal-cursor-changer-term-type-override 'xterm) (evil-terminal-cursor-changer-use-blink nil))
    (should (equal (evil-terminal-cursor-changer--make-cursor-shape-seq 'invalid) "\e[2 q"))))

(ert-deftest evil-terminal-cursor-changer-decscusr-nil-shape-returns-nil ()
  "nil shape (hidden cursor) should return nil, not a fallback."
  (should-not (evil-terminal-cursor-changer--make-cursor-shape-seq nil)))

(ert-deftest evil-terminal-cursor-changer-decscusr-no-terminal-returns-nil ()
  "Undetected terminal returns nil."
  (let ((evil-terminal-cursor-changer-term-type-override nil)
        (evil-terminal-cursor-changer-use-blink nil)
        (process-environment nil))
    (should-not (evil-terminal-cursor-changer--make-cursor-shape-seq 'box))))

;;; ------------------------------------------------------------------
;;; Cursor color (OSC 12, unified for all terminals)
;;; ------------------------------------------------------------------

(ert-deftest evil-terminal-cursor-changer-color-seq ()
  "Named and hexadecimal colors produce the complete OSC 12 payload."
  (dolist (color '("red" "#ff0000"))
    (should (equal (evil-terminal-cursor-changer--make-cursor-color-seq color)
                   "\e]12;#ffff00000000\a"))))

(ert-deftest evil-terminal-cursor-changer-color-invalid-returns-nil ()
  (should-not (evil-terminal-cursor-changer--make-cursor-color-seq "not-a-color")))

(ert-deftest evil-terminal-cursor-changer-color-follows-input-changes ()
  "Color changes, including a mutated color string, must not reuse stale output."
  (let ((color (copy-sequence "#ff0000")))
    (should (equal (evil-terminal-cursor-changer--make-cursor-color-seq color)
                   "\e]12;#ffff00000000\a"))
    (store-substring color 1 "00ff00")
    (should (equal (evil-terminal-cursor-changer--make-cursor-color-seq color)
                   "\e]12;#0000ffff0000\a"))
    (should-not
     (evil-terminal-cursor-changer--make-cursor-color-seq "not-a-color"))
    (should-not (evil-terminal-cursor-changer--make-cursor-color-seq nil))
    (should (equal (evil-terminal-cursor-changer--make-cursor-color-seq "#ff0000")
                   "\e]12;#ffff00000000\a"))))

;;; ------------------------------------------------------------------
;;; Selected-window cursor integration
;;; ------------------------------------------------------------------

(ert-deftest evil-terminal-cursor-changer-set-cursor-shapes ()
  "Read symbol and sized cursor types, preserving fallback and hidden cursors."
  (evil-terminal-cursor-changer-test--with-visible-input
    (dolist (case '((bar "\e[6 q")
                    ((hbar . 2) "\e[4 q")
                    (invalid "\e[2 q")
                    (nil nil)))
      (setq-local cursor-type (car case))
      (setq sent nil)
      (evil-terminal-cursor-changer--set-cursor)
      (should (equal sent (and (cadr case) (list (cadr case))))))))

(ert-deftest evil-terminal-cursor-changer-set-cursor-color-options ()
  "Color output is optional and independent of whether the cursor is hidden."
  (evil-terminal-cursor-changer-test--with-visible-input
    (dolist (case '((bar t "red" ("\e[6 q" "\e]12;#ffff00000000\a"))
                    (nil t "red" ("\e]12;#ffff00000000\a"))
                    (bar nil "red" ("\e[6 q"))
                    (bar t nil ("\e[6 q"))
                    (bar t "not-a-color" ("\e[6 q"))))
      (setq-local cursor-type (nth 0 case))
      (let ((evil-terminal-cursor-changer-use-color (nth 1 case))
            (color (nth 2 case)))
        (setq sent nil)
        (cl-letf (((symbol-function 'frame-parameter)
                   (lambda (_frame param)
                     (when (eq param 'cursor-color) color))))
          (evil-terminal-cursor-changer--set-cursor))
        (should (equal (reverse sent) (nth 3 case)))))))

;;; ------------------------------------------------------------------
;;; Visible-buffer cursor synchronization
;;; ------------------------------------------------------------------

(ert-deftest evil-terminal-cursor-changer-background-command-keeps-visible-input-cursor ()
  "A server callback must not replace the visible input bar with a box."
  (evil-terminal-cursor-changer-test--with-visible-input
    (evil-terminal-cursor-changer-activate)
    (setq sent nil)
    (with-current-buffer background
      (run-hooks 'pre-command-hook 'post-command-hook))
    (should (equal sent '("\e[6 q" "\e[6 q")))
    (should (eq (buffer-local-value 'cursor-type visible) 'bar))
    (should (eq (buffer-local-value 'cursor-type background) 'box))))

(ert-deftest evil-terminal-cursor-changer-background-blink-keeps-visible-input-cursor ()
  "Blink changes in a callback must use the selected window's cursor."
  (evil-terminal-cursor-changer-test--with-visible-input
    (let ((evil-terminal-cursor-changer-use-blink t))
      (evil-terminal-cursor-changer-activate)
      (setq sent nil)
      (with-current-buffer background
        (blink-cursor-mode -1))
      (should (equal sent '("\e[6 q"))))))

(ert-deftest evil-terminal-cursor-changer-disabled-blink-does-not-trigger-output ()
  "Disabling blink support skips blink updates but retains command updates."
  (evil-terminal-cursor-changer-test--with-visible-input
    (evil-terminal-cursor-changer-activate)
    (setq sent nil)
    (blink-cursor-mode -1)
    (should-not sent)
    (run-hooks 'post-command-hook)
    (should (equal sent '("\e[6 q")))))

(ert-deftest evil-terminal-cursor-changer-redisplay-restores-input-cursor-after-background-work ()
  "Repair the terminal cursor after async work without another command."
  (evil-terminal-cursor-changer-test--with-visible-input
    (evil-terminal-cursor-changer-activate)
    (setq sent nil)
    ;; Model a subprocess leaving the physical cursor in block shape.
    (send-string-to-terminal "\e[2 q")
    (with-current-buffer background
      (run-hook-with-args 'pre-redisplay-functions (list (selected-window))))
    (should (equal sent '("\e[6 q" "\e[2 q")))))

(ert-deftest evil-terminal-cursor-changer-redisplay-only-updates-selected-window ()
  "Ignore other windows, then follow selection changes without stale output."
  (evil-terminal-cursor-changer-test--with-visible-input
    (let ((input-window (selected-window))
          (other-window (split-window-right)))
      (set-window-buffer other-window background)
      (evil-terminal-cursor-changer-activate)
      (setq sent nil)
      (run-hook-with-args 'pre-redisplay-functions other-window)
      (should-not sent)
      (run-hook-with-args 'pre-redisplay-functions input-window)
      (should (equal sent '("\e[6 q")))
      (select-window other-window)
      (run-hook-with-args 'pre-redisplay-functions input-window)
      (should (equal sent '("\e[6 q")))
      (run-hook-with-args 'pre-redisplay-functions other-window)
      (should (equal (reverse sent) '("\e[6 q" "\e[2 q"))))))

(ert-deftest evil-terminal-cursor-changer-redisplay-restores-cached-color ()
  "A cached color must still be resent after outside output changes the cursor."
  (evil-terminal-cursor-changer-test--with-visible-input
    (let ((evil-terminal-cursor-changer-use-color t)
          (original-color (frame-parameter nil 'cursor-color)))
      (unwind-protect
          (progn
            (set-frame-parameter nil 'cursor-color "#ff0000")
            (evil-terminal-cursor-changer-activate)
            (setq sent nil)
            (send-string-to-terminal "\e[2 q\e]12;#00000000ffff\a")
            (run-hook-with-args 'pre-redisplay-functions (selected-window))
            (should (equal (reverse sent)
                           '("\e[2 q\e]12;#00000000ffff\a"
                             "\e[6 q" "\e]12;#ffff00000000\a"))))
        (set-frame-parameter nil 'cursor-color original-color)))))

(ert-deftest evil-terminal-cursor-changer-deactivation-stops-redisplay-output ()
  (evil-terminal-cursor-changer-test--with-visible-input
    (let ((evil-terminal-cursor-changer-use-blink t))
      (evil-terminal-cursor-changer-activate)
      (evil-terminal-cursor-changer-deactivate)
      (setq sent nil)
      (with-current-buffer background
        (run-hooks 'pre-command-hook 'post-command-hook 'blink-cursor-mode-hook)
        (run-hook-with-args 'pre-redisplay-functions (list (selected-window))))
      (should-not sent))))

(ert-deftest evil-terminal-cursor-changer-reactivation-registers-redisplay-once ()
  (evil-terminal-cursor-changer-test--with-visible-input
    (evil-terminal-cursor-changer-activate)
    (should (equal sent '("\e[6 q")))
    (evil-terminal-cursor-changer-activate)
    (setq sent nil)
    (run-hook-with-args 'pre-redisplay-functions t)
    (should (equal sent '("\e[6 q")))))

(ert-deftest evil-terminal-cursor-changer-gui-hooks-do-not-send-terminal-output ()
  (evil-terminal-cursor-changer-test--with-visible-input
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t)))
      (evil-terminal-cursor-changer-activate)
      (with-current-buffer background
        (run-hooks 'post-command-hook 'blink-cursor-mode-hook)
        (run-hook-with-args 'pre-redisplay-functions t))
      (should-not sent))))

(ert-deftest evil-terminal-cursor-changer-hidden-visible-cursor-does-not-use-background-box ()
  (evil-terminal-cursor-changer-test--with-visible-input
    (setq-local cursor-type nil)
    (evil-terminal-cursor-changer-activate)
    (with-current-buffer background
      (run-hooks 'post-command-hook)
      (run-hook-with-args 'pre-redisplay-functions t))
    (should-not sent)))

(ert-deftest evil-terminal-cursor-changer-visible-normal-buffer-still-uses-box ()
  (evil-terminal-cursor-changer-test--with-visible-input
    (setq-local cursor-type 'box)
    (evil-terminal-cursor-changer-activate)
    (should (equal sent '("\e[2 q")))))

;;; test.el ends here
