;;; +darthBinds.el -*- lexical-binding: t; -*-

(map! :g "C-c v" (cmd! (message "%s" "this wor")))

(map! :map evil-normal-state-map
           ;;;misc
      "M-;" 'save-buffer      
      "<mouse-8>" 'previous-buffer
      "<mouse-9>" 'next-buffer
      "C-M-o" 'consult-outline
      "M-n" 'avy-goto-char-2
      "C-e" 'evil-end-of-line ; clash with other settings - capitalise, org-metaright
      "C-a" 'beginning-of-line-text

          ;;; EOL, BOL
      "M-S-l" 'end-of-visual-line
      "M-S-h" 'beginning-of-visual-line

          ;;; insert newline below/above
      "M-o" '+evil/insert-newline-below
      "M-O" '+evil/insert-newline-above

      "C-'" 'olivetti-mode

      :map evil-insert-state-map
      "M-/" '#'org-comment-dwim 
      "M-;" 'nil                 ;Unmap default org-comment-dwim

      :map doom-leader-map
      "to" 'hl-todo-occur
      "I" 'ielm
      "SPC" 'ace-window)

