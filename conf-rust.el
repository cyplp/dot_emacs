;;; conf-rust.el --- Configuration Rust -*- lexical-binding: t -*-

;;; Commentary:

;; `rust-ts-mode' (Emacs 30) + eglot + rust-analyzer.
;;
;; Cette pile remplace quatre paquets qui se recouvraient : `rust-mode' et
;; `rustic' fournissaient chacun un mode majeur pour .rs, `racer' proposait la
;; completion et la documentation — le projet est archive depuis 2021, son role
;; ayant ete repris par rust-analyzer — et `cargo' faisait double emploi avec
;; `cargo-mode', tous deux activant un `cargo-minor-mode' sur le meme hook.
;;
;; `flycheck-rust' disparait avec flycheck : les diagnostics de clippy arrivent
;; desormais par rust-analyzer, donc par flymake (voir conf-lsp.el).

;;; Code:

(use-package reformatter
  :ensure t
  :demand t)

;; rustfmt lit stdin et ecrit stdout : le formatage ne passe pas par le serveur
;; de langage et ne peut donc pas geler Emacs en attendant rust-analyzer.
(reformatter-define rust-format
  :program "rustfmt"
  :args '("--emit" "stdout" "--quiet"))

(defun my-rust-setup ()
  "Reglages communs aux buffers Rust."
  (eglot-ensure)
  (rust-format-on-save-mode 1))

;; Les indices de type en ligne, principal apport de rust-analyzer sur du code
;; fortement infere, sont actives par eglot lui-meme des que le serveur declare
;; la capacite. Les allumer depuis le hook du mode majeur echouait : a cet
;; instant `eglot-ensure' n'a pas encore etabli la connexion, et la commande
;; remontait une erreur "No current JSON-RPC connection" a chaque ouverture de
;; fichier .rs.

(add-hook 'rust-ts-mode-hook #'my-rust-setup)

;; Lancement des commandes cargo depuis le buffer courant.
(use-package cargo-mode
  :ensure t
  :hook (rust-ts-mode . cargo-minor-mode)
  ;; La keymap du mode mineur s'appelle `cargo-minor-mode-map' ; le nom
  ;; `cargo-mode-map' n'existe pas, et la liaison echouait a l'activation du
  ;; mode par un "void-variable".
  :bind (:map cargo-minor-mode-map
              ("C-c b" . cargo-mode-build)
              ("C-c t" . cargo-mode-test)))

;; Les reglages rust-analyzer (clippy, build scripts, macros procedurales)
;; sont dans conf-lsp.el.

(provide 'conf-rust)

;;; conf-rust.el ends here
