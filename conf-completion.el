;;; conf-completion.el --- Completion dans le buffer -*- lexical-binding: t -*-

;;; Commentary:

;; Repartition des roles : helm tient le minibuffer (M-x, fichiers, buffers),
;; corfu tient la completion au point dans le buffer.  Les deux ne se marchent
;; pas dessus parce que `helm-mode-handle-completion-in-region' est desactive
;; dans init.el.
;;
;; corfu s'appuie sur `completion-at-point-functions', l'interface standard
;; d'Emacs : eglot, dabbrev et les modes majeurs l'alimentent sans greffon
;; dedie.  C'est ce qui remplace auto-complete et company, tous deux presents
;; auparavant via des paquets satellites (auto-complete-rst, auto-complete-nxml).

;;; Code:

(use-package corfu
  :ensure t
  :custom
  ;; Declenchement automatique : sans cela corfu n'apparait que sur
  ;; `completion-at-point', ce qui revient a taper le raccourci a chaque fois.
  (corfu-auto t)
  (corfu-auto-prefix 2)
  (corfu-auto-delay 0.15)
  (corfu-cycle t)
  ;; Ne pas completer d'office en quittant : une insertion non voulue au
  ;; moindre deplacement du curseur est plus couteuse qu'une completion ratee.
  (corfu-preview-current nil)
  (corfu-quit-no-match 'separator)
  :init
  (global-corfu-mode 1)
  :config
  ;; Documentation du candidat courant dans une infobulle laterale.
  (corfu-popupinfo-mode 1))

;; dabbrev sert de source de repli dans les buffers sans serveur de langage.
;; Par defaut il traverse les buffers d'images et d'archives, ce qui produit
;; des candidats binaires.
(use-package dabbrev
  :custom
  (dabbrev-ignored-buffer-regexps '("\\.\\(?:pdf\\|jpe?g\\|png\\|gz\\|zip\\)\\'")))

(provide 'conf-completion)

;;; conf-completion.el ends here
