(use-package auto-complete-nxml
  :ensure t)

;; Keystroke for popup help about something at point.
(setq auto-complete-nxml-popup-help-key "C-:")

;; Keystroke for toggle on/off automatic completion.
(setq auto-complete-nxml-toggle-automatic-key "C-c C-t")

;; If you want to start completion manually from the beginning
(setq auto-complete-nxml-automatic-p nil)

(use-package html5-schema
  :ensure t)

;;could be usefull sometimes
(use-package x-path-walker
  :ensure t)

(use-package hideshow
  :ensure t)

(use-package sgml-mode
  :ensure t)


;; fold some part
;; https://emacs.stackexchange.com/questions/2884/the-old-how-to-fold-xml-question
(add-to-list 'hs-special-modes-alist
             '(nxml-mode
               "<!--\\|<[^/>]*[^/]>"
               "-->\\|</[^/>]*[^/]>"

               "<!--"
               sgml-skip-tag-forward
               nil))

(add-hook 'nxml-mode-hook 'hs-minor-mode)

;; optional key bindings, easier than hs defaults
(define-key nxml-mode-map (kbd "C-c h") 'hs-toggle-hiding)

(use-package reformatter
  :ensure t)

(reformatter-define xml-format
  :program "xmllint"
  :args '("--format" "-")
  :mode ((nxml-mode
	  (mode . xml-format-on-save))))
