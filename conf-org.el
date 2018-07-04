(setq org-directory "~/dev/org")
(setq org-default-notes-file "~/dev/org/refile.org")

;; I use C-c c to start capture mode
(global-set-key (kbd "C-c c") 'org-capture)

;; Capture templates for: TODO tasks, Notes, appointments, phone calls, meetings, and org-protocol

(setq org-capture-templates
      '(("a" "Activité"
	 entry
	 (file+datetree "~/dev/log_cyp/activities.org")
	 "* %?"
	 :clock-in t
	 :clock-resume t)
      ("t" "todo" entry (file+datetree "~/dev/log_cyp/activities.org")
       "* TODO %?\n%U\n%a\n" :clock-in t :clock-resume t)
      ("r" "respond" entry (file+datetree "~/dev/log_cyp/activities.org")
       "* NEXT Respond to %:from on %:subject\nSCHEDULED: %t\n%U\n%a\n" :clock-in t :clock-resume t :immediate-finish t)
      ("n" "note" entry (file+datetree "~/dev/log_cyp/activities.org")
       "* %? :NOTE:\n%U\n%a\n" :clock-in t :clock-resume t)
      ("j" "Journal" entry (file+datetree+datetree "~/dev/log_cyp/diary.org")
       "* %?\n%U\n" :clock-in t :clock-resume t)
      ("w" "org-protocol" entry (file+datetree "~/dev/log_cyp/activities.org")
       "* TODO Review %c\n%U\n" :immediate-finish t)
      ("m" "Meeting" entry (file+datetree "~/dev/log_cyp/activities.org")
       "* MEETING with %? :MEETING:\n%U" :clock-in t :clock-resume t)
      ("p" "Phone call" entry (file+datetree "~/dev/log_cyp/activities.org")
       "* PHONE %? :PHONE:\n%U" :clock-in t :clock-resume t)
      ("h" "Habit" entry (file+datetree "~/dev/log_cyp/activities.org")
       "* NEXT %?\n%U\n%a\nSCHEDULED: %(format-time-string \"%<<%Y-%m-%d %a .+1d/3d>>\")\n:PROPERTIES:\n:STYLE: habit\n:REPEAT_TO_STATE: NEXT\n:END:\n")))

(global-set-key [f6]
		(lambda ()
		  (interactive)
		  (org-capture nil "a")))