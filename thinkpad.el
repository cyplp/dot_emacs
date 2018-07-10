;; default mapping is BOF and EOF
(global-set-key [XF86Forward] 'move-end-of-line)
(global-set-key [XF86Back] 'move-beginning-of-line)

;; use big blue button for pay/pause in rhythmbox
(use-package helm-rhythmbox
  :ensure t)
(global-set-key [XF86Launch1] 'helm-rhythmbox-playpause-song)
