;;; conf-python.el --- Configuration Python -*- lexical-binding: t -*-

;;; Commentary:

;; On utilise le python.el integre a Emacs 30 plutot que le paquet MELPA
;; `python-mode'.  Ce dernier lie TAB a `py-indent-line', qui fait defiler les
;; niveaux d'indentation candidats au lieu de calculer le bon : dans un bloc
;; src org, le code sautait d'une colonne a l'autre a chaque TAB.
;;
;; Tout s'accroche a `python-base-mode', ancetre commun de `python-mode' et de
;; `python-ts-mode'.  C'est ce qui fait que la bascule vers tree-sitter decidee
;; dans conf-treesit.el ne desactive silencieusement ni les raccourcis ni les
;; modes mineurs declares ici.

;;; Code:

(require 'python)

;; eglot est charge par conf-lsp.el, qui precede ce module dans
;; `my-configuration-modules'.

(add-hook 'python-base-mode-hook
          (lambda ()
            ;; buffer-local : ce sont des options globales par defaut
            (setq-local python-indent-offset 4)
            (setq-local indent-tabs-mode nil)
            (setq-local tab-width 4)))

;; --- Serveur de langage -----------------------------------------------------

(defconst my-python-language-servers
  '("basedpyright-langserver" "pyright-langserver" "pylsp" "jedi-language-server")
  "Serveurs de langage Python acceptes, du plus complet au plus simple.

La liste par defaut d'eglot se rabat aussi sur \"ruff server\". C'est un piege
ici : pyenv installe un shim `ruff' visible depuis `executable-find' alors que
le binaire n'existe que dans un interpreteur precis. eglot demarrerait donc un
serveur qui echoue immediatement, a chaque ouverture de fichier.")

(defun my-python-available-language-server ()
  "Premier serveur de `my-python-language-servers' present sur la machine."
  (seq-find #'executable-find my-python-language-servers))

(defun my-python-setup-eglot ()
  "Demarrer eglot seulement si un serveur Python est installe.
Sans cette garde, chaque ouverture d'un fichier Python sur une machine sans
serveur produit une erreur de connexion."
  (when (my-python-available-language-server)
    (eglot-ensure)))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               (cons '(python-mode python-ts-mode)
                     (lambda (&rest _)
                       (let ((server (my-python-available-language-server)))
                         (if (member server '("basedpyright-langserver" "pyright-langserver"))
                             (list server "--stdio")
                           (list server)))))))

(add-hook 'python-base-mode-hook #'my-python-setup-eglot)

;; --- Aides a l'ecriture -----------------------------------------------------

(defun python-add-breakpoint ()
  "Inserer un `breakpoint()' sur une nouvelle ligne et sauvegarder."
  (interactive)
  (newline-and-indent)
  (insert "breakpoint()")
  (newline-and-indent)
  (highlight-lines-matching-regexp "^[ ]*breakpoint()")
  (save-buffer))

(defun python-add-remote-breakpoint ()
  "Inserer un point d'arret rpdb, accessible par telnet."
  (interactive)
  (newline-and-indent)
  (insert "import rpdb; rpdb.set_trace()")
  (newline-and-indent)
  (highlight-lines-matching-regexp "^[ ]*import rpdb; rpdb.set_trace()")
  (save-buffer))

(defun python-add-noqa ()
  "Ajouter un marqueur `# NOQA' en fin de ligne courante."
  (interactive)
  (move-end-of-line nil)
  (insert "  # NOQA"))

(defun python-add-nocover ()
  "Ajouter un marqueur `# pragma: nocover' en fin de ligne courante."
  (interactive)
  (move-end-of-line nil)
  (insert "  # pragma: nocover")
  (save-buffer))

(defun python-replace-quote ()
  "Remplacer les guillemets doubles par des simples sur la ligne courante."
  (interactive)
  (save-excursion
    (move-beginning-of-line nil)
    (let ((line-end (copy-marker (line-end-position))))
      (while (re-search-forward "\"" line-end t)
        (replace-match "'" nil nil)))))

(defun python-add-header-file ()
  "Inserer l'en-tete de module : encodage puis docstring."
  (interactive)
  ;; `goto-line' est reserve a l'usage interactif et declenche un
  ;; avertissement a la compilation ; en Lisp on se deplace directement.
  (goto-char (point-min))
  (insert "# coding: utf-8\n")
  (insert "\"\"\"Some comment.\"\"\"\n\n"))

(defun telnet-rpdb ()
  "Ouvrir un telnet sur le port par defaut de rpdb."
  (interactive)
  (telnet "127.0.0.1" 4444))

;; Les raccourcis portent sur `python-base-mode-map' pour valoir aussi bien en
;; `python-mode' qu'en `python-ts-mode'.
;;
;; Les anciennes liaisons "C-p" (nocover) et "C-f" (erreur suivante) sont
;; abandonnees : elles ecrasaient `previous-line' et `forward-char' dans tous
;; les buffers Python. Le parcours des erreurs passe desormais par les M-n /
;; M-p de flymake (conf-lsp.el).
(defconst my-python-key-bindings
  '(("C-c C-b" . python-add-breakpoint)
    ("C-c C-r" . python-add-remote-breakpoint)
    ("<f7>"    . python-add-nocover)
    ("<f8>"    . python-add-header-file)
    ("<f9>"    . python-replace-quote)
    ("<f10>"   . python-add-noqa))
  "Raccourcis maison des buffers Python.")

;; Les liaisons sont posees sur les deux keymaps enfants et non sur
;; `python-base-mode-map'. python.el reserve deja certaines de ces touches dans
;; les keymaps de `python-mode' et `python-ts-mode' — C-c C-b y vaut
;; `python-shell-send-block' — et une keymap enfant masque toujours son parent :
;; declarer dans la keymap commune ne suffit donc pas a reprendre la touche.
(dolist (python-keymap (list python-mode-map python-ts-mode-map))
  (dolist (binding my-python-key-bindings)
    (define-key python-keymap (kbd (car binding)) (cdr binding))))

;; --- Outils -----------------------------------------------------------------

;; Generation de docstrings au format Sphinx.
(use-package sphinx-doc
  :ensure t
  :hook (python-base-mode . sphinx-doc-mode))

;; Coloration et raccourcis pour les fichiers reStructuredText.
(use-package sphinx-mode
  :ensure t
  :commands sphinx-mode)

(use-package pip-requirements
  :ensure t
  :mode ("requirements\\(?:-[^/]*\\)?\\.txt\\'" . pip-requirements-mode))

;; Note sur le formatage : `blacken' a ete retire, black n'etant pas installe
;; ici. `ruff format' le remplacerait avantageusement, mais son binaire n'est
;; accessible que dans l'environnement pyenv 3.11 — le brancher sur
;; `before-save-hook' ferait echouer chaque sauvegarde ailleurs. A rebrancher
;; le jour ou l'outil est disponible globalement.

(provide 'conf-python)

;;; conf-python.el ends here
