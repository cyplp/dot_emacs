(setq org-directory "~/dev/log_cyp")

(defun my-org-root (target)
  (concat (file-name-as-directory org-directory) target))

(setq org-default-notes-file (my-org-root "refile.org"))

;; I use C-c c to start capture mode
(global-set-key (kbd "C-c c") 'org-capture)

;; hide markup
(setq org-hide-emphasis-markers t)

;; Capture templates for: TODO tasks, Notes, appointments, phone calls, meetings, and org-protocol
(setq org-capture-templates
      '(("a" "Activité"
	 entry
	 (file+olp+datetree (my-org-root "activities.org"))
	 "* %?"
	 :clock-in t
	 :clock-resume t)
	("t" "todo" entry
	 (file  (my-org-root "todos.org"))
	 "\n* TODO %?\n%U\n%a\n" :clock-in t :clock-resume t)
	("T" "todo whitout file" item (file  (my-org-root "todos.org"))
	 "\n* TODO %?\n%U\n" :clock-in t :clock-resume t)
	("p" "Phone call" entry (file+olp+datetree (my-org-root "activities.org"))
	 "\n* PHONE %? :PHONE:\n%U" :clock-in t :clock-resume t)
	("R" "lien vers une recette" entry (file (my-org-root "cookbook.org"))
         "%(org-chef-get-recipe-from-url)"
         :empty-lines 1)
        ("r" "Recette" entry (file (my-org-root "cookbook.org"))
         "* %^{Recipe title: }\n  :PROPERTIES:\n  :source-url:\n  :servings:\n  :prep-time:\n  :cook-time:\n  :ready-in:\n  :END:\n** Ingredients\n   %?\n** Instructions\n\n")
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
(global-set-key (kbd "<S-f6>") (lambda() (interactive)(find-file (my-org-root "activities.org"))))

;; shortcut for TODOS
(global-set-key (kbd "<S-f8>") (lambda() (interactive)(find-file (my-org-root "todos.org"))))

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
(setq org-agenda-files '("~/dev/log_cyp"))

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

;; add auto commit for some org mode file
(use-package git-auto-commit-mode
  :ensure t)

(use-package org-sticky-header
  :ensure t
  :hook (org-mode . org-sticky-header-mode))

(use-package org-present
  :ensure t)

(eval-after-load "org-present"
  '(progn
     (add-hook 'org-present-mode-hook
               (lambda ()
                 (org-present-big)
                 (org-display-inline-images)
                 (org-present-hide-cursor)
                 (org-present-read-only)))
     (add-hook 'org-present-mode-quit-hook
               (lambda ()
                 (org-present-small)
                 (org-remove-inline-images)
                 (org-present-show-cursor)
                 (org-present-read-write)))))

(setq org-roam-directory (my-org-root "roam"))
(if (not(file-exists-p org-roam-directory))
    (make-directory org-roam-directory))

(use-package org-roam
      :ensure t
      :hook (after-init . org-roam-mode)
      :custom (org-roam-directory org-roam-directory)
      :bind (:map org-roam-mode-map
              (("C-c n l" . org-roam)
               ("C-c n f" . org-roam-find-file)
               ("C-c n b" . org-roam-switch-to-buffer)
               ("C-c n g" . org-roam-graph))
              :map org-mode-map
              (("C-c n i" . org-roam-insert))))

(setq org-roam-capture-templates
      '(
	("d" "default" plain (function org-roam--capture-get-point)
	 "%?"
	 :file-name "%(format-time-string \"%Y-%m-%d--%H-%M-%S--${slug}\" (current-time) t)"
	 :head "# -*- eval: (git-auto-commit-mode 1) -*-\n#+TITLE: ${title}\n* ${title}\n"
	 :unnarrowed t)
	))

;; org-roam-server
(use-package org-roam-server
  :ensure t
  :config
  (setq org-roam-server-host "127.0.0.1"
        org-roam-server-port 8080
        org-roam-server-authenticate nil
        org-roam-server-export-inline-images t
        org-roam-server-serve-files nil
        org-roam-server-served-file-extensions '("pdf" "mp4" "ogv")
        org-roam-server-network-poll t
        org-roam-server-network-arrows nil
        org-roam-server-network-label-truncate t
        org-roam-server-network-label-truncate-length 60
        org-roam-server-network-label-wrap-length 20))

(use-package org-journal
  :ensure t
  :bind
  ("C-c n j" . org-journal-new-entry)
  :custom
  (org-journal-date-prefix "# -*- eval: (git-auto-commit-mode 1) -*-\n#+TITLE: ")
  (org-journal-file-format "%Y-%m-%d.org")
  (org-journal-dir org-directory)
  (org-journal-carryover-items "") ;; do not move TODO next day
  (org-journal-date-format "%A, %d %B %Y"))

;; format duration in hours and minutes not in days
(setq org-duration-format 'h:mm)

(use-package org-chef
  :ensure t)

;; org-menu
(quelpa '(org-menu
	  :fetcher git
	  :url "https://github.com/sheijk/org-menu.git"))

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c m") 'org-menu))

(require 'org-menu)


;; org-appear
(quelpa '(org-appear
	  :fetcher git
	  :url "https://github.com/awth13/org-appear.git"))

(add-hook 'org-mode-hook 'org-appear-mode)

(defun sluggify (str)
  (replace-regexp-in-string
   "[^a-z0-9-]"
   "-"
   (downcase str)))
