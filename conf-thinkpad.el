;;; conf-thinkpad.el --- ThinkPad-specific keys -*- lexical-binding: t -*-

;;; Commentary:

;; The ThinkPad navigation keys are bound by default to beginning and end of
;; buffer, which makes them dangerous within thumb reach.  We bring them back
;; to beginning and end of line.

;;; Code:

(global-set-key [XF86Forward] #'move-end-of-line)
(global-set-key [XF86Back] #'move-beginning-of-line)

;; The big blue button drives playback in Rhythmbox.
(use-package helm-rhythmbox
  :ensure t
  :commands (helm-rhythmbox helm-rhythmbox-playpause-song)
  :bind ([XF86Launch1] . helm-rhythmbox-playpause-song))

(provide 'conf-thinkpad)

;;; conf-thinkpad.el ends here
