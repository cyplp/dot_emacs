(setq org-directory "~/dev/org")
(setq org-default-notes-file "~/dev/org/refile.org")

;; I use C-c c to start capture mode
(global-set-key (kbd "C-c c") 'org-capture)

;; Capture templates for: TODO tasks, Notes, appointments, phone calls, meetings, and org-protocol

(setq org-capture-templates
      '(("a" "Activité"
	 entry
	 (file+olp+datetree "~/dev/log_cyp/activities.org")
	 "* %?"
	 :clock-in t
	 :clock-resume t)
	("t" "todo" entry
	 (file "~/dev/log_cyp/todos.org")
	 "\n** TODO %?\n%U\n%a\n" :clock-in t :clock-resume t)
	("T" "todo whitout file" item (file "~/dev/log_cyp/todos.org")
	 "\n** TODO %?\n%U\n" :clock-in t :clock-resume t)
	("p" "Phone call" entry (file+olp+datetree "~/dev/log_cyp/activities.org")
	 "\n* PHONE %? :PHONE:\n%U" :clock-in t :clock-resume t)
))

;; shortcut for activités
(global-set-key [f6]
		(lambda ()
		  (interactive)
		  (org-capture nil "a")))

;; shortcut for todo without file
(global-set-key [f8]
 		(lambda ()
		 (interactive)
		 (org-capture nil "T")))

;; shortcut for todo file
(global-set-key (kbd "<C-f8>")
 		(lambda ()
		 (interactive)
		 (org-capture nil "t")))

;; shortcut for activities
(global-set-key (kbd "<S-f6>") (lambda() (interactive)(find-file "~/dev/log_cyp/activities.org")))

;; shortcut for TODOS
(global-set-key (kbd "<S-f8>") (lambda() (interactive)(find-file "~/dev/log_cyp/todos.org")))

;; nicer bullets
(use-package org-bullets
  :ensure t)

(org-bullets-mode t)
(add-hook 'org-mode-hook (lambda () (org-bullets-mode 1)))

(use-package org
  :ensure t)
(define-key global-map "\C-cl" 'org-store-link)
(define-key global-map "\C-ca" 'org-agenda)
(setq org-log-done t)

(use-package org-repo-todo
  :ensure t)

(global-set-key (kbd "M-;") 'ort/capture-todo)
(global-set-key (kbd "M-'") 'ort/capture-checkitem)
(global-set-key (kbd "M-d") 'ort/goto-todos)

(use-package dashboard
  :ensure t
  :config
  (dashboard-setup-startup-hook))

(use-package ob-restclient
  :ensure t)

(use-package ob-rust
  :ensure t)

;; active Babel languages
(org-babel-do-load-languages
 'org-babel-load-languages
 '((sql . t)
   (python . t)
   (shell . t)
   (plantuml . t)
   (restclient . t)
   (rust . t)))

(setq org-src-fontify-natively t)

(setq org-todo-keyword-faces
         '(("ARCHIVE" . (:foreground "light green" :weight bold))
           ("DISPATCHED" . (:foreground "light blue" :weight bold))
           ("LATER" . (:foreground "pink" :weight bold))
	   ("INPROGRESS" . (:foreground "light green" :weight bold)))
	 )


(use-package ox-rst
  :ensure t)


(use-package org-fancy-priorities
  :ensure t
  :hook
  (org-mode . org-fancy-priorities-mode)
  :config
  (setq org-fancy-priorities-list '("☇" "↑" "↓")
	org-priority-faces '((?A :foreground "red" :weight bold :size 15)
			     (?B :foreground "orange" :weight bold :size 15)
			     (?C :foreground "green" :weight bold :size 15))))

(setq org-plantuml-jar-path
      (expand-file-name "/usr/share/plantuml/plantuml.jar"))


(use-package ox-pandoc
  :ensure t)

;; sidebar
(quelpa '(org-sidebar
	  :fetcher git
	  :url "https://github.com/alphapapa/org-sidebar.git"))
