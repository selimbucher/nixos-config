;;; init.el --- editor behaviour  -*- lexical-binding: t -*-
;;
;; VS Code habits: explorer on the left (C-b), terminal at the bottom (C-j),
;; tree-sitter colours, and the usual C-c/C-v/C-x/C-z/C-s keys. The look lives
;; in look.el.

(load (expand-file-name "look" user-emacs-directory) nil t)

;;; Files

(setq make-backup-files nil
      create-lockfiles nil
      auto-save-list-file-prefix (expand-file-name "emacs/auto-save/" (or (getenv "XDG_CACHE_HOME") "~/.cache"))
      custom-file (expand-file-name "emacs/custom.el" (or (getenv "XDG_STATE_HOME") "~/.local/state"))
      use-short-answers t
      confirm-kill-processes nil
      ring-bell-function #'ignore)

(global-auto-revert-mode 1)
(save-place-mode 1)
(setq recentf-auto-cleanup 'never)
(recentf-mode 1)

;;; Editing

(setq-default indent-tabs-mode nil
              tab-width 4
              truncate-lines t
              fill-column 80)

(setq scroll-conservatively 101
      scroll-margin 3
      mouse-wheel-progressive-speed nil
      select-enable-clipboard t)

(pixel-scroll-precision-mode 1)
(electric-pair-mode 1)
(show-paren-mode 1)
;; line numbers in every file, code or not
(add-hook 'find-file-hook #'display-line-numbers-mode)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

;;; Colours: tree-sitter modes for every language with a grammar

(require 'treesit-auto)
(setq treesit-auto-install nil
      treesit-font-lock-level 4)
(treesit-auto-add-to-auto-mode-alist 'all)
(global-treesit-auto-mode 1)
(add-to-list 'auto-mode-alist '("\\.nix\\'" . nix-ts-mode))

;;; Quick open, command palette and project search, VS Code style: a list
;;; that narrows as you type, in a panel at the top of the window

(require 'vertico)
(require 'vertico-posframe)
(require 'orderless)
(require 'marginalia)
(require 'consult)

(setq vertico-count 12
      vertico-cycle t
      vertico-resize nil
      ;; words in any order, each matching anywhere
      completion-styles '(orderless basic)
      completion-category-overrides '((file (styles basic partial-completion)))
      completion-ignore-case t
      read-file-name-completion-ignore-case t
      read-buffer-completion-ignore-case t
      vertico-count-format '("%-5s " . "%s/%s")
      vertico-posframe-border-width 1
      ;; type the search itself, no "#" in front
      consult-async-split-style 'none
      ;; results show the file under the cursor as you move through them
      consult-preview-key '(:debounce 0.15 any)
      consult-async-min-input 2)
(vertico-mode 1)
(vertico-posframe-mode 1)
(marginalia-mode 1)

(load (expand-file-name "popups" user-emacs-directory) nil t)

(defun vs-search ()
  "Search every file in the project, like VS Code's C-S-f.
With text selected, start with that text."
  (interactive)
  (let ((vertico-count-format nil))
   (minibuffer-with-setup-hook
       (lambda ()
         (setq popup--placeholder "Search in files")
         (add-hook 'post-command-hook #'popup--placeholder-update nil t)
         (popup--placeholder-update))
   (consult--grep "" #'consult--ripgrep-make-builder
                 (if-let* ((proj (project-current))) (project-root proj) default-directory)
                 (when (use-region-p)
                   (buffer-substring-no-properties (region-beginning) (region-end)))))))

;; The panel: centred, below the header, 60% of the window wide.
(setq vertico-posframe-poshandler
      (lambda (info)
        ;; posframe centres the text area, not the panel with its fringes
        (let ((pw (plist-get info :parent-frame-width))
              (w (+ (plist-get info :posframe-width) (* 2 (look--px 0.7)) 2)))
          (cons (/ (- pw w) 2) (look--px 2.4)))))
(setq vertico-posframe-size-function
      (lambda (buffer)
        (let* ((size (vertico-posframe-get-size buffer))
               (w (min 110 (round (* 0.6 (frame-width)))))
               ;; as tall as its results: the prompt line, then up to
               ;; vertico-count candidates
               (mini (active-minibuffer-window))
               (n (or (and mini (buffer-local-value 'vertico--total (window-buffer mini))) 0))
               (h (1+ (min vertico-count n))))
          (plist-put size :width w)
          (plist-put size :min-width w)
          (plist-put size :height h)
          (plist-put size :min-height h))))

;;; Right-click menus, as in VS Code

(defun vs-copy ()
  "Copy the selection and keep it selected, as VS Code does."
  (interactive)
  (kill-ring-save (region-beginning) (region-end))
  (setq deactivate-mark nil))

(defun vs--menu-point (event)
  "Select EVENT's window; move point there unless the click is in the selection."
  (let* ((posn (event-start event))
         (win (posn-window posn))
         (pt (posn-point posn)))
    (select-window win)
    (set-buffer (window-buffer win))
    (unless (and (use-region-p) pt (<= (region-beginning) pt (region-end)))
      (deactivate-mark)
      (when pt (goto-char pt)))))

(defun vs-context-menu (event)
  "The editor's right-click menu (the explorer has its own)."
  (interactive "e")
  (if (with-current-buffer (window-buffer (posn-window (event-start event)))
        (derived-mode-p 'treemacs-mode))
      (explorer-menu event)
    (vs--context-menu event)))

(defun vs--context-menu (event)
  (vs--menu-point event)
  (let ((sel (use-region-p)))
    (popup-menu
     (explorer--menu
      `(["Go to Symbol…" consult-imenu :keys "Ctrl+Shift+O"]
        "---"
        ["Cut" kill-region :active ,sel :keys "Ctrl+X"]
        ["Copy" vs-copy :active ,sel :keys "Ctrl+C"]
        ["Paste" yank :keys "Ctrl+V"]
        "---"
        ["Select All" mark-whole-buffer :keys "Ctrl+A"]
        ["Toggle Comment" comment-line :keys "Ctrl+/"]
        "---"
        ["Find…" isearch-forward :keys "Ctrl+F"]
        ["Search in Files…" vs-search :keys "Ctrl+Shift+F"]))
     event)))

(defun vs-terminal-menu (event)
  "The terminal's right-click menu."
  (interactive "e")
  (vs--menu-point event)
  (popup-menu
   (explorer--menu
    `(["Copy" kill-ring-save :active ,(use-region-p) :keys "Ctrl+Shift+C"]
      ["Paste" vterm-yank :keys "Ctrl+Shift+V"]
      "---"
      ["Clear" vterm-clear :keys "Ctrl+L"]
      ["Hide Terminal" vs-toggle-terminal :keys "Ctrl+J"]))
   event))

;;; Keys

;; C-c / C-x copy and cut when text is selected, C-v pastes, C-z undoes;
;; with nothing selected C-c and C-x still reach Emacs's own commands.
(setq cua-keep-region-after-copy t)
(cua-mode 1)

(defun vs-new-buffer ()
  "An empty, unnamed buffer, like File > New."
  (interactive)
  (switch-to-buffer (generate-new-buffer "untitled"))
  (text-mode))

(defun vs-move-line (n)
  "Move the current line, or the selected lines, N lines down."
  (let* ((beg (line-beginning-position))
         (end (line-beginning-position 2))
         (text (delete-and-extract-region beg end))
         (col (current-column)))
    (forward-line n)
    (let ((pos (point)))
      (insert text)
      (goto-char pos)
      (move-to-column col))))

(defvar-keymap vs-keys-mode-map
  "C-s"   #'save-buffer
  "C-S-s" #'write-file
  "C-o"   #'find-file
  "C-p"   #'vs-find-file
  "C-S-p" #'vs-command-palette
  "C-S-o" #'consult-imenu
  "C-r"   #'consult-recent-file
  "C-n"   #'vs-new-buffer
  "C-w"   #'kill-current-buffer
  "C-a"   #'mark-whole-buffer
  "C-f"   #'isearch-forward
  "C-S-f" #'vs-search
  "C-y"   #'undo-redo
  "C-S-z" #'undo-redo
  "C-/"   #'comment-line
  "C-<tab>"   #'next-buffer
  "C-S-<iso-lefttab>" #'previous-buffer
  "C-="   #'text-scale-increase
  "C-+"   #'text-scale-increase
  "C--"   #'text-scale-decrease
  "C-0"   (lambda () (interactive) (text-scale-set 0))
  "M-<up>"   (lambda () (interactive) (vs-move-line -1))
  "M-<down>" (lambda () (interactive) (vs-move-line 1))
  "C-b"   #'vs-toggle-explorer
  "C-j"   #'vs-toggle-terminal
  "<down-mouse-3>" #'ignore
  "<mouse-3>" #'vs-context-menu)

(define-minor-mode vs-keys-mode
  "VS Code's everyday shortcuts, above every major mode's own."
  :global t
  :keymap vs-keys-mode-map)
(vs-keys-mode 1)

;; C-f again finds the next match, C-S-f the previous one
(keymap-set isearch-mode-map "C-f" #'isearch-repeat-forward)
(keymap-set isearch-mode-map "C-S-f" #'isearch-repeat-backward)
(keymap-set isearch-mode-map "<escape>" #'isearch-cancel)
;; Escape closes prompts, like everywhere else
(keymap-set minibuffer-local-map "<escape>" #'abort-recursive-edit)
(keymap-global-set "<escape>" #'keyboard-quit)

;;; Explorer

(require 'treemacs)
(setq treemacs-width 30
      treemacs-width-is-initially-locked t
      treemacs-show-cursor nil
      treemacs-is-never-other-window t
      treemacs-no-png-images nil
      treemacs-user-mode-line-format 'none
      treemacs-persist-file (expand-file-name "emacs/treemacs-persist" (or (getenv "XDG_STATE_HOME") "~/.local/state"))
      treemacs-last-error-persist-file (expand-file-name "emacs/treemacs-errors" (or (getenv "XDG_STATE_HOME") "~/.local/state")))
(treemacs-follow-mode 1)
(treemacs-filewatch-mode 1)
(treemacs-fringe-indicator-mode -1)
(treemacs-git-mode 'simple)
(treemacs-hide-gitignored-files-mode 1)
;; clicks, dragging and file operations
(load (expand-file-name "explorer" user-emacs-directory) nil t)

(defun vs-toggle-explorer ()
  "Show or hide the explorer."
  (interactive)
  (pcase (treemacs-current-visibility)
    ('visible (delete-window (treemacs-get-local-window)))
    (_ (treemacs-select-window) (other-window 1))))

;; `emacs DIR` opens that folder in the explorer instead of a directory listing
;; Start: `emacs DIR` opens DIR in the explorer beside the start page, like
;; `code DIR`; `emacs FILE` just the file; plain `emacs` the start page.
;; after the window's frame is set up (look.el): during startup the
;; minibuffer's own frame is the selected one
(add-hook 'look-window-ready-hook
          (lambda ()
            (let ((dired (seq-find (lambda (b) (with-current-buffer b (derived-mode-p 'dired-mode)))
                                   (buffer-list)))
                  (files (seq-filter #'buffer-file-name (buffer-list))))
              (cond
               (dired
                (let ((dir (with-current-buffer dired default-directory)))
                  (kill-buffer dired)
                  (delete-other-windows)
                  (with-current-buffer (get-buffer-create "Welcome")
                    (setq default-directory dir))
                  (switch-to-buffer (look-welcome))
                  (let ((default-directory dir)
                        (inhibit-message t))
                    (treemacs-add-and-display-current-project-exclusively)
                    (other-window 1)
                    (look-welcome))))
               ((not files)
                (delete-other-windows)
                (switch-to-buffer (look-welcome)))))))

;;; Terminal

(require 'vterm)
(setq vterm-max-scrollback 10000
      vterm-kill-buffer-on-exit t)

;; the explorer keeps the full height; the terminal sits under the editor
(setq window-sides-vertical t)

(add-to-list 'display-buffer-alist
             '("\\*terminal\\*"
               (display-buffer-in-side-window)
               (side . bottom)
               (window-height . 0.3)
               (window-parameters (no-delete-other-windows . t))))

(defun vs-toggle-terminal ()
  "Show or hide the terminal panel, starting a shell the first time."
  (interactive)
  (let* ((buf (get-buffer "*terminal*"))
         (win (and buf (get-buffer-window buf))))
    (cond
     ((and win (eq win (selected-window))) (delete-window win))
     (win (select-window win))
     (t (if buf
            (select-window (display-buffer buf))
          (let ((default-directory (or (and (project-current) (project-root (project-current)))
                                       default-directory)))
            (select-window (display-buffer (save-window-excursion (vterm "*terminal*"))))))))))

;; The terminal gets every key except the panel toggles; copy and paste are
;; C-S-c / C-S-v there, as in kitty.
(add-hook 'vterm-mode-hook
          (lambda ()
            (setq-local vs-keys-mode nil)
            (setq-local cua-mode nil)
            (setq-local line-spacing 0.12)
            (look-panel-title "Terminal")))
(keymap-set vterm-mode-map "C-j" #'vs-toggle-terminal)
(keymap-set vterm-mode-map "C-b" #'vs-toggle-explorer)
(keymap-set vterm-mode-map "C-S-v" #'vterm-yank)
(keymap-set vterm-mode-map "C-S-c" #'kill-ring-save)
(keymap-set vterm-mode-map "<down-mouse-3>" #'ignore)
(keymap-set vterm-mode-map "<mouse-3>" #'vs-terminal-menu)
