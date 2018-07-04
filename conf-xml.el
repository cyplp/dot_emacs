(use-package auto-complete-nxml
  :ensure t)

(use-package nxml-fold
  :ensure t)

;; Keystroke for popup help about something at point.
(setq auto-complete-nxml-popup-help-key "C-:")

;; Keystroke for toggle on/off automatic completion.
(setq auto-complete-nxml-toggle-automatic-key "C-c C-t")

;; If you want to start completion manually from the beginning
(setq auto-complete-nxml-automatic-p nil)

(add-hook 'nxml-mode-hook (lambda () (require 'nxml-fold)))
