;;; init.el -*- lexical-binding: t; -*-
;;      directory (for easy access to its source code).
(doom!
 :input
 ;;bidi              ; (tfel ot) thgir etirw uoy gnipleh
 ;;chinese
 ;;japanese
 ;;layout            ; auie,ctsrnm is the superior home row

 :completion
 ;; (company +tng +childframe)           ; the ultimate code completion backend ;NOTE deprecated in favor of corfu
 (corfu +orderless) ; complete with cap(f), cape and a flying feather!
 ;; (helm +childframe +icons +fuzzy )              ; the *other* search engine for love and life
 ;; ido               ; the other *other* search engine...
 ;; (ivy +childframe +icons) ; a search engine for love and life
 (vertico +icons)           ; the search engine of the future

 :ui
 ;; deft              ; notational velocity for Emacs
 doom              ; what makes DOOM look the way it does
 dashboard    ; a nifty splash screen for Emacs
 ;; doom-quit         ; DOOM quit-message prompts when you quit Emacs
 (emoji +unicode)              ; 🙂
 hl-todo           ; highlight TODO/FIXME/NOTE/DEPRECATED/HACK/REVIEW
 ;;indent-guides     ; highlighted indent columns
 (ligatures +extra)         ; ligatures and symbols to make your code pretty again
 ;; minimap           ; show a map of the code on the side
 modeline          ; snazzy, Atom-inspired modeline, plus API
 ;; nav-flash         ; blink cursor line after big motions
 ;; neotree           ; a project drawer, like NERDTree for vim
 ophints           ; highlight the region an operation acts on ; TODO read further
 (popup +all +defaults)   ; tame sudden yet inevitable temporary windows
 tabs              ; a tab bar for Emacs
 (treemacs)          ; a project drawer, like neotree but cooler TODO test further ; NOTE:  +lsp not with eglot
 ;; unicode           ; extended unicode support for various languages NOTE can cause issues with ligatures
 (vc-gutter +pretty) ; vcs diff in the fringe
 ;; vi-tilde-fringe   ; fringe tildes to mark beyond EOB
 (window-select +numbers)     ; visually switch windows
 workspaces        ; tab emulation, persistence & separate workspaces ;persp-mode
 ;; (smooth-scroll +interpolate)
 ;;zen               ; distraction-free coding or writing

 :editor
 (evil +everywhere); come to the dark side, we have cookies
 file-templates    ; auto-snippets for empty files ;TODO make this better then maybe use it
 fold              ; (nigh) universal code folding
 (format +onsave +lsp)  ; automated prettiness
 ;;god               ; run Emacs commands without modifier keys
 ;;lispy             ; vim for lisp, for people who don't like vim
 multiple-cursors  ; editing in many places at once
 ;; (objed +manual)             ; text object editing for the innocent ;TODO test this
 parinfer          ; turn lisp into python, sort of ;TODO DISABLE until needed in lisp files
 rotate-text       ; cycle region at point between text candidates eg false to true
 snippets          ; my elves. They type so I don't have to
 word-wrap         ; soft wrapping with language-aware indent

 :emacs
 (dired +icons)             ; making dired pretty [functional]
 electric          ; smarter, keyword-based electric-indent
 eww               ; the internet is gross
 (ibuffer +icons)  ; interactive buffer management
 (undo +tree)      ; persistent, smarter undo for your inevitable mistakes
 vc                ; version-control and Emacs, sitting in a tree

 :term
 eshell            ; the elisp shell that works everywhere
 ;; shell             ; simple shell REPL for Emacs
 ;; term              ; basic terminal emulator for Emacs
 vterm             ; the best terminal emulation in Emacs

 :checkers
 (syntax +icons +childframe) ; tasing you for every semicolon you forget ;TODO test if childframe needed and difference in behaviour
 (spell +aspell)
 ;; grammar           ; tasing grammar mistake every you make

 :tools
 ;; editorconfig      ; let someone else argue about tabs vs spaces TODO test this
 (eval +overlay)     ; run code, run (also, repls)
 (lookup +dictionary +offline)              ; navigate your code and its documentation
 (lsp +eglot +booster)               ; M-x vscode ; NOTE: peek does not work with eglot, booster only eglot for now
 magit
 ;; make              ; run make tasks from Emacs
 pdf               ; pdf enhancements
 ;; rgb ; create color str NOTE: deprecated??
 tree-sitter       ; syntax and parsing, sitting in a tree...
 direnv
 ;; (docker +tree-sitter +lsp)
 ;; (pass +auth)

 ;; ein ;; NOTE: deprecated infavor of code-cells.el
 ;; DISABLED tools
 ;; taskrunner        ;This module integrates taskrunner into Doom Emacs, which scraps runnable tasks from build systems like make, gradle, npm and the like.
 ;; upload            ; map local to remote projects via ssh/ftp
 ;;prodigy           ; FIXME managing external services & code builders
 ;;terraform         ; infrastructure as code
 ;; tmux              ; an API for interacting with tmux
 ;;ansible
 ;;biblio            ; Writes a PhD for you (citation needed)
 ;;collab            ; buffers with friends
 ;; ( debugger +lsp)          ; FIXME stepping through code, to help you add bugs

 :os
 (:if (featurep :system 'macos) macos)  ; improve compatibility with macOS
 (tty +osc)               ; improve the terminal Emacs experience

 :lang
 (cc +lsp +tree-sitter)         ; C > C++ == 1
 ;; (csharp +dotnet +lsp +tree-sitter)            ; unity, .NET, and mono shenanigans
 ;; (java +lsp +tree-sitter)       ; the poster child for carpal tunnel syndrome
 (markdown +grip +tree-sitter)          ; writing docs for people to ignore
 (nix +tree-sitter +lsp)               ; I hereby declare "nix geht mehr!"
 (org +noter +crypt +present +roam +pomodoro +contacts +journal +dragndrop +pandoc +pretty) ;TODO test crypt, journal, noter
 (python +lsp +pyright +tree-sitter)            ; beautiful is better than ugly
 (sh +lsp +tree-sitter)                ; she sells {ba,z,fi}sh shells on the C xor
 (web +lsp +tree-sitter)               ; the tubes - web/css mode
 (javascript +lsp +tree-sitter)        ; all(hope(abandon(ye(who(enter(here))))))
 data              ; config/data formats - csv/xml
 (latex +lsp +fold +cdlatex)             ; writing papers in Emacs has never been so fun
 (lua +lsp +tree-sitter)               ; one-based indices? one-based indices
 emacs-lisp        ; drown in parentheses
 (json +lsp +tree-sitter)              ; At least it ain't XML
 (qt +lsp +tree-sitter)                ; the 'cutest' gui framework ever
 (yaml +lsp +tree-sitter)              ; JSON, but readable
 ;; DISABLED :lang
 ;;agda              ; types of types of types of types...
 ;;beancount         ; mind the GAAP
 ;;clojure           ; java with a lisp
 ;;common-lisp       ; if you've seen one lisp, you've seen them all
 ;;coq               ; proofs-as-programs
 ;;crystal           ; ruby at the speed of c
 ;;(dart +flutter)   ; paint ui and not much else
 ;;dhall
 ;;elixir            ; erlang done right
 ;;elm               ; care for a cup of TEA?
 ;;erlang            ; an elegant language for a more civilized age
 ;;ess               ; emacs speaks statistics
 ;;factor
 ;;faust             ; dsp, but you get to keep your soul
 ;;fortran           ; in FORTRAN, GOD is REAL (unless declared INTEGER)
 ;;fsharp            ; ML stands for Microsoft's Language
 ;;fstar             ; (dependent) types and (monadic) effects and Z3
 ;;gdscript          ; the language you waited for
 ;;(go +lsp)         ; the hipster dialect
 ;;(graphql +lsp)    ; Give queries a REST
 ;;(haskell +lsp)    ; a language that's lazier than I am

 ;;hy                ; readability of scheme w/ speed of python
 ;;idris             ; a language you can depend on
 ;;julia             ; a better, faster MATLAB
 ;;kotlin            ; a better, slicker Java(Script)
 ;;lean              ; for folks with too much to prove
 ;;ledger            ; be audit you can be
 ;;nim               ; python + lisp at the speed of c
 ;;ocaml             ; an objective camel
 ;;php               ; perl's insecure younger brother
 ;;plantuml          ; diagrams for confusing people more
 ;; graphviz          ; diagrams for confusing yourself even more
 ;;purescript        ; javascript, but functional
 ;;racket            ; a DSL for DSLs
 ;;raku              ; the artist formerly known as perl6
 ;;rest              ; Emacs as a REST client
 ;;rst               ; ReST in peace

 ;;(rust +lsp)       ; Fe2O3.unwrap().unwrap().unwrap().unwrap()
 ;;scala             ; java, but good
 ;;(scheme +guile)   ; a fully conniving family of lisps
 ;;sml
 ;;solidity          ; do you need a blockchain? No.
 ;;swift             ; who asked for emoji variables?
 ;;terra             ; Earth and Moon in alignment for performance.
 ;;zig               ; C, but simpler

 :email
 ;; (mu4e +mbsync +org +gmail)
 ;;notmuch
 ;;(wanderlust +gmail)

 :app
 calendar
 ;; twitter ; TODO never works?
 ;; emms
 ;; everywhere        ; *leave* Emacs!? You must be joking
 irc               ; how neckbeards socialize
 (rss +org)        ; emacs as an RSS reader

 :config
 literate
 (default +bindings +gnupg +smartparens))


