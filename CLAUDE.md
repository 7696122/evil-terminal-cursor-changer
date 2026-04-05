# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

```bash
# Run all tests
emacs --batch -L . -l test.el -f ert-run-tests-batch-and-exit

# Run a single test by name
emacs --batch -L . -l test.el --eval '(ert-run-tests-batch-and-exit "etcc-decscusr-box-steady")'
```

## Architecture

Single-file Emacs Lisp package (`evil-terminal-cursor-changer.el`) distributed via MELPA. No build step — just load the `.el` file.

**Data-driven design:** Terminal detection uses lookup tables. All terminals use unified DECSCUSR for shape and OSC 12 for color.

- `etcc--term-detectors` — alist of `(TYPE . DETECT-FN)`. `etcc--detect-terminal` iterates through it, returning the first match. `etcc-term-type-override` short-circuits detection.
- `etcc--decscusr-codes` — shape-to-escape-code mapping. Blink vs steady via nested alist keyed on boolean.
- `etcc--make-cursor-shape-seq` — returns DECSCUSR sequence. Returns nil if no terminal detected or shape is nil.
- `etcc--make-cursor-color-seq` — returns OSC 12 color sequence. Unified for all terminals.
- `etcc--set-cursor` — reads `cursor-type` and sends shape sequence; if `etcc-use-color` is t, also reads `cursor-color` frame parameter and sends color sequence. Works with evil, meow, or standalone.

**Adding a new terminal:** Add an entry to `etcc--term-detectors` and a `const` choice in `etcc-term-type-override`. All modern terminals support DECSCUSR, so no sequence changes needed.

**Test structure:** `test.el` uses ERT. Tests override `etcc-term-type-override` to control terminal detection without real env vars. `cl-letf` on `send-string-to-terminal` captures output for assertion.
