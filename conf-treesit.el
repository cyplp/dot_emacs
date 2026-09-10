;;; conf-treesit.el --- tree-sitter major modes -*- lexical-binding: t -*-

;;; Commentary:

;; Emacs 30 ships a tree-sitter mode for most of the languages used here.
;; These modes really parse the syntax instead of approximating it with regular
;; expressions: coloring stays correct inside strings and nestings, indentation
;; follows the grammar, and `imenu' / folding become reliable.  They replace
;; several unmaintained MELPA packages (go-mode, rust-mode, lua-mode,
;; typescript-mode, csharp-mode).
;;
;; Two precautions structure this file.
;;
;; 1. Grammar revisions are pinned.  Emacs 30.1 reads ABI 13 to 14 (see
;;    `treesit-library-abi-version'), yet most grammars switched to ABI 15
;;    during 2025: building the default branch produces a library that compiles
;;    without error but refuses to load.  Every revision listed here has been
;;    checked to be 14 or lower.
;;
;; 2. Nothing is enabled without a grammar.  A missing or unreadable grammar
;;    leaves the classic mode in place rather than opening the file in
;;    `fundamental-mode'.

;;; Code:

(require 'treesit)

(setq treesit-language-source-alist
      '((bash       "https://github.com/tree-sitter/tree-sitter-bash"       "v0.23.3")
        (c-sharp    "https://github.com/tree-sitter/tree-sitter-c-sharp"    "v0.23.1")
        (css        "https://github.com/tree-sitter/tree-sitter-css"        "v0.23.2")
        (dockerfile "https://github.com/camdencheek/tree-sitter-dockerfile" "v0.2.0")
        (go         "https://github.com/tree-sitter/tree-sitter-go"         "v0.23.4")
        (gomod      "https://github.com/camdencheek/tree-sitter-go-mod"     "v1.1.0")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "v0.23.1")
        (json       "https://github.com/tree-sitter/tree-sitter-json"       "v0.24.8")
        (lua        "https://github.com/tree-sitter-grammars/tree-sitter-lua" "v0.3.0")
        (python     "https://github.com/tree-sitter/tree-sitter-python"     "v0.23.6")
        (rust       "https://github.com/tree-sitter/tree-sitter-rust"       "v0.23.3")
        (toml       "https://github.com/tree-sitter/tree-sitter-toml"       "v0.5.1")
        (tsx        "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2" "tsx/src")
        (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2" "typescript/src")
        (yaml       "https://github.com/ikatyang/tree-sitter-yaml"          "v0.5.0")))

(defconst my-treesit-major-modes
  '((python     python-ts-mode     python-mode    nil)
    (go         go-ts-mode         nil            "\\.go\\'")
    (gomod      go-mod-ts-mode     nil            "\\(?:\\`\\|/\\)go\\.mod\\'")
    (rust       rust-ts-mode       nil            "\\.rs\\'")
    (yaml       yaml-ts-mode       yaml-mode      "\\.ya?ml\\'")
    (json       json-ts-mode       json-mode      "\\.json\\'")
    (toml       toml-ts-mode       conf-toml-mode "\\.toml\\'")
    (dockerfile dockerfile-ts-mode nil            "\\(?:\\`\\|/\\)\\(?:Containerfile\\|Dockerfile\\)\\(?:\\.[^/]*\\)?\\'")
    (bash       bash-ts-mode       sh-mode        nil)
    (css        css-ts-mode        css-mode       nil)
    (javascript js-ts-mode         (js-mode javascript-mode) nil)
    (typescript typescript-ts-mode nil            "\\.ts\\'")
    (tsx        tsx-ts-mode        nil            "\\.tsx\\'")
    (c-sharp    csharp-ts-mode     csharp-mode    nil)
    (lua        lua-ts-mode        nil            "\\.lua\\'"))
  "Mapping between grammar, tree-sitter mode and classic mode.

Each entry is (GRAMMAR TS-MODE CLASSIC-MODE FILE-REGEXP).

CLASSIC-MODE, when non-nil, is the mode Emacs would choose without
tree-sitter; it is then redirected through `major-mode-remap-alist', which
preserves the existing `auto-mode-alist' rules and stays reversible.  A list
is accepted, for the languages that `auto-mode-alist' designates sometimes by
a name and sometimes by its alias — `js-mode' and `javascript-mode' point to
the same function, but the remapping compares symbols.

FILE-REGEXP covers the opposite case: the tree-sitter modes do not register
themselves in `auto-mode-alist', and without a MELPA package to do it an
extension such as .go or .rs no longer has any mode associated.  The go.mod
case is the most surprising: Emacs associates it by default with `m2-mode',
that is, Modula-2.

Some entries set both fields. That is necessary when a still-installed package
keeps an autoload on the same extension — json-mode on .json, go-mode on
go.mod: the remapping alone would not be enough, since it is the package, and
not the native mode, that `auto-mode-alist' would designate.")

(defun my-treesit-missing-grammars ()
  "List of the grammars declared but not usable.
A grammar built against an incompatible ABI is reported here just like a
missing grammar: in both cases the tree-sitter mode cannot start."
  (seq-remove (lambda (language)
                (treesit-ready-p language t))
              (mapcar #'car treesit-language-source-alist)))

(defun my-treesit-install-missing-grammars ()
  "Build and install the missing grammars.
Requires git and a C compiler. The operation takes several minutes on the
first run; it has nothing to do afterwards."
  (interactive)
  (let ((missing (my-treesit-missing-grammars)))
    (if (null missing)
        (message "All tree-sitter grammars are installed")
      (dolist (language missing)
        (message "Installing the %s grammar..." language)
        (treesit-install-language-grammar language))
      (message "Grammars installed: %s" missing))))

(defun my-treesit-activate-modes ()
  "Route each language to its tree-sitter mode when the grammar answers.
The languages without a usable grammar keep their classic mode, which keeps a
broken grammar from making whole files unreadable."
  (dolist (entry my-treesit-major-modes)
    (let ((language (nth 0 entry))
          (treesit-mode (nth 1 entry))
          (classic-mode (nth 2 entry))
          (file-pattern (nth 3 entry)))

      (when (and (treesit-ready-p language t)
                 (fboundp treesit-mode))
        (dolist (replaced-mode (if (listp classic-mode) classic-mode (list classic-mode)))
          (when replaced-mode
            (add-to-list 'major-mode-remap-alist (cons replaced-mode treesit-mode))))
        (when file-pattern
          (add-to-list 'auto-mode-alist (cons file-pattern treesit-mode)))))))

(my-treesit-activate-modes)

;; Maximal decoration level: the tree-sitter modes then distinguish function
;; calls, properties and operators, where the default level 3 stops at keywords
;; and strings.
(setq treesit-font-lock-level 4)

;; Reports what is missing only once, without installing anything behind the
;; user's back: building grammars downloads code and runs a compiler, which has
;; no place in a silent startup.
(add-hook 'emacs-startup-hook
          (lambda ()
            (let ((missing (my-treesit-missing-grammars)))
              (when missing
                (message "Missing tree-sitter grammars (%s): M-x my-treesit-install-missing-grammars"
                         (mapconcat #'symbol-name missing " "))))))

(provide 'conf-treesit)

;;; conf-treesit.el ends here
