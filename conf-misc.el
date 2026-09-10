;;; conf-misc.el --- General tools -*- lexical-binding: t -*-

;;; Commentary:

;; Everything that belongs to no language: editing, navigation, web search,
;; multimedia, small homemade commands.

;;; Code:

;; --- Localization -----------------------------------------------------------

;; `setq' and not `defvar': these variables are already defined by calendar.el,
;; and `defvar' does not override a variable that already has a value. The old
;; version only worked by accident, because it ran before calendar was loaded.
(with-eval-after-load 'calendar
  (setq calendar-day-name-array
        ["dimanche" "lundi" "mardi" "mercredi" "jeudi" "vendredi" "samedi"])
  (setq calendar-month-name-array
        ["janvier" "février" "mars" "avril" "mai" "juin"
         "juillet" "août" "septembre" "octobre" "novembre" "décembre"]))

;; --- Editing commands -------------------------------------------------------

(defun increment-number-at-point ()
  "Increment by one the number under the cursor."
  (interactive)
  (skip-chars-backward "0-9")
  (unless (looking-at "[0-9]+")
    (error "No number under the cursor"))
  (replace-match (number-to-string (1+ (string-to-number (match-string 0))))))

(global-set-key (kbd "C-+") #'increment-number-at-point)

(defun kill-start-of-line ()
  "Delete from the cursor to the beginning of the line."
  (interactive)
  (kill-line 0))

(global-set-key (kbd "M-k") #'kill-start-of-line)

(defun eol-newline-indent ()
  "Open an indented line below the current one, from anywhere."
  (interactive)
  (end-of-line)
  (newline-and-indent))

(global-set-key (kbd "M-<return>") #'eol-newline-indent)

(defun uniquify-region-lines (region-start region-end)
  "Delete the identical adjacent lines between REGION-START and REGION-END."
  (interactive "*r")
  (save-excursion
    (goto-char region-start)
    (while (re-search-forward "^\\(.*\n\\)\\1+" region-end t)
      (replace-match "\\1"))))

(defun uniquify-buffer-lines ()
  "Delete the identical adjacent lines in the whole buffer."
  (interactive)
  (uniquify-region-lines (point-min) (point-max)))

(defun get-string-from-file (file-path)
  "Return the content of FILE-PATH, without surrounding whitespace."
  (with-temp-buffer
    (insert-file-contents file-path)
    (string-trim (buffer-string))))

(defun uuid-create ()
  "Return a UUID provided by the kernel."
  (get-string-from-file "/proc/sys/kernel/random/uuid"))

(defun uuid-insert ()
  "Insert a new UUID at point."
  (interactive)
  (insert (uuid-create)))

;; --- Navigation and selection -----------------------------------------------

(use-package move-text
  :ensure t
  :bind (([M-up] . move-text-up)
         ([M-down] . move-text-down)))

(use-package iedit
  :ensure t
  :commands iedit-mode)

;; symbol-overlay replaces highlight-symbol: the latter is no longer maintained
;; and re-scanned the whole buffer with a regular expression after every cursor
;; move. symbol-overlay bounds its search to the displayed portion and only
;; puts its overlays on demand.
(use-package symbol-overlay
  :ensure t
  :hook (prog-mode . symbol-overlay-mode)
  :bind (:map symbol-overlay-mode-map
              ("M-s s" . symbol-overlay-put)
              ("M-s n" . symbol-overlay-jump-next)
              ("M-s p" . symbol-overlay-jump-prev)
              ("M-s r" . symbol-overlay-rename)))

(use-package imenu-list
  :ensure t
  :bind ([f1] . imenu-list-smart-toggle))

(use-package edit-indirect
  :ensure t
  :commands edit-indirect-region)

;; vundo replaces undo-tree, which was installed but whose global mode was
;; never enabled: `undo-tree-visualize' therefore failed when called.
;; vundo hooks onto the native undo history instead of replacing it, keeps no
;; state on disk and cannot corrupt the buffer history.
(use-package vundo
  :ensure t
  :bind ("C-x :" . vundo)
  :custom
  (vundo-glyph-alist vundo-unicode-symbols))

;; The default undo history is quickly truncated on a big refactoring, which
;; makes the visualization useless.
(setq undo-limit (* 8 1024 1024))
(setq undo-strong-limit (* 16 1024 1024))

;; --- Code display -----------------------------------------------------------

(use-package highlight-indent-guides
  :ensure t
  :hook (prog-mode . highlight-indent-guides-mode)
  :custom
  (highlight-indent-guides-method 'character)
  ;; the "responsive" mode re-evaluates the guides on every cursor move
  (highlight-indent-guides-responsive nil)
  (highlight-indent-guides-suppress-auto-error t))

(use-package highlight-parentheses
  :ensure t
  :hook (prog-mode . highlight-parentheses-mode))

;; Colorizes colors written in hexadecimal in place.
(use-package rainbow-mode
  :ensure t
  :commands rainbow-mode)

;; --- Miscellaneous major modes ----------------------------------------------

(use-package ssh-config-mode
  :ensure t
  :mode (("/\\.ssh/config\\'" . ssh-config-mode)
         ("/sshd?_config\\'" . ssh-config-mode)
         ("/known_hosts\\'" . ssh-known-hosts-mode)
         ("/authorized_keys2?\\'" . ssh-authorized-keys-mode)))

(use-package graphviz-dot-mode
  :ensure t
  :mode ("\\.dot\\'" . graphviz-dot-mode))

(use-package plantuml-mode
  :ensure t
  :mode ("\\.plantuml\\'" . plantuml-mode))

(use-package markdown-mode
  :ensure t
  :mode (("README\\.md\\'" . gfm-mode)
         ("\\.md\\'" . markdown-mode)
         ("\\.markdown\\'" . markdown-mode))
  :custom (markdown-command "multimarkdown"))

(use-package jq-mode
  :ensure t
  :mode ("\\.jq\\'" . jq-mode))

;; Emacs 30 provides `lua-ts-mode': the MELPA package `lua-mode' was dropped,
;; the .lua association is done in conf-treesit.el.

;; --- HTTP requests ----------------------------------------------------------

(use-package restclient
  :ensure t
  :mode ("\\.http\\'" . restclient-mode))

(use-package restclient-helm
  :ensure t
  :after restclient)

;; --- Files and buffers ------------------------------------------------------

(use-package helm-ls-git
  :ensure t
  :commands helm-ls-git)

(use-package sudo-edit
  :ensure t
  :commands (sudo-edit sudo-edit-find-file))

(use-package ibuffer-git :ensure t :after ibuffer)
(use-package ibuffer-vc :ensure t :after ibuffer)
(use-package ibuffer-tramp :ensure t :after ibuffer)

(global-set-key (kbd "C-x C-b") #'ibuffer)

;; Cleanup of trailing whitespace, limited to buffers that are already clean:
;; an old file therefore never ends up reformatted in full in a commit that was
;; only supposed to touch three lines.
(use-package whitespace-cleanup-mode
  :ensure t
  :config
  (global-whitespace-cleanup-mode t))

;; editorconfig is bundled with Emacs 30; the MELPA package is no longer needed.
(editorconfig-mode 1)

;; --- Startup ----------------------------------------------------------------

;; Welcome screen: recent files, projects, bookmarks. Declared here and not in
;; conf-org.el, where it had no business being.
(use-package dashboard
  :ensure t
  :config
  (dashboard-setup-startup-hook))

;; --- Documentation and help -------------------------------------------------

(use-package helm-dash
  :ensure t
  :commands (helm-dash helm-dash-at-point))

(use-package cheat-sh
  :ensure t
  :commands (cheat-sh cheat-sh-search))

(use-package tldr
  :ensure t
  :commands tldr)

(use-package lorem-ipsum
  :ensure t
  :commands (lorem-ipsum-insert-paragraphs
             lorem-ipsum-insert-sentences
             lorem-ipsum-insert-list))

(use-package remind-bindings
  :ensure t
  :hook (after-init . remind-bindings-initialise)
  :bind (("C-c C-d" . remind-bindings-toggle-buffer)
         ("C-c M-d" . remind-bindings-specific-mode)))

;; Key usage statistics, useful to spot the frequent commands that deserve a
;; shortcut.
(use-package keyfreq
  :ensure t
  :config
  (keyfreq-mode 1)
  (keyfreq-autosave-mode 1))

;; --- Web search -------------------------------------------------------------

;; The URLs are all in HTTPS: several engines now refuse clear text, and the
;; "rfcs" engine pointed at pretty-rfc.herokuapp.com, out of service since the
;; free Heroku dynos were shut down. It is replaced by the official IETF
;; service.
(use-package engine-mode
  :ensure t
  :config
  (engine-mode t)

  (defengine duckduckgo "https://duckduckgo.com/?q=%s" :keybinding "d")
  (defengine google "https://www.google.fr/search?ie=utf-8&oe=utf-8&q=%s" :keybinding "g")
  (defengine github "https://github.com/search?ref=simplesearch&q=%s")
  (defengine stack-overflow "https://stackoverflow.com/search?q=%s")
  (defengine rfcs "https://datatracker.ietf.org/doc/search?name=%s&rfcs=on")
  (defengine wikipedia
    "https://www.wikipedia.org/search-redirect.php?language=fr&go=Go&search=%s"
    :keybinding "w")
  (defengine wiktionary
    "https://www.wikipedia.org/search-redirect.php?family=wiktionary&language=fr&go=Go&search=%s")
  (defengine google-maps "https://maps.google.com/maps?q=%s")
  (defengine wolfram-alpha "https://www.wolframalpha.com/input/?i=%s")
  (defengine youtube "https://www.youtube.com/results?search_query=%s")
  (defengine project-gutenberg "https://www.gutenberg.org/ebooks/search/?query=%s"))

;; --- Multimedia -------------------------------------------------------------

(use-package emms
  :ensure t
  :commands (emms emms-play-directory emms-play-file)
  :custom
  (emms-playlist-buffer-name "*Music*")
  (emms-info-asynchronously t)
  (emms-source-file-default-directory "~/musique/")
  :config
  (emms-all)
  (emms-default-players)
  ;; libtag is the only metadata provider: the others spawn one subprocess per
  ;; track.
  (require 'emms-info-libtag)
  (setq emms-info-functions '(emms-info-libtag))
  (emms-mode-line 1)
  (emms-playing-time 1))

(defconst my-fip-stream-url
  "https://stream.radiofrance.fr/fip/fip_hifi.m3u8?id=radiofrance"
  "HLS stream of the FIP radio.")

(use-package eradio
  :ensure t
  :bind (("C-c r p" . eradio-play)
         ("C-c r s" . eradio-stop))
  :custom
  (eradio-channels (list (cons "fip" my-fip-stream-url))))

(defun eradio-play-fip ()
  "Play FIP directly, without going through the station chooser."
  (interactive)
  (require 'eradio)
  (eradio--play-low-level my-fip-stream-url)
  (message "FIP rox !"))

;; Binding installed outside the `use-package': passing this command through
;; `:bind' would make use-package generate an autoload to the eradio package,
;; which does not define it.
(global-set-key (kbd "C-c r f") #'eradio-play-fip)

;; --- Dropped packages -------------------------------------------------------

;; pocket-reader : the Pocket service shut down in July 2025.
;; wttrin         : unmaintained, broken by a wttr.in API change.
;; multi-term     : unmaintained; `M-x ansi-term' covers the same need.
;; origami        : unmaintained, and no key was bound to it here.
;; beacon, ctrlf  : declared but never enabled (`ctrf-mode' was moreover a
;;                  typo for `ctrlf-mode').
;; csharp-mode    : bundled with Emacs since version 29.
;; auto-complete-rst : an auto-complete plugin, replaced by corfu.
;; flycheck and its plugins : see conf-lsp.el.
;; spaceline / powerline : the XPM separators were regenerated on every
;;                  redisplay; the modus-operandi mode-line replaces them.
;; dimmer         : recomputed the faces of every window on each buffer
;;                  change.
;; smooth-scrolling : replaced by `pixel-scroll-precision-mode' (init.el).

(provide 'conf-misc)

;;; conf-misc.el ends here
