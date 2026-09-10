;;; conf-org-emphasis.el --- org emphasis on the active region -*- lexical-binding: t -*-

;;; Commentary:

;; Typing an org emphasis marker while a region is active wraps that region
;; with the marker: selecting "long sentence" then typing "*" produces
;; "*long sentence*".
;;
;; That gesture had no useful effect until now: the character was simply
;; inserted at point and the selection was lost. The only remaining way was
;; `C-c C-x C-f', which then asks for the marker again in the minibuffer.
;;
;; Since `delete-selection-mode' was enabled in init.el, doing nothing would be
;; worse still: the marker would plainly replace the selected text. As the
;; command defined here does not carry the `delete-selection' property, it
;; escapes that replacement and keeps control of the region.
;;
;; The wrapping itself is delegated to `org-emphasize': it already knows how to
;; strip a pre-existing emphasis and to add the guard spaces that
;; `org-emphasis-regexp-components' requires. This file only adds what is
;; missing around it — trimming the edges, detecting the context and binding
;; the keys.

;;; Code:

(require 'org)
(require 'org-element)

(defconst my-org-emphasis-inert-elements
  '(src-block example-block export-block comment-block comment
    fixed-width latex-environment keyword)
  "Types of org elements where emphasis markup makes no sense.
Wrapping an expression inside a code block would inject characters that the
source language interprets, without ever producing any formatting.")

(defconst my-org-emphasis-boundary-characters " \t\n\r"
  "Characters excluded from the edges of a selection before wrapping.
The org grammar rejects a marker adjacent to whitespace: \"*text *\" stays
plain text, markers visible. Trimming the selection is therefore what makes
the emphasis actually take effect.")

(defun my-org-emphasis-inert-context-p (position)
  "Non-nil when POSITION is in an org context where no emphasis is possible.
The context is asked of the org parser rather than of a homemade regular
expression, so as to stay correct on nested blocks."
  (memq (org-element-type (org-element-at-point position))
        my-org-emphasis-inert-elements))

(defun my-org-emphasis-region-bounds ()
  "Bounds of the active region narrowed down to its non-blank content.
Return a cons (START . END), or nil when the region contains only whitespace:
there is then nothing to wrap."
  (let ((start (region-beginning))
        (end (region-end)))
    (save-excursion
      (goto-char start)
      (skip-chars-forward my-org-emphasis-boundary-characters end)
      (setq start (point))
      (goto-char end)
      (skip-chars-backward my-org-emphasis-boundary-characters start)
      (setq end (point)))

    (when (< start end)
      (cons start end))))

(defun my-org-emphasize-region-or-self-insert (repetitions)
  "Wrap the active region with the typed marker, otherwise insert it.
REPETITIONS is the prefix argument, passed to `org-self-insert-command' when
no wrapping happens.

The fallback goes through `org-self-insert-command' and not through
`self-insert-command': org hooks field blanking and table realignment onto
its own command, which the global version would lose."
  (interactive "p")
  (let ((bounds (and (org-region-active-p)
                     (not (my-org-emphasis-inert-context-p (region-beginning)))
                     (my-org-emphasis-region-bounds))))
    (if (null bounds)
        (org-self-insert-command repetitions)

      (set-mark (car bounds))
      (goto-char (cdr bounds))
      (org-emphasize last-command-event))))

(defun my-org-emphasis-bind-markers ()
  "Bind each marker of `org-emphasis-alist' in `org-mode-map'.
The list of characters is not frozen here: customizing `org-emphasis-alist'
stays consistent with the active keys.

The binding is on `org-mode-map' and not on the global keymap: the modes
derived from org-mode inherit it without any extra declaration, and non-org
buffers are never affected. Binding the character directly takes precedence
over the `self-insert-command' remapping to `org-self-insert-command' set by
org, which the branch without a region replays."
  (dolist (emphasis org-emphasis-alist)
    (define-key org-mode-map (car emphasis)
                #'my-org-emphasize-region-or-self-insert)))

(my-org-emphasis-bind-markers)

(provide 'conf-org-emphasis)

;;; conf-org-emphasis.el ends here
