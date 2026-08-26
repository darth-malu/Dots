;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; Fun
(package! yeetube)
(package! mpv)
;;; ORG
(package! olivetti)
(package! org-super-agenda)             ;TODO:
(package! org-auto-tangle)
(package! drag-stuff)
(package! org-fragtog)
(package! org-roam-ui)
(package! nov)                      ;For annotations? -org-noter

;; (package! org-transclusion)

;;; LSP / Dev
;; (package! jupyter)
;; (package! blacken)
;; (package! ein)
;; (package! code-cells)                   ; NOTE: use in depth - Jupyter NoteBooks replacement?
(package! direnv)
(package! tmr)
;; (package! exec-path-from-shell) ; NOTE use doom env lol
(package! qml-ts-mode
  :recipe (:host github :repo "xhcoding/qml-ts-mode" :files ("*.el")))
(package! prettier-js)
;; (package! astro-ts-mode)
(package! lsp-tailwindcss :recipe (:host github :repo "merrickluo/lsp-tailwindcss"))

;; (package! spotify)
;; (package! emms-player-spotify)
;; (package! obsidian)
(package! tldr)
(package! all-the-icons) ;TODO add desc
(package! elcord)
;; (package! xclip)
;; (package! codeium :recipe (:host github :repo "Exafunction/codeium.el"))
;; (package! wttrin)
;; (package! wttrin :recipe (:local-repo "lisp/wttrin"))
