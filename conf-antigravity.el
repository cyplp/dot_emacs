;;; conf-antigravity.el --- Google Antigravity assistant -*- lexical-binding: t -*-

;;; Commentary:

;; Integration of the `agy' CLI (Google Antigravity) into Emacs.
;;
;; The integration does not reach the editor, where the one in conf-claude.el
;; does: Antigravity only speaks its own IDE protocol, reserved for its VS Code
;; extension, and no Emacs package implements it. No ediff diff, no MCP tools on
;; the Emacs side — but one session per project, a side window, sending a
;; reference to the current file and the org-babel blocks of
;; `ob-antigravity.el', which covers daily use.
;;
;; The terminal stays `eat', already installed by conf-claude.el: the CLI is a
;; full-screen application that `shell' or `comint' cannot display.

;;; Code:

(require 'project)

;; `eat' is only loaded on the first call: without these declarations the
;; compiler reports unknown symbols.
(declare-function eat-make "eat" (name program &optional startfile &rest switches))
(declare-function eat-term-send-string "eat" (terminal string))
(defvar eat-terminal)

;; --- Settings ---------------------------------------------------------------

(defgroup antigravity nil
  "Google Antigravity assistant in an Emacs terminal."
  :group 'tools)

(defcustom antigravity-cli-path "agy"
  "Path of the Antigravity CLI executable.
The ~/.local/bin directory it installs into is already added to `exec-path'
by conf-claude.el."
  :type 'string
  :group 'antigravity)

(defcustom antigravity-window-width 0.4
  "Width of the session window, as a fraction of the frame."
  :type 'number
  :group 'antigravity)

;; --- Session ----------------------------------------------------------------

(defun antigravity--project-directory ()
  "Return the root of the current project, or `default-directory'."
  (if-let* ((current-project (project-current)))
      (project-root current-project)
    default-directory))

(defun antigravity--session-name ()
  "Return the session name associated with the current project.
One session per project: two repositories open at the same time must share
neither conversation nor working directory."
  (format "agy: %s"
          (file-name-nondirectory
           (directory-file-name (antigravity--project-directory)))))

(defun antigravity--session-buffer ()
  "Return the session buffer of the current project, or nil.
`eat-make' surrounds the name with asterisks; we rebuild the same shape
rather than storing it in a variable that has to be kept up to date."
  (get-buffer (concat "*" (antigravity--session-name) "*")))

(defun antigravity--display-session (session-buffer)
  "Display SESSION-BUFFER in a side window and return that window.
A side window survives the layout changes of the rest of the frame: the
conversation does not vanish on the first `other-window'."
  (display-buffer session-buffer
                  `((display-buffer-in-side-window)
                    (side . right)
                    (window-width . ,antigravity-window-width))))

;;;###autoload
(defun antigravity-start ()
  "Start the Antigravity session of the current project, or join it."
  (interactive)
  ;; conf-claude.el only autoloads `eat' for its own commands: here the load is
  ;; explicit, and deferred until the first call.
  (require 'eat)
  ;; The CLI inherits the current directory; it must start at the root so that
  ;; its context covers the whole repository and not just the open file.
  (let* ((default-directory (antigravity--project-directory))
         (session-buffer (eat-make (antigravity--session-name)
                                   antigravity-cli-path)))
    (select-window (antigravity--display-session session-buffer))))

;;;###autoload
(defun antigravity-toggle ()
  "Show or hide the session window without stopping the CLI."
  (interactive)
  (let* ((session-buffer (antigravity--session-buffer))
         (session-window (and session-buffer
                              (get-buffer-window session-buffer))))
    (cond
     ((null session-buffer) (antigravity-start))
     (session-window (delete-window session-window))
     (t (antigravity--display-session session-buffer)))))

;; --- Reference to the current code ------------------------------------------

(defun antigravity--current-reference ()
  "Return a textual reference to the active region or the current line.
The path is relative to the project root, the only form the CLI resolves from
its own working directory.  No `@' prefix: in the TUI that character opens a
file selector that would swallow the rest of the string."
  (let* ((project-directory (antigravity--project-directory))
         (path (if buffer-file-name
                   (file-relative-name buffer-file-name project-directory)
                 (buffer-name)))
         (first-line (line-number-at-pos (if (use-region-p)
                                             (region-beginning)
                                           (point))))
         (last-line (line-number-at-pos (if (use-region-p)
                                            (region-end)
                                          (point)))))
    (if (= first-line last-line)
        (format "%s:%d" path first-line)
      (format "%s:%d-%d" path first-line last-line))))

;;;###autoload
(defun antigravity-insert-reference ()
  "Send the session a reference to the region or the current line.
The reference is only inserted, without submitting: the question is still to
be written around it."
  (interactive)
  (let ((reference (antigravity--current-reference)))
    (unless (antigravity--session-buffer)
      (antigravity-start))
    (let ((session-buffer (antigravity--session-buffer)))
      (with-current-buffer session-buffer
        (eat-term-send-string eat-terminal (concat reference " ")))
      (select-window (antigravity--display-session session-buffer)))))

;; --- Shortcuts --------------------------------------------------------------

;; F5 and not F2 — taken by conf-claude.el — nor F3/F4, reserved for keyboard
;; macros, nor F7 to F10, taken over by conf-python.el.  Same layout as for
;; Claude: bare key to open, S- to toggle, C- to quote.
(global-set-key (kbd "<f5>") #'antigravity-start)
(global-set-key (kbd "<S-f5>") #'antigravity-toggle)
(global-set-key (kbd "<C-f5>") #'antigravity-insert-reference)

;; --- Org blocks -------------------------------------------------------------

;; `ob-antigravity' makes `antigravity' an org-babel language: the block body
;; is a prompt, `C-c C-c' sends it to the CLI and the answer becomes the
;; result.
(with-eval-after-load 'org
  (require 'ob-antigravity)

  ;; The prompt and the answer are markdown: `org-edit-special' opens the block
  ;; in markdown-mode rather than in `fundamental-mode'.
  (add-to-list 'org-src-lang-modes '("antigravity" . markdown))

  ;; `<ag' then TAB inserts the block.
  (add-to-list 'org-structure-template-alist '("ag" . "src antigravity")))

(provide 'conf-antigravity)

;;; conf-antigravity.el ends here
