;;; test.el --- ERT tests for evil-terminal-cursor-changer  -*- lexical-binding: t; -*-

(require 'ert)
(add-to-list 'load-path (file-name-directory (or load-file-name buffer-file-name)))
(require 'evil-terminal-cursor-changer)

;;; ------------------------------------------------------------------
;;; Terminal detection via etcc-term-type-override
;;; ------------------------------------------------------------------

(ert-deftest etcc-detect-all-types-via-override ()
  "Each override value should be detected correctly."
  (dolist (type '(xterm iterm kitty konsole apple gnome dumb))
    (let ((etcc-term-type-override type))
      (should (eq (etcc--detect-terminal) type)))))

(ert-deftest etcc-detect-nil-override ()
  "nil override falls through to env var detection."
  (let ((etcc-term-type-override nil))
    ;; In batch mode TERM is usually set, so just verify it doesn't error
    (should (member (etcc--detect-terminal)
                    '(xterm iterm kitty konsole apple gnome dumb nil)))))

;;; ------------------------------------------------------------------
;;; DECSCUSR sequences (xterm / iterm / kitty / apple / dumb)
;;; ------------------------------------------------------------------

(ert-deftest etcc-decscusr-box-blink ()
  (let ((etcc-use-blink t) (blink-cursor-mode t))
    (should (equal (etcc--decscusr-seq 'box) "\e[1 q"))))

(ert-deftest etcc-decscusr-box-steady ()
  (let ((etcc-use-blink t) (blink-cursor-mode nil))
    (should (equal (etcc--decscusr-seq 'box) "\e[2 q"))))

(ert-deftest etcc-decscusr-bar-blink ()
  (let ((etcc-use-blink t) (blink-cursor-mode t))
    (should (equal (etcc--decscusr-seq 'bar) "\e[5 q"))))

(ert-deftest etcc-decscusr-bar-steady ()
  (let ((etcc-use-blink t) (blink-cursor-mode nil))
    (should (equal (etcc--decscusr-seq 'bar) "\e[6 q"))))

(ert-deftest etcc-decscusr-hbar-blink ()
  (let ((etcc-use-blink t) (blink-cursor-mode t))
    (should (equal (etcc--decscusr-seq 'hbar) "\e[3 q"))))

(ert-deftest etcc-decscusr-hbar-steady ()
  (let ((etcc-use-blink t) (blink-cursor-mode nil))
    (should (equal (etcc--decscusr-seq 'hbar) "\e[4 q"))))

(ert-deftest etcc-decscusr-blink-disabled ()
  "When etcc-use-blink is nil, always steady regardless of blink-cursor-mode."
  (let ((etcc-use-blink nil) (blink-cursor-mode t))
    (should (equal (etcc--decscusr-seq 'box) "\e[2 q"))
    (should (equal (etcc--decscusr-seq 'bar) "\e[6 q"))
    (should (equal (etcc--decscusr-seq 'hbar) "\e[4 q"))))

(ert-deftest etcc-decscusr-invalid-fallback-box ()
  "Invalid shape falls back to box."
  (let ((etcc-use-blink nil))
    (should (equal (etcc--decscusr-seq 'invalid) "\e[2 q"))
    (should (equal (etcc--decscusr-seq nil)      "\e[2 q"))))

;;; ------------------------------------------------------------------
;;; Konsole sequences
;;; ------------------------------------------------------------------

(ert-deftest etcc-konsole-box ()
  (should (equal (etcc--konsole-seq 'box) "\e]50;CursorShape=0\x7")))

(ert-deftest etcc-konsole-bar ()
  (should (equal (etcc--konsole-seq 'bar) "\e]50;CursorShape=1\x7")))

(ert-deftest etcc-konsole-hbar ()
  (should (equal (etcc--konsole-seq 'hbar) "\e]50;CursorShape=2\x7")))

(ert-deftest etcc-konsole-invalid-fallback-box ()
  (should (equal (etcc--konsole-seq 'invalid) "\e]50;CursorShape=0\x7")))

;;; ------------------------------------------------------------------
;;; Dispatch: etcc--make-cursor-shape-seq
;;; ------------------------------------------------------------------

(ert-deftest etcc-dispatch-decscusr-terminals ()
  "xterm, iterm, kitty, apple, dumb all use DECSCUSR."
  (dolist (type '(xterm iterm kitty apple dumb))
    (let ((etcc-term-type-override type)
          (etcc-use-blink nil))
      (should (equal (etcc--make-cursor-shape-seq 'bar) "\e[6 q")))))

(ert-deftest etcc-dispatch-konsole ()
  (let ((etcc-term-type-override 'konsole))
    (should (equal (etcc--make-cursor-shape-seq 'bar)
                   "\e]50;CursorShape=1\x7"))))

(ert-deftest etcc-dispatch-gnome-uses-decscusr ()
  "Gnome Terminal uses DECSCUSR (not gconftool-2)."
  (let ((etcc-term-type-override 'gnome) (etcc-use-blink nil))
    (should (equal (etcc--make-cursor-shape-seq 'box) "\e[2 q"))))

;;; ------------------------------------------------------------------
;;; Cursor color
;;; ------------------------------------------------------------------

(ert-deftest etcc-color-seq-non-iterm ()
  (let ((etcc-term-type-override 'xterm))
    (let ((seq (etcc--make-cursor-color-seq "red")))
      (should (string-prefix-p "\e]12;" seq))
      (should (string-suffix-p "\a" seq)))))

(ert-deftest etcc-color-seq-iterm ()
  (let ((etcc-term-type-override 'iterm))
    (let ((seq (etcc--make-cursor-color-seq "red")))
      (should (string-prefix-p "\e]Pl" seq))
      (should (string-suffix-p "\e\\" seq)))))

(ert-deftest etcc-color-invalid-returns-nil ()
  (should-not (etcc--make-cursor-color-seq "not-a-color")))

;;; ------------------------------------------------------------------
;;; Public API: activate / deactivate
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

(ert-deftest etcc-on-off-are-aliases ()
  (should (equal (indirect-function 'etcc-on)
                 (indirect-function 'evil-terminal-cursor-changer-activate)))
  (should (equal (indirect-function 'etcc-off)
                 (indirect-function 'evil-terminal-cursor-changer-deactivate))))

;;; ------------------------------------------------------------------
;;; Standalone usage (without evil)
;;; ------------------------------------------------------------------

(ert-deftest etcc-set-cursor-symbol ()
  "etcc--set-cursor reads cursor-type when it's a symbol."
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink nil)
        (cursor-type 'bar)
        (sent nil))
    (cl-letf (((symbol-function 'send-string-to-terminal)
               (lambda (seq) (setq sent seq))))
      (etcc--set-cursor)
      (should (equal sent "\e[6 q")))))

(ert-deftest etcc-set-cursor-list ()
  "etcc--set-cursor reads (car cursor-type) when it's a list."
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink nil)
        (cursor-type '(hbar . 2))
        (sent nil))
    (cl-letf (((symbol-function 'send-string-to-terminal)
               (lambda (seq) (setq sent seq))))
      (etcc--set-cursor)
      (should (equal sent "\e[4 q")))))

;;; test.el ends here
