;;; conf-git.el --- Integration git -*- lexical-binding: t -*-

;;; Commentary:

;; magit et ses satellites.  Les reglages de performance sont conserves : le
;; buffer de statut de magit est le point de contact le plus frequent avec un
;; depot, et son rafraichissement automatique est ce qui coute le plus cher.

;;; Code:

;; Marques de modification dans la marge.
(use-package git-gutter
  :ensure t
  :hook (prog-mode . git-gutter-mode)
  :custom
  ;; 0 desactive le rafraichissement periodique : la marge se met a jour sur
  ;; les evenements du buffer, sans minuterie qui reveille Emacs au repos.
  (git-gutter:update-interval 0))

(use-package git-gutter-fringe
  :ensure t
  :after git-gutter
  :config
  (define-fringe-bitmap 'git-gutter-fr:added [224] nil nil '(center repeated))
  (define-fringe-bitmap 'git-gutter-fr:modified [224] nil nil '(center repeated))
  (define-fringe-bitmap 'git-gutter-fr:deleted [128 192 224 240] nil nil 'bottom))

(use-package magit
  :ensure t
  :bind ("C-x g" . magit-status)
  :custom
  ;; Ne pas reconstruire le buffer de statut apres chaque commande : sur un
  ;; gros depot chaque rafraichissement relance une dizaine de sous-processus
  ;; git. `g' rafraichit a la demande.
  (magit-refresh-status-buffer nil)
  ;; Mettre a t pour profiler les temps de rafraichissement de magit.
  (magit-refresh-verbose nil))

;; Diff colore mot a mot dans magit, via delta.
(use-package magit-delta
  :ensure t
  :hook (magit-mode . magit-delta-mode))

(use-package forge
  :ensure t
  :after magit
  :config
  ;; Ces sections interrogent l'API de la forge a chaque ouverture du statut.
  ;; Le retrait doit avoir lieu apres le chargement de forge : c'est forge qui
  ;; les installe, donc les appels a `remove-hook' au chargement du fichier —
  ;; comme c'etait le cas jusqu'ici — s'executaient avant l'ajout et n'avaient
  ;; aucun effet.
  (remove-hook 'magit-status-sections-hook 'forge-insert-pullreqs)
  (remove-hook 'magit-status-sections-hook 'forge-insert-issues))

;; Modes majeurs pour .gitconfig, .gitignore, .gitattributes.
(use-package git-modes
  :ensure t)

(use-package gist
  :ensure t
  :commands (gist-region gist-buffer gist-list))

;; Affiche le commit responsable de la ligne courante.
;; Remplace git-messenger, non maintenu depuis 2019 et qui faisait doublon.
(use-package vc-msg
  :ensure t
  :bind ("C-x v p" . vc-msg-show))

;; Ouvrir la ligne courante dans l'interface web de la forge.
(use-package browse-at-remote
  :ensure t
  :bind ("C-x v b" . browse-at-remote))

(use-package gitlab-ci-mode
  :ensure t
  :mode ("\\.gitlab-ci\\.ya?ml\\'" . gitlab-ci-mode))

;; `gitlab-ci-mode-flycheck' est retire avec flycheck ; la validation passe par
;; `M-x gitlab-ci-lint', qui interroge directement l'API GitLab.

;; Assistance a la redaction de messages au format Conventional Commits.
;; `:vc' remplace l'appel a quelpa : quelpa interrogeait le depot distant a
;; chaque demarrage d'Emacs, la ou package-vc n'agit qu'a l'installation.
;; La coloration du format vit dans `conf-conventional-commit'.
(use-package conventional-commit
  :vc (:url "https://github.com/akirak/conventional-commit.el" :rev :newest)
  ;; `git-commit-setup' lie `git-commit-mode-hook' a nil le temps d'activer le
  ;; mode mineur : la completion accrochee la n'etait jamais installee sur un
  ;; commit lance par magit. `git-commit-setup-hook' est le point d'entree que
  ;; magit prevoit pour la configuration d'un tampon de message.
  :hook (git-commit-setup . conventional-commit-setup))

(provide 'conf-git)

;;; conf-git.el ends here
