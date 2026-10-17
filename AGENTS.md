# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

```bash
# Run all tests
emacs --batch -L . -l test.el -f ert-run-tests-batch-and-exit

# Run a single test by name
emacs --batch -L . -l test.el --eval '(ert-run-tests-batch-and-exit "evil-terminal-cursor-changer-decscusr-box-steady")'
```

## Architecture

Single-file Emacs Lisp package (`evil-terminal-cursor-changer.el`) distributed via MELPA. No build step — just load the `.el` file.

**Data-driven design:** Terminal detection uses lookup tables. All terminals use unified DECSCUSR for shape and OSC 12 for color.

- `evil-terminal-cursor-changer--term-detectors` — alist of `(TYPE . DETECT-FN)`. `evil-terminal-cursor-changer--detect-terminal` caches detection per terminal against an environment snapshot and detector-table identity; `evil-terminal-cursor-changer-term-type-override` takes precedence.
- `evil-terminal-cursor-changer--decscusr-codes` — shape-to-escape-code mapping. Blink vs steady via nested alist keyed on boolean.
- `evil-terminal-cursor-changer--make-cursor-shape-seq` — returns DECSCUSR sequence, or nil if no terminal is detected or the shape is nil.
- `evil-terminal-cursor-changer--make-cursor-color-seq` — caches the last color and OSC 12 sequence per frame, including invalid colors. Activation refreshes the selected display's caches.
- `evil-terminal-cursor-changer--set-cursor` — skips nonselected-window redisplay callbacks and reads the selected window's buffer. Cached sequences are still sent on each update so outside terminal output cannot leave a stale cursor.

**Adding a new terminal:** Add an entry to `evil-terminal-cursor-changer--term-detectors` and a `const` choice in `evil-terminal-cursor-changer-term-type-override`. All modern terminals support DECSCUSR, so no sequence changes needed.

**Test structure:** `test.el` uses ERT with isolated terminal environments and selected-window fixtures. `cl-letf` on `send-string-to-terminal` captures output for assertion.
