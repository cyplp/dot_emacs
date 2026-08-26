;;; conf-treesit.el --- Modes majeurs tree-sitter -*- lexical-binding: t -*-

;;; Commentary:

;; Emacs 30 embarque un mode tree-sitter pour la plupart des langages utilises
;; ici.  Ces modes analysent reellement la syntaxe au lieu de l'approcher par
;; expressions regulieres : la coloration reste juste dans les chaines et les
;; imbrications, l'indentation suit la grammaire, et `imenu' / le repliage
;; deviennent fiables.  Ils remplacent plusieurs paquets MELPA non maintenus
;; (go-mode, rust-mode, lua-mode, typescript-mode, csharp-mode).
;;
;; Deux precautions structurent ce fichier.
;;
;; 1. Les revisions de grammaires sont epinglees.  Emacs 30.1 lit les ABI 13 a
;;    14 (voir `treesit-library-abi-version'), or la plupart des grammaires ont
;;    bascule en ABI 15 courant 2025 : compiler la branche par defaut produit
;;    une bibliotheque qui se compile sans erreur mais refuse de se charger.
;;    Chaque revision listee ici a ete verifiee a 14 ou moins.
;;
;; 2. Rien n'est active sans grammaire.  Une grammaire absente ou illisible
;;    laisse le mode classique en place plutot que d'ouvrir le fichier en
;;    `fundamental-mode'.

;;; Code:

(require 'treesit)

(setq treesit-language-source-alist
      '((bash       "https://github.com/tree-sitter/tree-sitter-bash"       "v0.23.3")
        (c-sharp    "https://github.com/tree-sitter/tree-sitter-c-sharp"    "v0.23.1")
        (css        "https://github.com/tree-sitter/tree-sitter-css"        "v0.23.2")
        (dockerfile "https://github.com/camdencheek/tree-sitter-dockerfile" "v0.2.0")
        (go         "https://github.com/tree-sitter/tree-sitter-go"         "v0.23.4")
        (gomod      "https://github.com/camdencheek/tree-sitter-go-mod"     "v1.1.0")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "v0.23.1")
        (json       "https://github.com/tree-sitter/tree-sitter-json"       "v0.24.8")
        (lua        "https://github.com/tree-sitter-grammars/tree-sitter-lua" "v0.3.0")
        (python     "https://github.com/tree-sitter/tree-sitter-python"     "v0.23.6")
        (rust       "https://github.com/tree-sitter/tree-sitter-rust"       "v0.23.3")
        (toml       "https://github.com/tree-sitter/tree-sitter-toml"       "v0.5.1")
        (tsx        "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2" "tsx/src")
        (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2" "typescript/src")
        (yaml       "https://github.com/ikatyang/tree-sitter-yaml"          "v0.5.0")))

(defconst my-treesit-major-modes
  '((python     python-ts-mode     python-mode    nil)
    (go         go-ts-mode         nil            "\\.go\\'")
    (gomod      go-mod-ts-mode     nil            "\\(?:\\`\\|/\\)go\\.mod\\'")
    (rust       rust-ts-mode       nil            "\\.rs\\'")
    (yaml       yaml-ts-mode       yaml-mode      "\\.ya?ml\\'")
    (json       json-ts-mode       json-mode      "\\.json\\'")
    (toml       toml-ts-mode       conf-toml-mode "\\.toml\\'")
    (dockerfile dockerfile-ts-mode nil            "\\(?:\\`\\|/\\)\\(?:Containerfile\\|Dockerfile\\)\\(?:\\.[^/]*\\)?\\'")
    (bash       bash-ts-mode       sh-mode        nil)
    (css        css-ts-mode        css-mode       nil)
    (javascript js-ts-mode         (js-mode javascript-mode) nil)
    (typescript typescript-ts-mode nil            "\\.ts\\'")
    (tsx        tsx-ts-mode        nil            "\\.tsx\\'")
    (c-sharp    csharp-ts-mode     csharp-mode    nil)
    (lua        lua-ts-mode        nil            "\\.lua\\'"))
  "Correspondance entre grammaire, mode tree-sitter et mode classique.

Chaque entree vaut (GRAMMAIRE TS-MODE MODE-CLASSIQUE REGEXP-FICHIER).

MODE-CLASSIQUE, quand il est non nil, designe le mode qu'Emacs choisirait
sans tree-sitter ; il est alors redirige via `major-mode-remap-alist', ce qui
preserve les regles d'`auto-mode-alist' existantes et reste reversible.  Une
liste est acceptee, pour les langages qu'`auto-mode-alist' designe tantot par
un nom tantot par son alias — `js-mode' et `javascript-mode' pointent sur la
meme fonction, mais le remappage compare les symboles.

REGEXP-FICHIER couvre le cas inverse : les modes tree-sitter ne s'inscrivent
pas eux-memes dans `auto-mode-alist', et sans paquet MELPA pour le faire une
extension comme .go ou .rs n'a plus aucun mode associe.  Le cas de go.mod est
le plus surprenant : Emacs l'associe par defaut a `m2-mode', c'est-a-dire
Modula-2.

Certaines entrees fixent les deux champs. C'est necessaire quand un paquet
encore installe garde un autoload sur la meme extension — json-mode sur .json,
go-mode sur go.mod : le seul remappage ne suffirait pas, puisque c'est le
paquet, et non le mode natif, qu'`auto-mode-alist' designerait.")

(defun my-treesit-missing-grammars ()
  "Liste des grammaires declarees mais non utilisables.
Une grammaire compilee dans une ABI incompatible est signalee ici au meme
titre qu'une grammaire absente : dans les deux cas le mode tree-sitter ne
peut pas demarrer."
  (seq-remove (lambda (language)
                (treesit-ready-p language t))
              (mapcar #'car treesit-language-source-alist)))

(defun my-treesit-install-missing-grammars ()
  "Compiler et installer les grammaires manquantes.
Necessite git et un compilateur C. L'operation prend plusieurs minutes au
premier lancement ; elle n'a rien a faire ensuite."
  (interactive)
  (let ((missing (my-treesit-missing-grammars)))
    (if (null missing)
        (message "Toutes les grammaires tree-sitter sont installees")
      (dolist (language missing)
        (message "Installation de la grammaire %s..." language)
        (treesit-install-language-grammar language))
      (message "Grammaires installees : %s" missing))))

(defun my-treesit-activate-modes ()
  "Router chaque langage vers son mode tree-sitter quand la grammaire repond.
Les langages sans grammaire utilisable gardent leur mode classique, ce qui
evite qu'une grammaire cassee rende des fichiers entiers illisibles."
  (dolist (entry my-treesit-major-modes)
    (let ((language (nth 0 entry))
          (treesit-mode (nth 1 entry))
          (classic-mode (nth 2 entry))
          (file-pattern (nth 3 entry)))

      (when (and (treesit-ready-p language t)
                 (fboundp treesit-mode))
        (dolist (replaced-mode (if (listp classic-mode) classic-mode (list classic-mode)))
          (when replaced-mode
            (add-to-list 'major-mode-remap-alist (cons replaced-mode treesit-mode))))
        (when file-pattern
          (add-to-list 'auto-mode-alist (cons file-pattern treesit-mode)))))))

(my-treesit-activate-modes)

;; Niveau de decoration maximal : les modes tree-sitter distinguent alors les
;; appels de fonction, les proprietes et les operateurs, la ou le niveau 3 par
;; defaut s'arrete aux mots-cles et aux chaines.
(setq treesit-font-lock-level 4)

;; Signale une seule fois ce qui manque, sans rien installer a l'insu de
;; l'utilisateur : compiler des grammaires telecharge du code et fait tourner
;; un compilateur, ce qui n'a pas sa place dans un demarrage silencieux.
(add-hook 'emacs-startup-hook
          (lambda ()
            (let ((missing (my-treesit-missing-grammars)))
              (when missing
                (message "Grammaires tree-sitter manquantes (%s) : M-x my-treesit-install-missing-grammars"
                         (mapconcat #'symbol-name missing " "))))))

(provide 'conf-treesit)

;;; conf-treesit.el ends here
