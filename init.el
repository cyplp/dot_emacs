;;; init.el --- Configuration principale -*- lexical-binding: t -*-

;;; Commentary:

;; Point d'entree unique.  Ce fichier ne contient que ce qui doit exister
;; avant tout le reste : depots de paquets, reglages du moteur Emacs, et le
;; chargement des modules `conf-*.el'.  Toute configuration liee a un langage
;; ou a un outil precis vit dans son propre module.

;;; Code:

(require 'package)

;; HTTPS partout : le depot GNU etait encore declare en clair.
(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))

;; Charge toujours le .el quand il est plus recent que le .elc correspondant.
(setq load-prefer-newer t)

(package-initialize)

;; use-package est integre depuis Emacs 29 : le bootstrap manuel n'a plus
;; lieu d'etre.  `require' reste necessaire pour que les macros soient
;; disponibles a la compilation des modules.
(require 'use-package)

;; Les avertissements de compilation native remontent en boucle sur des
;; paquets tiers qu'on ne corrigera pas ; ils masquent les vrais messages.
(setq native-comp-async-report-warnings-errors 'silent)

;; --- Performance / anti-freeze ---------------------------------------------

;; Le ramasse-miettes est neutralise pendant l'initialisation, ou l'on alloue
;; massivement et brievement, puis ramene a un seuil vivable. Le garder a
;; `most-positive-fixnum' en regime normal repousserait la collecte jusqu'a
;; une pause de plusieurs secondes.
(setq gc-cons-threshold most-positive-fixnum)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 64 1024 1024))))

;; Les serveurs LSP (gopls, rust-analyzer) envoient de gros paquets JSON. Le
;; defaut de 4096 octets force Emacs a boucler des milliers de fois par
;; reponse : c'est la cause n1 des gels avec eglot.
(setq read-process-output-max (* 4 1024 1024))

;; Bascule automatiquement en mode degrade sur les fichiers a lignes tres
;; longues (JSON minifie, logs, dumps SQL), ou font-lock devient inutilisable.
(global-so-long-mode 1)

;; L'algorithme bidirectionnel de rendu du texte coute cher et n'a aucune
;; utilite ici : on force la direction gauche-droite.
(setq-default bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)

;; Evite qu'Emacs vide ses caches de fontes sous pression memoire, ce qui
;; provoque des pauses de redisplay avec les themes riches en glyphes.
(setq inhibit-compacting-font-caches t)

;; --- Fichiers ---------------------------------------------------------------

(setq make-backup-files nil) ; pas de fichiers backup~
(setq auto-save-default nil) ; pas de fichiers #autosave#
(setq create-lockfiles nil)  ; pas de fichiers .#

;; Avertit a l'ouverture des fichiers de plus de 100 Mo.
(setq large-file-warning-threshold 100000000)

(setq require-final-newline t)
(setq next-line-add-newlines nil)

;; Recharge un buffer dont le fichier a change sur disque, y compris dired.
(setq global-auto-revert-non-file-buffers t)
(global-auto-revert-mode 1)

;; --- Interface --------------------------------------------------------------

(load-theme 'modus-operandi t)

(setq inhibit-splash-screen t)
(setq ring-bell-function 'ignore)

;; `%d' n'existe pas parmi les specificateurs de `frame-title-format' : le
;; titre affichait la lettre telle quelle. On montre le buffer et son chemin.
(setq frame-title-format '("%b" (:eval (if buffer-file-name " — %f" "")) " — Emacs"))

(menu-bar-mode 0)
(tool-bar-mode 0)

(setq column-number-mode t)
(setq line-number-mode t)

;; Reponses a une lettre. Remplace l'ancien `fset' sur `yes-or-no-p', qui
;; ecrasait la fonction pour tout le monde y compris les appels ou une
;; confirmation longue est voulue.
(setq use-short-answers t)

(prefer-coding-system 'utf-8)

;; Affiche seulement la queue des lignes trop longues, les tabulations et les
;; espaces en fin de ligne. Le nettoyage effectif est assure par
;; `global-whitespace-cleanup-mode' (conf-misc.el), qui ne touche que les
;; buffers deja propres.
(setq whitespace-line-column 88
      whitespace-style '(tabs trailing lines-tail))

(show-paren-mode t)
(winner-mode t)
(delete-selection-mode 1)

;; Paires automatiques. Remplace `skeleton-pair', dont l'activation passait
;; par des liaisons globales sur "(", "[", "{" et le guillemet : elles
;; s'appliquaient a tous les buffers, y compris le minibuffer et les modes
;; texte ou l'auto-appariement n'est pas souhaitable.
(electric-pair-mode 1)

;; Defilement au pixel, natif depuis Emacs 29.
(pixel-scroll-precision-mode 1)

(setq tramp-default-method "ssh")
(setq calendar-week-start-day 1)

(setq select-enable-clipboard t)

;; Limite la taille du buffer *Messages*.
(setq-default message-log-max 1000)

;; --- Paquets de base --------------------------------------------------------

(use-package try
  :ensure t
  :commands try)

;; quelpa : installation depuis un depot git pour les paquets absents de
;; MELPA. Conserve pour les paquets deja construits ; les nouveaux passent
;; par `:vc', integre a use-package depuis Emacs 30.
(use-package quelpa
  :ensure t
  :defer t)

(use-package which-key
  :ensure t
  :config
  (which-key-mode))

(use-package ace-window
  :ensure t
  :bind ([remap other-window] . ace-window))

(use-package expand-region
  :ensure t
  :bind ("C-œ" . er/expand-region))

;; Utilise par certains snippets yasnippet pour convertir la casse.
(use-package string-inflection
  :ensure t
  :commands (string-inflection-underscore
             string-inflection-camelcase
             string-inflection-kebab-case))

(use-package yasnippet
  :ensure t
  :config
  (yas-global-mode 1))

(use-package yasnippet-snippets
  :ensure t
  :after yasnippet)

(use-package aws-snippets
  :ensure t
  :after yasnippet)

(use-package xclip
  :ensure t
  :config
  (xclip-mode 1))

(use-package helm
  :ensure t
  :bind (("M-x" . helm-M-x)
         ("C-c C-c M-x" . execute-extended-command))
  :init
  (setq helm-M-x-fuzzy-match t
        helm-mode-fuzzy-match t
        helm-buffers-fuzzy-matching t
        helm-recentf-fuzzy-match t
        helm-locate-fuzzy-match t
        helm-semantic-fuzzy-match t
        helm-imenu-fuzzy-match t
        helm-completion-in-region-fuzzy-match t
        ;; helm garde le minibuffer, corfu garde la completion dans le buffer
        helm-mode-handle-completion-in-region nil
        helm-candidate-number-list 150
        helm-split-window-inside-p t
        helm-move-to-line-cycle-in-source t
        helm-echo-input-in-header-line t
        helm-autoresize-max-height 0
        helm-autoresize-min-height 20)
  :config
  (helm-mode 1))

;; --- Chargement des modules -------------------------------------------------

;; Les modules sont charges par `require' et non plus par `load-file' : le
;; chemin absolu disparait des appels, un module deja charge ne l'est pas deux
;; fois, et la byte-compilation devient possible.
(add-to-list 'load-path (expand-file-name "." user-emacs-directory))

;; Custom ecrit dans son propre fichier pour ne pas reecrire celui-ci.
(setq custom-file (locate-user-emacs-file "custom.el"))

(when (file-exists-p custom-file)
  (load custom-file nil t))

(defconst my-configuration-modules
  '(conf-treesit
    conf-completion
    conf-lsp
    ;; org
    conf-org
    conf-org-emphasis
    ;; divers
    conf-misc
    conf-python
    conf-git
    conf-shortcut
    conf-auto-load
    conf-jabber
    conf-xml
    conf-rust
    conf-go
    conf-sql
    conf-web
    conf-thinkpad
    conf-dired
    conf-elisp
    conf-yaml
    conf-devops
    conf-claude
    conf-antigravity
    conf-mcp
    conf-mcp-explorer
    conf-latex
    conf-webserver)
  "Modules de configuration a charger, dans l'ordre.
L'ordre compte : `conf-treesit' fixe les modes majeurs et `conf-lsp' les
reglages eglot dont dependent les modules par langage.")

(defun my-load-configuration-module (module)
  "Charger MODULE en isolant ses erreurs.
Sans cette isolation, une seule erreur dans un module interrompt tout le
reste du chargement et laisse Emacs a moitie configure, sans indice sur le
coupable.

MODULE est un symbole de fonctionnalite (voir `provide')."
  (condition-case failure
      (require module)
    (error
     (message "Module %s non charge : %s" module (error-message-string failure)))))

(mapc #'my-load-configuration-module my-configuration-modules)

;; Fichiers hors depot git : secrets, connexions base, reliquats de l'ancien
;; .emacs. Charges par `load' car ils n'ont pas de `provide'.
(dolist (private-file '("secret.el" "dbconnections.el" "old.el"))
  (let ((path (locate-user-emacs-file private-file)))
    (when (file-exists-p path)
      (load path nil t))))

(message "conf loaded")

;;; init.el ends here
