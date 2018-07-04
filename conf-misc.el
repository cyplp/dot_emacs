
;; french calendar
(defvar calendar-day-name-array
  ["dim" "lun" "mar" "mer" "jeu" "ven" "sam"])
(defvar calendar-month-name-array
  ["janvier" "février" "mars" "avril" "mai" "juin"
   "juillet" "août" "septembre" "octobre" "novembre" "décembre"])

;; short anwser
(fset 'yes-or-no-p 'y-or-n-p)

(defun increment-number-at-point ()
      (interactive)
      (skip-chars-backward "0-9")
      (or (looking-at "[0-9]+")
          (error "No number at point"))
      (replace-match (number-to-string (1+ (string-to-number (match-string 0)))
				       )
		     )
      )
(global-set-key (kbd "C-+") 'increment-number-at-point)
