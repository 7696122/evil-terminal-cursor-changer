;;; test.el --- ERT tests for evil-terminal-cursor-changer  -*- lexical-binding: t; -*-

(require 'ert)

;; Load the package from current directory
(add-to-list 'load-path (file-name-directory (or load-file-name buffer-file-name)))
(require 'evil-terminal-cursor-changer)

;;; ------------------------------------------------------------------
;;; Terminal detection (via etcc-term-type-override)
;;; ------------------------------------------------------------------

(ert-deftest etcc-detect-dumb ()
  (let ((etcc-term-type-override 'dumb))
    (should (etcc--in-dumb?))))

(ert-deftest etcc-detect-iterm ()
  (let ((etcc-term-type-override 'iterm))
    (should (etcc--in-iterm?))))

(ert-deftest etcc-detect-xterm ()
  (let ((etcc-term-type-override 'xterm))
    (should (etcc--in-xterm?))))

(ert-deftest etcc-detect-gnome ()
  (let ((etcc-term-type-override 'gnome))
    (should (etcc--in-gnome-terminal?))))

(ert-deftest etcc-detect-konsole ()
  (let ((etcc-term-type-override 'konsole))
    (should (etcc--in-konsole?))))

(ert-deftest etcc-detect-apple ()
  (let ((etcc-term-type-override 'apple))
    (should (etcc--in-apple-terminal?))))

(ert-deftest etcc-detect-kitty ()
  (let ((etcc-term-type-override 'kitty))
    (should (etcc--in-kitty?))))

(ert-deftest etcc-no-override-falls-through ()
  "When override is nil, detection relies on env vars only."
  (let ((etcc-term-type-override nil))
    ;; In a batch/test environment with no special env vars, all should be nil.
    (should-not (etcc--in-dumb?))
    (should-not (etcc--in-iterm?))
    (should-not (etcc--in-xterm?))
    (should-not (etcc--in-gnome-terminal?))
    (should-not (etcc--in-konsole?))
    (should-not (etcc--in-apple-terminal?))
    (should-not (etcc--in-kitty?))))

;;; ------------------------------------------------------------------
;;; Escape sequence generation — XTerm/iTerm/Kitty/Apple/Dumb
;;; ------------------------------------------------------------------

(ert-deftest etcc-xterm-box-blink ()
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink t)
        (blink-cursor-mode t))
    (should (equal (etcc--make-xterm-cursor-shape-seq 'box) "\e[1 q"))))

(ert-deftest etcc-xterm-box-steady ()
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink t)
        (blink-cursor-mode nil))
    (should (equal (etcc--make-xterm-cursor-shape-seq 'box) "\e[2 q"))))

(ert-deftest etcc-xterm-bar-blink ()
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink t)
        (blink-cursor-mode t))
    (should (equal (etcc--make-xterm-cursor-shape-seq 'bar) "\e[5 q"))))

(ert-deftest etcc-xterm-bar-steady ()
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink t)
        (blink-cursor-mode nil))
    (should (equal (etcc--make-xterm-cursor-shape-seq 'bar) "\e[6 q"))))

(ert-deftest etcc-xterm-hbar-blink ()
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink t)
        (blink-cursor-mode t))
    (should (equal (etcc--make-xterm-cursor-shape-seq 'hbar) "\e[3 q"))))

(ert-deftest etcc-xterm-hbar-steady ()
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink t)
        (blink-cursor-mode nil))
    (should (equal (etcc--make-xterm-cursor-shape-seq 'hbar) "\e[4 q"))))

(ert-deftest etcc-xterm-blink-disabled-always-steady ()
  "When etcc-use-blink is nil, always use steady sequences."
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink nil)
        (blink-cursor-mode t))
    (should (equal (etcc--make-xterm-cursor-shape-seq 'box) "\e[2 q"))
    (should (equal (etcc--make-xterm-cursor-shape-seq 'bar) "\e[6 q"))
    (should (equal (etcc--make-xterm-cursor-shape-seq 'hbar) "\e[4 q"))))

(ert-deftest etcc-xterm-invalid-shape-fallback-box ()
  "Invalid shape should fall back to box."
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink nil))
    (should (equal (etcc--make-xterm-cursor-shape-seq 'invalid) "\e[2 q"))
    (should (equal (etcc--make-xterm-cursor-shape-seq nil) "\e[2 q"))))

;;; ------------------------------------------------------------------
;;; Escape sequence generation — Konsole
;;; ------------------------------------------------------------------

(ert-deftest etcc-konsole-box ()
  (let ((etcc-term-type-override 'konsole))
    (should (equal (etcc--make-konsole-cursor-shape-seq 'box) "\e]50;CursorShape=0\x7"))))

(ert-deftest etcc-konsole-bar ()
  (let ((etcc-term-type-override 'konsole))
    (should (equal (etcc--make-konsole-cursor-shape-seq 'bar) "\e]50;CursorShape=1\x7"))))

(ert-deftest etcc-konsole-hbar ()
  (let ((etcc-term-type-override 'konsole))
    (should (equal (etcc--make-konsole-cursor-shape-seq 'hbar) "\e]50;CursorShape=2\x7"))))

(ert-deftest etcc-konsole-invalid-fallback-box ()
  (let ((etcc-term-type-override 'konsole))
    (should (equal (etcc--make-konsole-cursor-shape-seq 'invalid) "\e]50;CursorShape=0\x7"))))

;;; ------------------------------------------------------------------
;;; Escape sequence generation — dispatch (etcc--make-cursor-shape-seq)
;;; ------------------------------------------------------------------

(ert-deftest etcc-dispatch-xterm ()
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink nil))
    (should (equal (etcc--make-cursor-shape-seq 'bar) "\e[6 q"))))

(ert-deftest etcc-dispatch-iterm ()
  (let ((etcc-term-type-override 'iterm)
        (etcc-use-blink nil))
    (should (equal (etcc--make-cursor-shape-seq 'bar) "\e[6 q"))))

(ert-deftest etcc-dispatch-kitty ()
  (let ((etcc-term-type-override 'kitty)
        (etcc-use-blink nil))
    (should (equal (etcc--make-cursor-shape-seq 'bar) "\e[6 q"))))

(ert-deftest etcc-dispatch-apple ()
  (let ((etcc-term-type-override 'apple)
        (etcc-use-blink nil))
    (should (equal (etcc--make-cursor-shape-seq 'bar) "\e[6 q"))))

(ert-deftest etcc-dispatch-konsole ()
  (let ((etcc-term-type-override 'konsole))
    (should (equal (etcc--make-cursor-shape-seq 'bar) "\e]50;CursorShape=1\x7"))))

(ert-deftest etcc-dispatch-dumb ()
  (let ((etcc-term-type-override 'dumb)
        (etcc-use-blink nil))
    (should (equal (etcc--make-cursor-shape-seq 'bar) "\e[6 q"))))

(ert-deftest etcc-dispatch-unknown-returns-nil ()
  "When no terminal is detected and no override, returns nil."
  (let ((etcc-term-type-override nil))
    (should (equal (etcc--make-cursor-shape-seq 'box) nil))))

;;; ------------------------------------------------------------------
;;; Cursor color sequences
;;; ------------------------------------------------------------------

(ert-deftest etcc-color-seq-xterm ()
  (let ((etcc-term-type-override 'xterm))
    (should (string-prefix-p "\e]12;" (etcc--make-cursor-color-seq "red")))
    (should (string-suffix-p "\a" (etcc--make-cursor-color-seq "red")))))

(ert-deftest etcc-color-seq-iterm ()
  (let ((etcc-term-type-override 'iterm))
    (should (string-prefix-p "\e]Pl" (etcc--make-cursor-color-seq "red")))
    (should (string-suffix-p "\e\\" (etcc--make-cursor-color-seq "red")))))

(ert-deftest etcc-color-seq-invalid-returns-nil ()
  "Invalid color should not produce a sequence."
  (should (equal (etcc--make-cursor-color-seq "not-a-color") nil)))

;;; ------------------------------------------------------------------
;;; Public API — activate / deactivate
;;; ------------------------------------------------------------------

(ert-deftest etcc-activate-adds-hooks ()
  (let ((etcc-use-blink t))
    (evil-terminal-cursor-changer-activate)
    (unwind-protect
        (progn
          (should (memq 'etcc--set-cursor pre-command-hook))
          (should (memq 'etcc--set-cursor post-command-hook))
          (should (memq 'etcc--set-cursor blink-cursor-mode-hook)))
      (evil-terminal-cursor-changer-deactivate))))

(ert-deftest etcc-deactivate-removes-hooks ()
  (let ((etcc-use-blink t))
    (evil-terminal-cursor-changer-activate)
    (evil-terminal-cursor-changer-deactivate)
    (should-not (memq 'etcc--set-cursor pre-command-hook))
    (should-not (memq 'etcc--set-cursor post-command-hook))
    (should-not (memq 'etcc--set-cursor blink-cursor-mode-hook))))

(ert-deftest etcc-activate-no-blink-skips-blink-hook ()
  (let ((etcc-use-blink nil))
    (evil-terminal-cursor-changer-activate)
    (unwind-protect
        (progn
          (should (memq 'etcc--set-cursor pre-command-hook))
          (should (memq 'etcc--set-cursor post-command-hook))
          (should-not (memq 'etcc--set-cursor blink-cursor-mode-hook)))
      (evil-terminal-cursor-changer-deactivate))))

(ert-deftest etcc-on-is-alias ()
  "etcc-on should behave identically to evil-terminal-cursor-changer-activate."
  (should (equal (indirect-function 'etcc-on)
                 (indirect-function 'evil-terminal-cursor-changer-activate))))

(ert-deftest etcc-off-is-alias ()
  "etcc-off should behave identically to evil-terminal-cursor-changer-deactivate."
  (should (equal (indirect-function 'etcc-off)
                 (indirect-function 'evil-terminal-cursor-changer-deactivate))))

;;; ------------------------------------------------------------------
;;; Standalone usage (without evil)
;;; ------------------------------------------------------------------

(ert-deftest etcc-set-cursor-reads-cursor-type-symbol ()
  "etcc--set-cursor should use `cursor-type' when it's a symbol."
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink nil)
        (cursor-type 'bar)
        (sent nil))
    (cl-letf (((symbol-function 'send-string-to-terminal)
               (lambda (seq) (setq sent seq))))
      (etcc--set-cursor)
      (should (equal sent "\e[6 q")))))

(ert-deftest etcc-set-cursor-reads-cursor-type-list ()
  "etcc--set-cursor should use (car cursor-type) when it's a list."
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink nil)
        (cursor-type '(bar . 2))
        (sent nil))
    (cl-letf (((symbol-function 'send-string-to-terminal)
               (lambda (seq) (setq sent seq))))
      (etcc--set-cursor)
      (should (equal sent "\e[6 q")))))

;;; test.el ends here
