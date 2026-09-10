;;; conf-jabber.el --- XMPP messaging -*- lexical-binding: t -*-

;;; Commentary:

;; XMPP client.  Accounts are declared in secret.el, outside the repository.

;;; Code:

(use-package jabber
  :ensure t
  :commands (jabber-connect jabber-connect-all))

(provide 'conf-jabber)

;;; conf-jabber.el ends here
