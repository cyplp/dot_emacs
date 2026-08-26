;;; conf-jabber.el --- Messagerie XMPP -*- lexical-binding: t -*-

;;; Commentary:

;; Client XMPP.  Les comptes sont declares dans secret.el, hors depot.

;;; Code:

(use-package jabber
  :ensure t
  :commands (jabber-connect jabber-connect-all))

(provide 'conf-jabber)

;;; conf-jabber.el ends here
