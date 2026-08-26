;;; conf-misc.el --- Outils generaux -*- lexical-binding: t -*-

;;; Commentary:

;; Tout ce qui n'appartient a aucun langage : edition, navigation, recherche
;; web, multimedia, petites commandes maison.

;;; Code:

;; --- Localisation -----------------------------------------------------------

;; `setq' et non `defvar' : ces variables sont deja definies par calendar.el,
;; et `defvar' n'ecrase pas une variable ayant deja une valeur. L'ancienne
;; version ne fonctionnait que par accident, parce qu'elle s'executait avant le
;; chargement de calendar.
(with-eval-after-load 'calendar
  (setq calendar-day-name-array
        ["dimanche" "lundi" "mardi" "mercredi" "jeudi" "vendredi" "samedi"])
  (setq calendar-month-name-array
        ["janvier" "février" "mars" "avril" "mai" "juin"
         "juillet" "août" "septembre" "octobre" "novembre" "décembre"]))

;; --- Commandes d'edition ----------------------------------------------------

(defun increment-number-at-point ()
  "Incrementer de un le nombre situe sous le curseur."
  (interactive)
  (skip-chars-backward "0-9")
  (unless (looking-at "[0-9]+")
    (error "Aucun nombre sous le curseur"))
  (replace-match (number-to-string (1+ (string-to-number (match-string 0))))))

(global-set-key (kbd "C-+") #'increment-number-at-point)

(defun kill-start-of-line ()
  "Supprimer du curseur jusqu'au debut de la ligne."
  (interactive)
  (kill-line 0))

(global-set-key (kbd "M-k") #'kill-start-of-line)

(defun eol-newline-indent ()
  "Ouvrir une ligne indentee sous la ligne courante, depuis n'importe ou."
  (interactive)
  (end-of-line)
  (newline-and-indent))

(global-set-key (kbd "M-<return>") #'eol-newline-indent)

(defun uniquify-region-lines (region-start region-end)
  "Supprimer les lignes adjacentes identiques entre REGION-START et REGION-END."
  (interactive "*r")
  (save-excursion
    (goto-char region-start)
    (while (re-search-forward "^\\(.*\n\\)\\1+" region-end t)
      (replace-match "\\1"))))

(defun uniquify-buffer-lines ()
  "Supprimer les lignes adjacentes identiques dans tout le buffer."
  (interactive)
  (uniquify-region-lines (point-min) (point-max)))

(defun get-string-from-file (file-path)
  "Renvoyer le contenu de FILE-PATH, sans blancs de bord."
  (with-temp-buffer
    (insert-file-contents file-path)
    (string-trim (buffer-string))))

(defun uuid-create ()
  "Renvoyer un UUID fourni par le noyau."
  (get-string-from-file "/proc/sys/kernel/random/uuid"))

(defun uuid-insert ()
  "Inserer un nouvel UUID au point."
  (interactive)
  (insert (uuid-create)))

;; --- Navigation et selection ------------------------------------------------

(use-package move-text
  :ensure t
  :bind (([M-up] . move-text-up)
         ([M-down] . move-text-down)))

(use-package iedit
  :ensure t
  :commands iedit-mode)

;; symbol-overlay remplace highlight-symbol : ce dernier n'est plus maintenu et
;; re-parcourait tout le buffer en expression reguliere apres chaque
;; deplacement du curseur. symbol-overlay borne sa recherche a la portion
;; affichee et ne pose ses overlays qu'a la demande.
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

;; vundo remplace undo-tree, qui etait installe mais dont le mode global
;; n'etait jamais active : `undo-tree-visualize' echouait donc a l'appel.
;; vundo se greffe sur l'historique d'annulation natif au lieu de le
;; remplacer, ne conserve aucun etat sur disque et ne peut pas corrompre
;; l'historique du buffer.
(use-package vundo
  :ensure t
  :bind ("C-x :" . vundo)
  :custom
  (vundo-glyph-alist vundo-unicode-symbols))

;; L'historique d'annulation par defaut est vite tronque sur un gros
;; refactoring, ce qui rend la visualisation inutile.
(setq undo-limit (* 8 1024 1024))
(setq undo-strong-limit (* 16 1024 1024))

;; --- Affichage du code ------------------------------------------------------

(use-package highlight-indent-guides
  :ensure t
  :hook (prog-mode . highlight-indent-guides-mode)
  :custom
  (highlight-indent-guides-method 'character)
  ;; le mode "responsive" reevalue les guides a chaque deplacement du curseur
  (highlight-indent-guides-responsive nil)
  (highlight-indent-guides-suppress-auto-error t))

(use-package highlight-parentheses
  :ensure t
  :hook (prog-mode . highlight-parentheses-mode))

;; Colorise sur place les couleurs ecrites en hexadecimal.
(use-package rainbow-mode
  :ensure t
  :commands rainbow-mode)

;; --- Modes majeurs divers ---------------------------------------------------

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

;; Emacs 30 fournit `lua-ts-mode' : le paquet MELPA `lua-mode' a ete retire,
;; l'association de .lua est faite dans conf-treesit.el.

;; --- Requetes HTTP ----------------------------------------------------------

(use-package restclient
  :ensure t
  :mode ("\\.http\\'" . restclient-mode))

(use-package restclient-helm
  :ensure t
  :after restclient)

;; --- Fichiers et buffers ----------------------------------------------------

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

;; Nettoyage des espaces en fin de ligne, limite aux buffers deja propres :
;; un fichier ancien ne se retrouve donc jamais reformate en entier dans un
;; commit qui ne devait toucher que trois lignes.
(use-package whitespace-cleanup-mode
  :ensure t
  :config
  (global-whitespace-cleanup-mode t))

;; editorconfig est integre a Emacs 30 ; le paquet MELPA n'est plus necessaire.
(editorconfig-mode 1)

;; --- Demarrage --------------------------------------------------------------

;; Ecran d'accueil : fichiers recents, projets, marque-pages. Declare ici et
;; non dans conf-org.el, ou il n'avait rien a faire.
(use-package dashboard
  :ensure t
  :config
  (dashboard-setup-startup-hook))

;; --- Documentation et aide --------------------------------------------------

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

;; Statistiques d'utilisation des touches, utiles pour reperer les commandes
;; frequentes qui meritent un raccourci.
(use-package keyfreq
  :ensure t
  :config
  (keyfreq-mode 1)
  (keyfreq-autosave-mode 1))

;; --- Recherche web ----------------------------------------------------------

;; Les URL sont toutes en HTTPS : plusieurs moteurs refusent aujourd'hui le
;; texte clair, et le moteur "rfcs" pointait sur pretty-rfc.herokuapp.com,
;; hors service depuis l'arret des dynos gratuits Heroku. Il est remplace par
;; le service officiel de l'IETF.
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
  ;; libtag est le seul fournisseur de metadonnees : les autres lancent un
  ;; sous-processus par piste.
  (require 'emms-info-libtag)
  (setq emms-info-functions '(emms-info-libtag))
  (emms-mode-line 1)
  (emms-playing-time 1))

(defconst my-fip-stream-url
  "https://stream.radiofrance.fr/fip/fip_hifi.m3u8?id=radiofrance"
  "Flux HLS de la radio FIP.")

(use-package eradio
  :ensure t
  :bind (("C-c r p" . eradio-play)
         ("C-c r s" . eradio-stop))
  :custom
  (eradio-channels (list (cons "fip" my-fip-stream-url))))

(defun eradio-play-fip ()
  "Lancer directement FIP, sans passer par le choix de station."
  (interactive)
  (require 'eradio)
  (eradio--play-low-level my-fip-stream-url)
  (message "FIP rox !"))

;; Liaison posee hors du `use-package' : passer cette commande par `:bind'
;; ferait generer a use-package un autoload vers le paquet eradio, qui ne la
;; definit pas.
(global-set-key (kbd "C-c r f") #'eradio-play-fip)

;; --- Paquets retires --------------------------------------------------------

;; pocket-reader : le service Pocket a ferme en juillet 2025.
;; wttrin         : non maintenu, casse par un changement d'API de wttr.in.
;; multi-term     : non maintenu ; `M-x ansi-term' couvre le meme besoin.
;; origami        : non maintenu, et aucune touche ne lui etait liee ici.
;; beacon, ctrlf  : declares mais jamais actives (`ctrf-mode' etait d'ailleurs
;;                  une coquille pour `ctrlf-mode').
;; csharp-mode    : integre a Emacs depuis la version 29.
;; auto-complete-rst : greffon d'auto-complete, remplace par corfu.
;; flycheck et ses greffons : voir conf-lsp.el.
;; spaceline / powerline : les separateurs XPM etaient regeneres a chaque
;;                  redisplay ; la mode-line de modus-operandi les remplace.
;; dimmer         : recalculait les faces de toutes les fenetres a chaque
;;                  changement de buffer.
;; smooth-scrolling : remplace par `pixel-scroll-precision-mode' (init.el).

(provide 'conf-misc)

;;; conf-misc.el ends here
