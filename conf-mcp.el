;;; conf-mcp.el --- Serveurs Model Context Protocol -*- lexical-binding: t -*-

;;; Commentary:

;; `mcp.el' parle le protocole MCP depuis Emacs : il gere le cycle de vie des
;; serveurs — processus stdio ou endpoint HTTP — et expose leurs outils,
;; prompts et ressources au reste d'Emacs.  `mcp-hub' en est le tableau de
;; bord : liste des serveurs, demarrage, arret, inspection des outils.
;;
;; A ne pas confondre avec le serveur MCP de `conf-claude.el', qui va dans
;; l'autre sens : celui-la expose Emacs au CLI Claude, celui-ci consomme des
;; serveurs tiers depuis Emacs.
;;
;; L'adresse et le jeton du serveur HTTP sont des donnees privees : elles
;; vivent dans `secret.el', hors du depot git.  Ce module se contente de les
;; cabler, et reste inerte si elles sont absentes — sur une machine sans
;; `secret.el' la configuration se charge sans erreur, aucun serveur n'est
;; declare.
;;
;; `secret.el' doit definir :
;;
;;   (setq my-mcp-http-server-url   "http://hote:port/mcp")
;;   (setq my-mcp-http-server-token "...")

;;; Code:

;; --- Parametres prives ------------------------------------------------------

;; Valeurs par defaut nil : `secret.el' est charge en fin d'`init.el', donc
;; apres ce module.  Le `defvar' declare seulement la variable, le `setq' de
;; `secret.el' l'alimente ensuite.

(defvar my-mcp-http-server-url nil
  "Adresse du serveur MCP HTTP, ou nil s'il n'y en a pas.
Definie dans `secret.el', hors du depot git.")

(defvar my-mcp-http-server-token nil
  "Jeton d'authentification du serveur MCP HTTP.
Defini dans `secret.el', hors du depot git.")

(defvar my-mcp-http-server-name "local"
  "Nom sous lequel le serveur MCP HTTP apparait dans `mcp-hub'.")

;; Declaration sans valeur : la variable appartient a `mcp-hub', on signale
;; seulement au compilateur qu'elle existe.
(defvar mcp-hub-servers)

;; --- Declaration du serveur -------------------------------------------------

(defun my-mcp-register-http-server ()
  "Declarer le serveur MCP HTTP prive dans `mcp-hub-servers'.
Ne fait rien tant que `my-mcp-http-server-url' ou
`my-mcp-http-server-token' n'est pas renseigne par `secret.el'.

L'entree est posee par `alist-get' plutot que par un `setq' de la liste
entiere : les autres serveurs eventuellement declares ailleurs survivent,
et un second appel met a jour l'entree au lieu de la dupliquer."
  (when (and my-mcp-http-server-url my-mcp-http-server-token)
    (setf (alist-get my-mcp-http-server-name mcp-hub-servers nil nil #'equal)
          (list :url my-mcp-http-server-url
                ;; Le mot-cle `:token' de mcp.el n'est pas utilisable ici : il
                ;; construit un en-tete "Authorization: Bearer ...", alors que
                ;; ce serveur attend le schema "Token" de Django REST
                ;; Framework.  On passe donc l'en-tete complet.
                :headers `(("Authorization"
                            . ,(concat "Token " my-mcp-http-server-token)))))))

;; --- Paquet -----------------------------------------------------------------

;; Aucun demarrage automatique : le serveur ecoute en local et n'est pas
;; toujours lance, une connexion a chaque demarrage d'Emacs echouerait le plus
;; souvent pour rien.  `mcp-hub' demarre ce qui est utile, a la demande.
;;
;; `C-c m' est deja pris par `org-menu' dans les buffers org (conf-org.el).
(use-package mcp
  :ensure t
  :bind ("C-c M-m" . mcp-hub)
  :commands (mcp-hub mcp-connect-server))

;; La declaration attend le chargement de `mcp-hub' — donc le premier appel a
;; `mcp-hub' — pour deux raisons : `mcp-hub-servers' n'existe pas avant, et
;; `secret.el' est alors certain d'avoir ete charge.
(with-eval-after-load 'mcp-hub
  (my-mcp-register-http-server))

(provide 'conf-mcp)

;;; conf-mcp.el ends here
