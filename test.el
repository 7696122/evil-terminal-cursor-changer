;;; test.el --- ERT tests for evil-terminal-cursor-changer  -*- lexical-binding: t; -*-

(require 'ert)
(add-to-list 'load-path (file-name-directory (or load-file-name buffer-file-name)))
(require 'evil-terminal-cursor-changer)

;;; ------------------------------------------------------------------
;;; Terminal detection via etcc-term-type-override
;;; ------------------------------------------------------------------

(ert-deftest etcc-detect-all-types-via-override ()
  "Each override value should be detected correctly."
  (dolist (type '(xterm iterm kitty konsole apple alacritty wezterm
                        wterm foot ghostty hyper rio tabby gnome dumb))
    (let ((etcc-term-type-override type))
      (should (eq (etcc--detect-terminal) type)))))

(ert-deftest etcc-detect-nil-override ()
  "nil override falls through to env var detection."
  (let ((etcc-term-type-override nil))
    ;; In batch mode TERM is usually set, so just verify it doesn't error
    (should (member (etcc--detect-terminal)
                    '(xterm iterm kitty konsole apple alacritty wezterm
                      wterm foot ghostty hyper rio tabby gnome dumb nil)))))

;;; ------------------------------------------------------------------
;;; DECSCUSR sequences
;;; ------------------------------------------------------------------

(ert-deftest etcc-decscusr-box-blink ()
  (let ((etcc-term-type-override 'xterm) (etcc-use-blink t) (blink-cursor-mode t))
    (should (equal (etcc--make-cursor-shape-seq 'box) "\e[1 q"))))

(ert-deftest etcc-decscusr-box-steady ()
  (let ((etcc-term-type-override 'xterm) (etcc-use-blink t) (blink-cursor-mode nil))
    (should (equal (etcc--make-cursor-shape-seq 'box) "\e[2 q"))))

(ert-deftest etcc-decscusr-bar-blink ()
  (let ((etcc-term-type-override 'xterm) (etcc-use-blink t) (blink-cursor-mode t))
    (should (equal (etcc--make-cursor-shape-seq 'bar) "\e[5 q"))))

(ert-deftest etcc-decscusr-bar-steady ()
  (let ((etcc-term-type-override 'xterm) (etcc-use-blink t) (blink-cursor-mode nil))
    (should (equal (etcc--make-cursor-shape-seq 'bar) "\e[6 q"))))

(ert-deftest etcc-decscusr-hbar-blink ()
  (let ((etcc-term-type-override 'xterm) (etcc-use-blink t) (blink-cursor-mode t))
    (should (equal (etcc--make-cursor-shape-seq 'hbar) "\e[3 q"))))

(ert-deftest etcc-decscusr-hbar-steady ()
  (let ((etcc-term-type-override 'xterm) (etcc-use-blink t) (blink-cursor-mode nil))
    (should (equal (etcc--make-cursor-shape-seq 'hbar) "\e[4 q"))))

(ert-deftest etcc-decscusr-blink-disabled ()
  "When etcc-use-blink is nil, always steady regardless of blink-cursor-mode."
  (let ((etcc-term-type-override 'xterm) (etcc-use-blink nil) (blink-cursor-mode t))
    (should (equal (etcc--make-cursor-shape-seq 'box) "\e[2 q"))
    (should (equal (etcc--make-cursor-shape-seq 'bar) "\e[6 q"))
    (should (equal (etcc--make-cursor-shape-seq 'hbar) "\e[4 q"))))

(ert-deftest etcc-decscusr-invalid-fallback-box ()
  "Invalid shape falls back to box."
  (let ((etcc-term-type-override 'xterm) (etcc-use-blink nil))
    (should (equal (etcc--make-cursor-shape-seq 'invalid) "\e[2 q"))))

(ert-deftest etcc-decscusr-nil-shape-returns-nil ()
  "nil shape (hidden cursor) should return nil, not a fallback."
  (should-not (etcc--make-cursor-shape-seq nil)))

(ert-deftest etcc-decscusr-no-terminal-returns-nil ()
  "Undetected terminal returns nil."
  (let ((etcc-term-type-override nil)
        (etcc-use-blink nil))
    (cl-letf (((symbol-function 'getenv) (lambda (_) nil)))
      (should-not (etcc--make-cursor-shape-seq 'box)))))

;;; ------------------------------------------------------------------
;;; Dispatch: etcc--make-cursor-shape-seq for all terminals
;;; ------------------------------------------------------------------

(ert-deftest etcc-dispatch-all-use-decscusr ()
  "All detected terminals use DECSCUSR."
  (dolist (type '(xterm iterm kitty konsole apple alacritty wezterm
                        wterm foot ghostty hyper rio tabby gnome dumb))
    (let ((etcc-term-type-override type)
          (etcc-use-blink nil))
      (should (equal (etcc--make-cursor-shape-seq 'bar) "\e[6 q")))))

;;; ------------------------------------------------------------------
;;; Cursor color (OSC 12, unified for all terminals)
;;; ------------------------------------------------------------------

(ert-deftest etcc-color-seq-all-terminals ()
  "All terminals use OSC 12 for cursor color."
  (dolist (type '(xterm iterm kitty konsole apple alacritty wezterm
                        wterm foot ghostty hyper rio tabby gnome dumb))
    (let ((etcc-term-type-override type))
      (let ((seq (etcc--make-cursor-color-seq "red")))
        (should (string-prefix-p "\e]12;" seq))
        (should (string-suffix-p "\a" seq))))))

(ert-deftest etcc-color-invalid-returns-nil ()
  (should-not (etcc--make-cursor-color-seq "not-a-color")))

;;; ------------------------------------------------------------------
;;; etcc--set-cursor integration
;;; ------------------------------------------------------------------

(ert-deftest etcc-set-cursor-symbol ()
  "etcc--set-cursor reads cursor-type when it's a symbol."
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink nil)
        (etcc-use-color nil)
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
        (etcc-use-color nil)
        (cursor-type '(hbar . 2))
        (sent nil))
    (cl-letf (((symbol-function 'send-string-to-terminal)
               (lambda (seq) (setq sent seq))))
      (etcc--set-cursor)
      (should (equal sent "\e[4 q")))))

(ert-deftest etcc-set-cursor-nil-does-nothing ()
  "etcc--set-cursor does not send shape when cursor-type is nil."
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink nil)
        (etcc-use-color nil)
        (cursor-type nil)
        (sent nil))
    (cl-letf (((symbol-function 'send-string-to-terminal)
               (lambda (seq) (setq sent seq))))
      (etcc--set-cursor)
      (should-not sent))))

(ert-deftest etcc-set-cursor-with-color ()
  "etcc--set-cursor sends color sequence when etcc-use-color is t."
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink nil)
        (etcc-use-color t)
        (cursor-type 'bar)
        sent-seqs)
    (cl-letf (((symbol-function 'send-string-to-terminal)
               (lambda (seq) (push seq sent-seqs)))
              ((symbol-function 'frame-parameter)
               (lambda (_frame param)
                 (when (eq param 'cursor-color) "red"))))
      (etcc--set-cursor)
      (should (= (length sent-seqs) 2))
      (should (member "\e[6 q" sent-seqs))
      (should (cl-find-if (lambda (s) (string-prefix-p "\e]12;" s)) sent-seqs)))))

(ert-deftest etcc-set-cursor-no-color-when-disabled ()
  "etcc--set-cursor skips color when etcc-use-color is nil."
  (let ((etcc-term-type-override 'xterm)
        (etcc-use-blink nil)
        (etcc-use-color nil)
        (cursor-type 'bar)
        sent-seqs)
    (cl-letf (((symbol-function 'send-string-to-terminal)
               (lambda (seq) (push seq sent-seqs)))
              ((symbol-function 'frame-parameter)
               (lambda (_frame param)
                 (when (eq param 'cursor-color) "red"))))
      (etcc--set-cursor)
      (should (= (length sent-seqs) 1))
      (should (equal (car sent-seqs) "\e[6 q")))))

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
;;; Visible-buffer cursor synchronization
;;; ------------------------------------------------------------------

(defmacro etcc-test--with-visible-input (&rest body)
  "Run BODY with a visible input buffer and a separate callback buffer."
  (declare (indent 0))
  `(save-window-excursion
     (let ((visible (generate-new-buffer " *etcc-input*"))
           (background (generate-new-buffer " *etcc-callback*"))
           (etcc-term-type-override 'xterm)
           (etcc-use-blink nil)
           (etcc-use-color nil)
           (blink-cursor-mode nil)
           (pre-command-hook nil)
           (post-command-hook nil)
           (blink-cursor-mode-hook nil)
           (pre-redisplay-functions nil)
           sent)
       (unwind-protect
           (progn
             (switch-to-buffer visible)
             (setq-local cursor-type 'bar)
             (with-current-buffer background
               (setq-local cursor-type 'box))
             (cl-letf (((symbol-function 'send-string-to-terminal)
                        (lambda (seq &optional _terminal) (push seq sent))))
               ,@body))
         (evil-terminal-cursor-changer-deactivate)
         (kill-buffer visible)
         (kill-buffer background)))))

(ert-deftest etcc-background-command-keeps-visible-input-cursor ()
  "A server callback must not replace the visible input bar with a box."
  (etcc-test--with-visible-input
    (evil-terminal-cursor-changer-activate)
    (setq sent nil)
    (with-current-buffer background
      (run-hooks 'pre-command-hook 'post-command-hook))
    (should (equal sent '("\e[6 q" "\e[6 q")))
    (should (eq (buffer-local-value 'cursor-type visible) 'bar))
    (should (eq (buffer-local-value 'cursor-type background) 'box))))

(ert-deftest etcc-background-blink-keeps-visible-input-cursor ()
  "Blink changes in a callback must use the selected window's cursor."
  (etcc-test--with-visible-input
    (let ((etcc-use-blink t))
      (evil-terminal-cursor-changer-activate)
      (setq sent nil)
      (with-current-buffer background
        (blink-cursor-mode -1))
      (should (equal sent '("\e[6 q"))))))

(ert-deftest etcc-redisplay-restores-input-cursor-after-background-work ()
  "Repair the terminal cursor after async work without another command."
  (etcc-test--with-visible-input
    (evil-terminal-cursor-changer-activate)
    (setq sent nil)
    ;; Model a subprocess leaving the physical cursor in block shape.
    (send-string-to-terminal "\e[2 q")
    (with-current-buffer background
      (run-hook-with-args 'pre-redisplay-functions (list (selected-window))))
    (should (equal sent '("\e[6 q" "\e[2 q")))))

(ert-deftest etcc-deactivation-stops-redisplay-output ()
  (etcc-test--with-visible-input
    (evil-terminal-cursor-changer-activate)
    (evil-terminal-cursor-changer-deactivate)
    (setq sent nil)
    (with-current-buffer background
      (run-hooks 'pre-command-hook 'post-command-hook 'blink-cursor-mode-hook)
      (run-hook-with-args 'pre-redisplay-functions t))
    (should-not sent)))

(ert-deftest etcc-reactivation-registers-redisplay-once ()
  (etcc-test--with-visible-input
    (evil-terminal-cursor-changer-activate)
    (evil-terminal-cursor-changer-activate)
    (should (= (cl-count 'etcc--set-cursor pre-redisplay-functions) 1))
    (setq sent nil)
    (run-hook-with-args 'pre-redisplay-functions t)
    (should (equal sent '("\e[6 q")))))

(ert-deftest etcc-gui-hooks-do-not-send-terminal-output ()
  (etcc-test--with-visible-input
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t)))
      (evil-terminal-cursor-changer-activate)
      (with-current-buffer background
        (run-hooks 'post-command-hook 'blink-cursor-mode-hook)
        (run-hook-with-args 'pre-redisplay-functions t))
      (should-not sent))))

(ert-deftest etcc-hidden-visible-cursor-does-not-use-background-box ()
  (etcc-test--with-visible-input
    (setq-local cursor-type nil)
    (evil-terminal-cursor-changer-activate)
    (with-current-buffer background
      (run-hooks 'post-command-hook)
      (run-hook-with-args 'pre-redisplay-functions t))
    (should-not sent)))

(ert-deftest etcc-visible-normal-buffer-still-uses-box ()
  (etcc-test--with-visible-input
    (setq-local cursor-type 'box)
    (evil-terminal-cursor-changer-activate)
    (should (equal sent '("\e[2 q")))))

;;; test.el ends here
