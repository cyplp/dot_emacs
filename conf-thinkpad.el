;;; conf-thinkpad.el --- Touches specifiques au ThinkPad -*- lexical-binding: t -*-

;;; Commentary:

;; Les touches de navigation du clavier ThinkPad sont associees par defaut au
;; debut et a la fin du buffer, ce qui les rend dangereuses a portee de pouce.
;; On les ramene au debut et a la fin de ligne.

;;; Code:

(global-set-key [XF86Forward] #'move-end-of-line)
(global-set-key [XF86Back] #'move-beginning-of-line)

;; Le gros bouton bleu pilote la lecture dans Rhythmbox.
(use-package helm-rhythmbox
  :ensure t
  :commands (helm-rhythmbox helm-rhythmbox-playpause-song)
  :bind ([XF86Launch1] . helm-rhythmbox-playpause-song))

(provide 'conf-thinkpad)

;;; conf-thinkpad.el ends here
