;;; look.el --- fonts, colours, explorer  -*- lexical-binding: t -*-
;;
;; One theme, `look', built from a palette. `look-variant' picks the palette
;; family; light or dark follows the desktop (org.freedesktop.appearance
;; color-scheme over the settings portal, pushed by D-Bus, no polling).
;; LOOK_VARIANT / LOOK_APPEARANCE / LOOK_FONT override them, for screenshots.
;;
;; Every pixel size is a multiple of the code font's line height (`look--u'),
;; so the proportions hold at any scale.

(require 'cl-lib)
(require 'color)
(require 'svg)

(defvar look-variant (intern (or (getenv "LOOK_VARIANT") "whitesur"))
  "Palette family, a key of `look-variants'.")

(defconst look-variants
  ;; bg: editor, side: explorer and echo area, faint: dividers,
  ;; dim: line numbers and secondary text.
  '((xcode
     :mono "Geist Mono" :mono-height 115 :ui "Inter" :ui-height 105
     :light (:bg "#ffffff" :side "#f5f5f7" :fg "#1d1d1f" :dim "#a1a1a6" :faint "#e2e2e5"
             :region "#b4d7ff" :accent "#0a64e1" :cursor "#0a64e1"
             :kw "#9b2393" :str "#c41a16" :com "#5d6c79" :fn "#0f68a0" :call "#326d74"
             :type "#0b4f79" :const "#1c00cf" :num "#1c00cf" :prop "#326d74" :pre "#643820"
             :red "#d12f1b" :green "#248a3d" :yellow "#b25000" :blue "#0f68a0"
             :magenta "#ad3da4" :cyan "#1b8599")
     :dark (:bg "#1f1f24" :side "#29292e" :fg "#dfdfe0" :dim "#6c6c72" :faint "#39393e"
            :region "#3f4b63" :accent "#3d8bff" :cursor "#dfdfe0"
            :kw "#fc5fa3" :str "#fc6a5d" :com "#7f8c98" :fn "#41a1c0" :call "#67b7a4"
            :type "#5dd8ff" :const "#d0bf69" :num "#d0bf69" :prop "#67b7a4" :pre "#fd8f3f"
            :red "#fc6a5d" :green "#67b7a4" :yellow "#d0bf69" :blue "#41a1c0"
            :magenta "#fc5fa3" :cyan "#5dd8ff"))

    (whitesur
     :mono "JetBrains Mono" :mono-height 105 :ui "Inter" :ui-height 105
     :light (:bg "#ffffff" :side "#f6f6f6" :fg "#262626" :dim "#a8a8a8" :faint "#e4e4e4"
             :region "#c9dcf9" :accent "#0a64e1" :cursor "#0a64e1"
             :kw "#0a64e1" :str "#1a8a3a" :com "#9a9a9a" :fn "#7c3aa6" :call "#262626"
             :type "#b35900" :const "#b35900" :num "#b35900" :prop "#4d4d4d" :pre "#9a9a9a"
             :red "#e0453a" :green "#1a8a3a" :yellow "#b35900" :blue "#0a64e1"
             :magenta "#7c3aa6" :cyan "#0a8a9a")
     :dark (:bg "#232327" :side "#2e2e32" :fg "#e8e8e8" :dim "#6a6a70" :faint "#3b3b40"
            :region "#264a80" :accent "#3d8bff" :cursor "#3d8bff"
            :kw "#5ca3ff" :str "#7ccf8a" :com "#808086" :fn "#c89bf0" :call "#e8e8e8"
            :type "#f0a35e" :const "#f0a35e" :num "#f0a35e" :prop "#bdbdc2" :pre "#808086"
            :red "#ff6b5e" :green "#7ccf8a" :yellow "#f0c25e" :blue "#5ca3ff"
            :magenta "#c89bf0" :cyan "#5ed0d8"))

    ;; Nicolas Rougier's N Λ N O: almost monochrome; weight and one accent
    ;; carry the structure.
    (nano
     :mono "Roboto Mono" :mono-height 105 :ui "Inter" :ui-height 105
     :light (:bg "#ffffff" :side "#f7f8f9" :fg "#37474f" :dim "#b0bec5" :faint "#e6eaec"
             :region "#e3e8eb" :accent "#673ab7" :cursor "#37474f"
             :kw "#37474f" :str "#673ab7" :com "#9fb0b8" :fn "#263238" :call "#37474f"
             :type "#37474f" :const "#673ab7" :num "#673ab7" :prop "#37474f" :pre "#9fb0b8"
             :bold (:kw :fn :type)
             :red "#ff6f00" :green "#673ab7" :yellow "#e0822f" :blue "#37474f"
             :magenta "#673ab7" :cyan "#90a4ae")
     :dark (:bg "#2e3440" :side "#353c4a" :fg "#eceff4" :dim "#677691" :faint "#434c5e"
            :region "#434c5e" :accent "#81a1c1" :cursor "#eceff4"
            :kw "#eceff4" :str "#81a1c1" :com "#7b88a1" :fn "#ffffff" :call "#eceff4"
            :type "#eceff4" :const "#81a1c1" :num "#81a1c1" :prop "#d8dee9" :pre "#7b88a1"
            :bold (:kw :fn :type)
            :red "#d08770" :green "#a3be8c" :yellow "#ebcb8b" :blue "#81a1c1"
            :magenta "#b48ead" :cyan "#88c0d0"))

    ;; GitHub's Primer code colours
    (github
     :mono "IBM Plex Mono" :mono-height 105 :ui "Inter" :ui-height 105
     :light (:bg "#ffffff" :side "#f6f8fa" :fg "#1f2328" :dim "#8c959f" :faint "#dde2e7"
             :region "#c8e1ff" :accent "#0969da" :cursor "#0969da"
             :kw "#cf222e" :str "#0a3069" :com "#6e7781" :fn "#8250df" :call "#8250df"
             :type "#953800" :const "#0550ae" :num "#0550ae" :prop "#0550ae" :pre "#cf222e"
             :red "#cf222e" :green "#1a7f37" :yellow "#9a6700" :blue "#0969da"
             :magenta "#8250df" :cyan "#1b7c83")
     :dark (:bg "#0d1117" :side "#151b23" :fg "#e6edf3" :dim "#6e7681" :faint "#262c36"
            :region "#1f3a5f" :accent "#4493f8" :cursor "#4493f8"
            :kw "#ff7b72" :str "#a5d6ff" :com "#8b949e" :fn "#d2a8ff" :call "#d2a8ff"
            :type "#ffa657" :const "#79c0ff" :num "#79c0ff" :prop "#79c0ff" :pre "#ff7b72"
            :red "#ff7b72" :green "#7ee787" :yellow "#e3b341" :blue "#79c0ff"
            :magenta "#d2a8ff" :cyan "#56d4dd"))))

(defvar look-appearance nil "Current appearance, `light' or `dark'.")
(defvar look--palette nil "The palette in use.")

(deftheme look "Fonts and colours from look.el.")

(defface look-sidebar '((t)) "The explorer's background and text.")
(defface look-sidebar-header '((t)) "The explorer's empty header, level with the editor's.")
(defface look-pill '((t)) "The explorer's selected row.")
(defface look-hover '((t)) "The explorer's row under the pointer.")
(defface look-sidebar-dim '((t)) "The explorer's ellipsis for names cut short.")
(defface look-nothing '((t)) "No attributes at all, for hiding a face by remapping.")
(defface look-crumb '((t)) "Parent folders in the breadcrumb.")
(defface look-crumb-current '((t)) "The file in the breadcrumb.")
(defface look-status '((t)) "Position and language, right of the breadcrumb.")
(defface look-panel-title '((t)) "The terminal panel's title.")
(defface look-welcome '((t)) "The start page's text.")
(defface look-panel-header '((t)) "The terminal panel's header, a hairline on top.")
(defface look-echo-text '((t)) "Messages in the echo area.")
(defface look-echo-side '((t)) "The explorer's colour, carried down through the echo area.")

(defun look--mix (a b amount)
  "Colour AMOUNT of the way from A to B."
  (apply #'color-rgb-to-hex
         (append (cl-mapcar (lambda (x y) (+ x (* amount (- y x))))
                            (color-name-to-rgb a) (color-name-to-rgb b))
                 '(2))))

(defun look--u ()
  "The layout unit: the code font's height in pixels."
  (frame-char-height))

(defun look--px (factor)
  (max 1 (round (* factor (look--u)))))

(defun look--faces (v p)
  "Face specs for variant plist V with palette P."
  (cl-flet* ((c (k) (plist-get p k))
             (syn (k) (append (list :foreground (c k))
                              (when (memq k (plist-get p :bold)) '(:weight semibold)))))
    (let* ((mono (plist-get v :mono))
           (ui (plist-get v :ui))
           (ui-h (plist-get v :ui-height))
           (pad (look--px 0.42))
           (bar (lambda (bg) `(:family ,ui :height ,ui-h :weight regular :background ,bg :foreground ,(c :dim)
                               :box (:line-width (1 . ,pad) :color ,bg) :underline nil :overline nil)))
           (header (funcall bar (c :bg))))
      `((default (:family ,mono :height ,(plist-get v :mono-height) :weight regular
                  :background ,(c :bg) :foreground ,(c :fg)))
        (fixed-pitch (:family ,mono))
        (fixed-pitch-serif (:family ,mono))
        (variable-pitch (:family ,ui))
        (cursor (:background ,(c :cursor)))
        (region (:background ,(c :region) :extend t))
        (secondary-selection (:background ,(look--mix (c :bg) (c :region) 0.5)))
        (highlight (:background ,(look--mix (c :bg) (c :fg) 0.06)))
        (hl-line (:background ,(look--mix (c :bg) (c :fg) 0.035) :extend t))
        (fringe (:background ,(c :bg) :foreground ,(c :dim)))
        (vertical-border (:foreground ,(c :faint)))
        (window-divider (:foreground ,(c :faint)))
        (window-divider-first-pixel (:foreground ,(c :faint)))
        (window-divider-last-pixel (:foreground ,(c :faint)))
        (internal-border (:background ,(c :bg)))
        (child-frame-border (:background ,(c :faint)))
        (line-number (:foreground ,(look--mix (c :bg) (c :dim) 0.8) :background ,(c :bg)))
        (line-number-current-line (:foreground ,(c :fg) :background ,(c :bg)))
        (mode-line (:height 0.1 :background ,(c :bg) :box nil :overline nil :underline nil))
        (mode-line-inactive (:inherit mode-line))
        (mode-line-active (:inherit mode-line))
        (header-line ,header)
        (header-line-active ,header)
        (header-line-inactive ,header)
        (look-crumb (:foreground ,(c :dim)))
        (look-crumb-current (:foreground ,(c :fg)))
        (look-status (:inherit header-line :foreground ,(c :dim)))
        (look-panel-title (:foreground ,(c :dim) :weight semibold :height 0.9))
        (look-panel-header (,@header :overline ,(c :faint)))
        (look-welcome (:family ,ui :height ,ui-h :background ,(c :bg) :foreground ,(c :fg)))
        (look-echo-text (:family ,ui :height ,ui-h :foreground ,(c :fg)))
        (look-echo-side (:background ,(c :side) :foreground ,(c :side)))
        (minibuffer-prompt (:family ,ui :height ,ui-h :foreground ,(c :fg)))
        (help-key-binding (:family ,mono :foreground ,(c :fg) :background ,(c :side)
                           :box (:line-width (1 . -1) :color ,(c :faint))))
        (link (:foreground ,(c :accent) :underline (:color ,(look--mix (c :bg) (c :accent) 0.4))))
        (button (:inherit link))
        (shadow (:foreground ,(c :dim)))
        (success (:foreground ,(c :green)))
        (warning (:foreground ,(c :yellow)))
        (error (:foreground ,(c :red)))
        (isearch (:background ,(c :accent) :foreground "#ffffff"))
        (isearch-fail (:foreground ,(c :red)))
        (lazy-highlight (:background ,(look--mix (c :bg) (c :yellow) 0.25)))
        (match (:background ,(look--mix (c :bg) (c :yellow) 0.25)))
        (show-paren-match (:background ,(look--mix (c :bg) (c :accent) 0.18)))
        (show-paren-mismatch (:background ,(look--mix (c :bg) (c :red) 0.3)))
        (completions-common-part (:foreground ,(c :accent)))
        (completions-first-difference (:weight semibold))
        (trailing-whitespace (:background ,(look--mix (c :bg) (c :red) 0.2)))

        (vertico-current (:background ,(look--mix (c :bg) (c :accent) 0.14) :extend t))
        (vertico-posframe (:background ,(c :bg)))
        (vertico-posframe-border (:background ,(look--mix (c :bg) (c :fg) 0.2)))
        (vertico-group-title (:foreground ,(c :fg)))
        (vertico-group-separator (:foreground ,(c :faint)))
        (orderless-match-face-0 (:foreground ,(c :accent) :weight semibold))
        (orderless-match-face-1 (:foreground ,(c :magenta) :weight semibold))
        (orderless-match-face-2 (:foreground ,(c :green) :weight semibold))
        (orderless-match-face-3 (:foreground ,(c :yellow) :weight semibold))
        (marginalia-documentation (:foreground ,(c :dim)))
        (completions-annotations (:foreground ,(c :dim)))
        ;; also a search group's title when the file is at the root (vertico
        ;; shows the candidate's text then): styled as those titles
        (consult-file (:inherit popup-name :weight medium :foreground ,(c :fg)))
        (consult-line-number (:foreground ,(c :dim)))
        (consult-line-number-prefix (:foreground ,(c :dim)))
        (consult-highlight-match (:foreground ,(c :accent) :weight semibold))
        (consult-preview-line (:background ,(look--mix (c :bg) (c :yellow) 0.12) :extend t))
        (consult-preview-match (:background ,(look--mix (c :bg) (c :yellow) 0.3)))

        (font-lock-keyword-face ,(syn :kw))
        (font-lock-builtin-face ,(syn :kw))
        (font-lock-string-face ,(syn :str))
        (font-lock-doc-face (:foreground ,(c :com) :slant italic))
        (font-lock-comment-face (:foreground ,(c :com) :slant italic))
        (font-lock-comment-delimiter-face (:inherit font-lock-comment-face))
        (font-lock-function-name-face ,(syn :fn))
        (font-lock-function-call-face ,(syn :call))
        (font-lock-type-face ,(syn :type))
        (font-lock-constant-face ,(syn :const))
        (font-lock-number-face ,(syn :num))
        (font-lock-variable-name-face (:foreground ,(c :fg)))
        (font-lock-variable-use-face (:foreground ,(c :fg)))
        (font-lock-property-name-face ,(syn :prop))
        (font-lock-property-use-face ,(syn :prop))
        (font-lock-preprocessor-face ,(syn :pre))
        (font-lock-escape-face ,(syn :const))
        (font-lock-regexp-grouping-construct (:foreground ,(c :const)))
        (font-lock-operator-face (:foreground ,(c :fg)))
        (font-lock-punctuation-face (:foreground ,(c :fg)))
        (font-lock-bracket-face (:foreground ,(c :fg)))
        (font-lock-delimiter-face (:foreground ,(c :fg)))
        (font-lock-warning-face (:foreground ,(c :yellow)))

        (look-sidebar (:family ,ui :height ,ui-h :background ,(c :side) :foreground ,(c :fg)))
        (look-sidebar-header ,(funcall bar (c :side)))
        (look-pill (:background ,(look--mix (c :side) (c :fg) 0.085) :extend t))
        (look-hover (:background ,(look--mix (c :side) (c :fg) 0.04) :extend t))
        (look-sidebar-dim (:foreground ,(c :dim) :background ,(c :side)))
        (explorer-drop (:background ,(look--mix (c :side) (c :accent) 0.16) :extend t))
        (treemacs-root-face (:foreground ,(c :dim) :weight semibold :height 0.92))
        (treemacs-root-unreadable-face (:inherit treemacs-root-face))
        (treemacs-root-remote-face (:inherit treemacs-root-face))
        (treemacs-directory-face (:foreground ,(c :fg)))
        (treemacs-file-face (:foreground ,(c :fg)))
        (treemacs-git-unmodified-face (:foreground ,(c :fg)))
        (treemacs-git-modified-face (:foreground ,(c :yellow)))
        (treemacs-git-renamed-face (:foreground ,(c :yellow)))
        (treemacs-git-added-face (:foreground ,(c :green)))
        (treemacs-git-untracked-face (:foreground ,(c :green)))
        (treemacs-git-conflict-face (:foreground ,(c :red)))
        (treemacs-git-ignored-face (:foreground ,(c :dim)))
        (treemacs-window-background-face (:background ,(c :side)))
        (treemacs-hl-line-face (:background ,(c :side)))

        ,@(cl-loop for (name key) in '((black :dim) (red :red) (green :green) (yellow :yellow)
                                        (blue :blue) (magenta :magenta) (cyan :cyan) (white :faint))
                   for col = (c key)
                   append `((,(intern (format "ansi-color-%s" name)) (:foreground ,col :background ,col))
                            (,(intern (format "ansi-color-bright-%s" name)) (:foreground ,col :background ,col))))
        (vterm-color-black (:inherit ansi-color-black))
        (vterm-color-red (:inherit ansi-color-red))
        (vterm-color-green (:inherit ansi-color-green))
        (vterm-color-yellow (:inherit ansi-color-yellow))
        (vterm-color-blue (:inherit ansi-color-blue))
        (vterm-color-magenta (:inherit ansi-color-magenta))
        (vterm-color-cyan (:inherit ansi-color-cyan))
        (vterm-color-white (:inherit ansi-color-white))))))

(defun look-apply (&optional appearance)
  "Load `look-variant' in APPEARANCE (`light' or `dark')."
  (setq look-appearance (or appearance look-appearance 'light))
  (let* ((v (copy-sequence (alist-get look-variant look-variants)))
         (v (if-let* ((font (getenv "LOOK_FONT"))) (plist-put v :mono font) v))
         (p (plist-get v (if (eq look-appearance 'dark) :dark :light))))
    (setq look--palette p)
    ;; the unit is the code font's height, so set the font before measuring
    (set-face-attribute 'default nil :family (plist-get v :mono) :height (plist-get v :mono-height))
    (apply #'custom-theme-set-faces 'look
           (mapcar (lambda (f) `(,(car f) ((t ,@(cadr f))))) (look--faces v p)))
    (enable-theme 'look)
    (look--chrome)
    (look--explorer-icons)))

;;; Chrome: hairline dividers, no bars, even padding

(setq-default cursor-type '(bar . 2)
              ;; half above, half below: text sits in the middle of its row, so
              ;; the cursor bar (always the row's height) is centred on it
              line-spacing '(0.15 . 0.15)
              ;; right-aligned in a column three digits wide in every file
              ;; (wider only past line 999), so the gap to the text and the
              ;; place of the digits are the same everywhere
              display-line-numbers-width 3
              display-line-numbers-grow-only t
              cursor-in-non-selected-windows nil
              indicate-empty-lines nil
              indicate-buffer-boundaries nil
              mode-line-format nil)
(setq window-divider-default-right-width 1
      window-divider-default-bottom-width 1
      window-divider-default-places 'right-only
      x-underline-at-descent-line t
      echo-keystrokes 0.02)
(window-divider-mode 1)
;; long lines just run off the edge, no arrows in the margin
(setq-default fringe-indicator-alist
              (append '((truncation nil nil) (continuation nil nil))
                      (default-value 'fringe-indicator-alist)))
;; blinks while you work, stops after ten blinks idle (no timer when idle)
(setq blink-cursor-blinks 10
      blink-cursor-interval 0.53)
(blink-cursor-mode 1)

(defun look--chrome ()
  "Sizes that depend on the unit."
  (let ((edge (look--px 0.7)))
    (setq-default left-fringe-width edge
                  right-fringe-width (look--px 0.35))
    (set-frame-parameter nil 'left-fringe edge)
    (set-frame-parameter nil 'right-fringe (look--px 0.35))
    (look--echo-padding)
    (setq vertico-posframe-parameters
          `((left-fringe . ,edge) (right-fringe . ,edge) (line-spacing . (0.17 . 0.17))))))

;; Messages and prompts show in the minibuffer's own panel (below): its text
;; in the interface font, no fringes.
(defun look--echo-remap ()
  (unless (assq 'default face-remapping-alist)
    (face-remap-add-relative 'default 'look-echo-text)))

(defun look--echo-padding (&rest _)
  ;; the explorer's edges (see `look--explorer-edges'); buffer-local fringe
  ;; widths only apply when a buffer is put into a window, and treemacs has
  ;; done that already
  (when-let* ((w (and (fboundp 'treemacs-get-local-window) (treemacs-get-local-window))))
    (look--explorer-edges w))
  (dolist (buf '(" *Echo Area 0*" " *Echo Area 1*" " *Minibuf-0*"))
    (with-current-buffer (get-buffer-create buf) (look--echo-remap)))
  ;; the panel's side padding
  (set-window-fringes (minibuffer-window) (look--px 0.7) (look--px 0.7)))

(add-hook 'minibuffer-setup-hook #'look--echo-padding)
(add-hook 'window-configuration-change-hook #'look--echo-padding)
(add-hook 'window-size-change-functions #'look--echo-padding)

(defun look--margin-columns ()
  "Right-margin columns that fit the pill's rounded end plus its inset."
  (ceiling (+ (look--pill-inset) (look--pill-radius)) (frame-char-width)))

(defun look--explorer-edges (w)
  "Explorer window W's right edge: a margin that holds the pill's right end
(`look--margin-cap') and a 1px fringe. No fringe on the left: the left inset is
drawn by the rows themselves."
  (let ((cols (look--margin-columns)))
    (unless (equal (window-margins w) (cons nil cols))
      (set-window-margins w nil cols))
    ;; fringes outside the margins: by default the 1px fringe sits between
    ;; the text and the margin, a seam through the pill
    (unless (equal (window-fringes w) '(0 1 t nil))
      (set-window-fringes w 0 1 t))))

(defun look--margin-block (face)
  "A square block of FACE's background across the right margin, ending one
inset short of the explorer's edge, like the pill."
  (let* ((w (* (look--margin-columns) (frame-char-width)))
         (h (look--row-height))
         (svg (svg-create w h)))
    (svg-rectangle svg 0 0 (- w (1- (look--pill-inset))) h
                   :fill (face-background face nil t))
    (svg-image svg :ascent 'center :scale 1)))

(defun look--margin-cap (&optional face)
  "The pill's right end, exactly as wide as the right margin: the pill runs on
flat from the text area and rounds off one inset (less the 1px fringe) short
of the margin's edge."
  (let* ((w (* (look--margin-columns) (frame-char-width)))
         (h (look--row-height))
         (r (look--pill-radius))
         (end (- w (1- (look--pill-inset))))
         (svg (svg-create w h)))
    (svg-rectangle svg (- r) 0 (+ end r) h :rx r :fill (face-background (or face 'look-pill) nil t))
    (svg-image svg :ascent 'center :scale 1)))

;;; The minibuffer as a floating panel. The window has no minibuffer line;
;;; the minibuffer frame (early-init.el) becomes a hidden child of the window.
;;; A prompt that isn't already one of the popups (a yes/no question, a
;;; name) shows it where the popups appear; a message shows it briefly as a
;;; toast in the bottom right corner.

(defvar look--mini-hide-timer nil)

(defun look--mini-frame () (window-frame (minibuffer-window)))

(defun look--main-frame ()
  "The window's frame: visible, not the minibuffer's, not a child."
  (seq-find (lambda (f) (and (frame-visible-p f)
                             (not (eq (frame-parameter f 'minibuffer) 'only))
                             (not (frame-parameter f 'parent-frame))))
            (frame-list)))

(defun look--mini-setup (&optional frame)
  "Make the minibuffer frame a hidden child of FRAME (the window's), styled
as a panel, and give the window back the focus Emacs gave the minibuffer."
  (let ((mf (look--mini-frame))
        (frame (or frame (look--main-frame))))
    (when (and frame (not (eq mf frame)) (not (frame-parameter mf 'parent-frame)))
      (modify-frame-parameters
       mf `((parent-frame . ,frame) (no-other-frame . t) (skip-taskbar . t)
            (undecorated . t) (child-frame-border-width . 1)
            ;; the popups' row: their line spacing, no other padding
            (internal-border-width . 0) (line-spacing . (0.17 . 0.17))
            (left-fringe . 0) (right-fringe . 0) (unsplittable . t)
            (background-color . ,(face-background 'default nil t))))
      (set-face-background 'child-frame-border (face-background 'vertico-posframe-border nil t) mf)
      (make-frame-invisible mf t)
      (select-frame-set-input-focus frame)
      (run-hooks 'look-window-ready-hook))))

(defvar look-window-ready-hook nil
  "Run once the window is set up (after startup, with its frame selected).")

(defun look--mini-place (where &optional text)
  "Put the minibuffer panel WHERE: `prompt' (top centre, like the popups)
or `toast' (bottom right, sized to TEXT)."
  (let* ((mf (look--mini-frame))
         (parent (frame-parameter mf 'parent-frame)))
    (when (frame-live-p parent)
      (let* ((pw (frame-pixel-width parent)) (ph (frame-pixel-height parent))
             (cw (frame-char-width mf))
             ;; one row of the popups: a line plus their line spacing
             (h (+ (frame-char-height mf) (* 2 (round (* 0.17 (frame-char-height mf)))))))
        (pcase where
          ('prompt
           ;; exactly where the popups' prompt row is: their width (see
           ;; `vertico-posframe-size-function'), their fringes and border
           (let* ((cols (with-selected-frame parent (min 110 (round (* 0.6 (frame-width))))))
                  (outer (+ (* cols cw) (* 2 (look--px 0.7)) 2))
                  (text (- outer (* 2 (look--px 0.7)) 2)))
             (set-frame-size mf text h t)
             (let ((err (- (frame-pixel-width mf) outer)))
               (unless (zerop err) (set-frame-size mf (- text err) h t)))
             (set-frame-position mf (/ (- pw outer) 2) (look--px 2.4))))
          ('toast
           (let* (;; measured in the font it shows in, plus the side padding
                  (w (min (round (* 0.5 pw))
                          (+ (string-pixel-width (propertize (or text "") 'face 'look-echo-text))
                             (* 2 (look--px 0.7)) 2))))
             (set-frame-size mf w h t)
             ;; placed by its full size, padding included: a child frame is
             ;; clipped at its parent's edge
             (set-frame-position mf
                                 (- pw (frame-pixel-width mf) (look--px 0.8))
                                 (- ph (frame-pixel-height mf) (look--px 0.8))))))
        (make-frame-visible mf)))))

(defun look--mini-hide ()
  (let ((mf (look--mini-frame)))
    (when (and (frame-parameter mf 'parent-frame) (frame-visible-p mf)
               (not (active-minibuffer-window)))
      (make-frame-invisible mf t))))

;; prompts: shown unless vertico's popup is showing this minibuffer. Emacs
;; makes the minibuffer's frame visible whenever it reads from it, so the
;; panel is hidden again for those popups.
(add-hook 'minibuffer-setup-hook
          (lambda ()
            (if (and (bound-and-true-p vertico-posframe-mode) vertico--input)
                (when (frame-parameter (look--mini-frame) 'parent-frame)
                  (make-frame-invisible (look--mini-frame) t))
              (run-at-time 0 nil
                           (lambda ()
                             (when (active-minibuffer-window)
                               (look--mini-place 'prompt)))))))

;; vertico-posframe shrinks the minibuffer window to one line before showing
;; its popup; in the minibuffer's own frame that window is the frame's root,
;; which can't be resized, and the error stopped the popup from showing. The
;; panel is hidden during these popups anyway: only hide the text, as it does.
(with-eval-after-load 'vertico-posframe
  (advice-add 'vertico-posframe--handle-minibuffer-window :override
              (lambda ()
                (let ((mw (active-minibuffer-window)))
                  (setq-local max-mini-window-height 1)
                  (set-window-vscroll mw 100)
                  (when (vertico-posframe--show-minibuffer-p)
                    (set-window-vscroll mw 0))))))

;; posframe declines to work while a minibuffer-only frame is selected, which
;; is always so while typing into this panel; the popups it shows belong to
;; the window's frame all the same
(with-eval-after-load 'posframe
  (advice-add 'posframe-workable-p :around
              (lambda (orig)
                (or (funcall orig)
                    (and (display-graphic-p)
                         (eq (frame-parameter (selected-frame) 'minibuffer) 'only))))))
(add-hook 'minibuffer-exit-hook
          (lambda () (run-at-time 0 nil #'look--mini-hide)))

;; messages: a toast for a few seconds
(defun look--toast (msg)
  (when (and msg (not (string-empty-p msg)) (not (active-minibuffer-window))
             (not look--asking))
    ;; this runs before the message reaches the echo area: size it by MSG
    (run-at-time 0 nil (lambda () (look--mini-place 'toast msg)))
    (when (timerp look--mini-hide-timer) (cancel-timer look--mini-hide-timer))
    (setq look--mini-hide-timer (run-at-time 3 nil #'look--mini-hide)))
  nil)
(add-hook 'set-message-functions #'look--toast)
;; a message taken back (the next key, or `(message nil)') leaves the toast
;; empty: it goes with it
(add-function :after clear-message-function
              (lambda (&rest _)
                (when (timerp look--mini-hide-timer) (cancel-timer look--mini-hide-timer))
                (look--mini-hide)))
;; y-or-n-p echoes the answer once the question is gone: no toast for that
(defvar look--asking nil)
(advice-add 'y-or-n-p :around
            (lambda (orig &rest args)
              (let ((look--asking t)) (apply orig args))))

(defun look--mini-setup-when-ready (&optional tries)
  "Set the panel up once the window has appeared (it hasn't, at startup)."
  (let ((tries (or tries 20)))
    (when (getenv "LOOK_DEBUG")
      (message "mini-setup try %s main=%S mini=%S" tries (look--main-frame) (look--mini-frame)))
    (if (or (look--main-frame) (<= tries 0))
        (look--mini-setup)
      (run-at-time 0.1 nil #'look--mini-setup-when-ready (1- tries)))))
;; a moment after startup: done during it, Emacs's own frame setup undid it
(add-hook 'emacs-startup-hook
          (lambda () (run-at-time 0.3 nil #'look--mini-setup-when-ready)))

;;; Window buttons. Emacs gets no title bar here, so the explorer's header
;;; carries them, as in a macOS sidebar: the desktop's traffic lights
;;; (home/theme.nix: 14px discs, 8px apart, 12px in; grey when unfocused).

(defconst look--lights
  '((close "#fe6254" save-buffers-kill-terminal)
    (minimize "#fdc92d" iconify-frame)
    (maximize "#28d33f" toggle-frame-maximized)))

(defvar look--light-hover nil "The button under the pointer, or nil.")
(defvar look--light-images (make-hash-table :test #'equal))

(defun look--glyph-file (name)
  "The desktop's hover glyph for button NAME (pkgs/titlebutton-glyphs.nix)."
  (expand-file-name (format "glyphs/%s.svg" name) user-emacs-directory))

(defun look--light-image (name colour state)
  "Disc NAME in STATE: `lit', `idle', or `hover' (lit, with its glyph)."
  (let* ((d (look--px 0.7))
         (key (list name state d look-appearance)))
    (or (gethash key look--light-images)
        (puthash key
                 (let ((svg (svg-create d d)))
                   (svg-circle svg (/ d 2.0) (/ d 2.0) (/ d 2.0)
                               :fill (if (eq state 'idle)
                                         (if (eq look-appearance 'dark) "#5d5d5d" "#cecece")
                                       colour))
                   (when (and (eq state 'hover) (file-exists-p (look--glyph-file name)))
                     (look--place-icon svg (look--glyph-file name) 0 0 d))
                   (svg-image svg :ascent 'center :scale 1))
                 look--light-images))))

(defun look--light-hover (name)
  (unless (eq look--light-hover name)
    (setq look--light-hover name)
    ;; a hover event doesn't redisplay by itself; Emacs does after a timer
    (run-at-time 0 nil #'force-mode-line-update t)))

;; Emacs calls a disc's help-echo function when the pointer enters it (the
;; function shows no tooltip), and show-help-function with nil when it leaves
;; for anything without one.
(add-function :before show-help-function
              (lambda (msg) (unless msg (look--light-hover nil))))

(defun look--traffic-lights ()
  "The three buttons, as one header-line string."
  (let ((focused (eq (frame-focus-state) t))
        (space (lambda (w) (propertize " " 'display `(space :width (,w))))))
    (concat
     (funcall space (look--px 0.6))
     (mapconcat
      (lambda (light)
        (pcase-let ((`(,name ,colour ,cmd) light))
          (propertize " "
                      'display (look--light-image
                                name colour
                                (cond ((eq look--light-hover name) 'hover)
                                      (focused 'lit)
                                      (t 'idle)))
                      'pointer 'arrow
                      'help-echo (lambda (&rest _) (look--light-hover name) nil)
                      'keymap (define-keymap "<header-line> <mouse-1>"
                                (lambda () (interactive)
                                  (look--light-hover nil)
                                  (call-interactively cmd))))))
      look--lights
      (funcall space (look--px 0.4)))
     (funcall space (look--px 0.6)))))

(defun look--top-left-p ()
  (let ((edges (window-edges)))
    (and (= 0 (nth 0 edges)) (= 0 (nth 1 edges)))))

(add-function :after after-focus-change-function
              (lambda () (setq look--light-hover nil) (force-mode-line-update t)))

;;; Breadcrumb header: folders › file, and where the cursor is

(defvar-local look--crumbs nil "Cached (PARENTS . NAME) for the header.")

(defun look--crumbs ()
  (or look--crumbs
      (setq look--crumbs
            (let* ((file buffer-file-name)
                   (proj (and file (project-current nil (file-name-directory file))))
                   (root (and proj (project-root proj)))
                   (rel (cond ((and root file) (file-relative-name file root))
                              (file (abbreviate-file-name file))
                              (t (buffer-name))))
                   (parts (split-string rel "/" t)))
              (cons (append (when root (list (file-name-nondirectory (directory-file-name root))))
                            (butlast parts))
                    (car (last parts)))))))

(add-hook 'after-set-visited-file-name-hook (lambda () (setq look--crumbs nil)))

(defun look--header-left ()
  (let* ((crumbs (look--crumbs))
         (sep (propertize "  ›  " 'face 'look-crumb)))
    (concat
     (mapconcat (lambda (c) (concat (propertize c 'face 'look-crumb) sep)) (car crumbs) "")
     (propertize (cdr crumbs) 'face 'look-crumb-current)
     (when (and buffer-file-name (buffer-modified-p))
       (propertize "  ●" 'face 'look-crumb)))))

(defun look--header-right ()
  (propertize
   (concat (format "Ln %d, Col %d" (line-number-at-pos) (1+ (current-column)))
           "      "
           (string-remove-suffix "-ts" (string-remove-suffix " mode" (format-mode-line mode-name))))
   'face 'look-status))

(defun look--header ()
  (let* ((pad (look--px 0.75))
         (right (look--header-right))
         (w (string-pixel-width right)))
    (concat (if (look--top-left-p)
                (look--traffic-lights)
              (propertize " " 'display `(space :width (,pad))))
            (look--header-left)
            (propertize " " 'display `(space :align-to (- right (,(+ w pad)))))
            right)))

(setq-default header-line-format '((:eval (look--header))))

;; Buffers that are not documents get no header.
(dolist (hook '(special-mode-hook messages-buffer-mode-hook help-mode-hook
                completion-list-mode-hook))
  (add-hook hook (lambda () (setq-local header-line-format nil))))

(defun look-panel-title (title)
  "A quiet TITLE header for a panel."
  (face-remap-add-relative 'header-line 'look-panel-header)
  (face-remap-add-relative 'header-line-active 'look-panel-header)
  (face-remap-add-relative 'header-line-inactive 'look-panel-header)
  (setq-local header-line-format
              `(,(propertize " " 'display `(space :width (,(look--px 0.75))))
                (:propertize ,(upcase title) face look-panel-title))))

;;; Start page: the shortcuts, in place of *scratch*

(defconst look-welcome-keys
  '(("Open file" . "Ctrl P") ("Search in files" . "Ctrl Shift F") ("Commands" . "Ctrl Shift P")
    ("Go to symbol" . "Ctrl Shift O") ("Recent files" . "Ctrl R")
    ("Explorer" . "Ctrl B") ("Terminal" . "Ctrl J")))

(defvar-keymap look-welcome-mode-map
  :doc "The start page doesn't scroll."
  "<wheel-up>" #'ignore "<wheel-down>" #'ignore
  "<mouse-4>" #'ignore "<mouse-5>" #'ignore)

(define-derived-mode look-welcome-mode special-mode "Welcome"
  "The start page."
  (setq-local header-line-format nil
              cursor-type nil
              line-spacing 0.9
              face-remapping-alist '((default look-welcome default))
              ;; its keymap would scroll by pixel regardless of ours
              pixel-scroll-precision-mode nil)
  (add-hook 'window-size-change-functions #'look--welcome-draw nil t)
  (add-hook 'window-scroll-functions
            (lambda (win start) (unless (= start (point-min)) (set-window-start win (point-min))))
            nil t))

(defun look--welcome-draw (&optional win)
  "Lay out the start page, centred in WIN."
  (let ((win (or (and (windowp win) win) (get-buffer-window "Welcome") (selected-window)))
        (inhibit-read-only t)
        (col (lambda (px) (propertize " " 'display `(space :align-to (,px))))))
    (with-current-buffer "Welcome"
      (erase-buffer)
      (let* ((w (window-body-width win t))
             (x (max (look--px 2) (- (/ w 2) (look--px 7))))
             (name (if-let* ((p (project-current)))
                       (file-name-nondirectory (directory-file-name (project-root p)))
                     "Emacs")))
        (insert (funcall col x)
                (propertize name 'face '(:inherit look-crumb-current :height 1.6 :weight semibold))
                "\n\n")
        (dolist (k look-welcome-keys)
          (insert (funcall col x) (propertize (car k) 'face 'look-crumb-current)
                  (funcall col (+ x (look--px 8))) (propertize (cdr k) 'face 'look-crumb)
                  "\n"))
        ;; vertically centred: an empty line exactly as tall as the space left
        (when (window-live-p win)
          (let* ((content (cdr (window-text-pixel-size win (point-min) (point-max))))
                 (top (max 0 (/ (- (window-body-height win t) content) 2))))
            (goto-char (point-min))
            (insert (propertize " " 'display `(space :height (,top))) "\n"))))
      ;; nothing to edit here: the arrow, not the text cursor
      (let ((o (make-overlay (point-min) (point-max) nil nil t)))
        (overlay-put o 'pointer 'arrow))
      (goto-char (point-min))
      (when (window-live-p win) (set-window-start win (point-min))))))

(defun look-welcome ()
  "The start page buffer."
  (with-current-buffer (get-buffer-create "Welcome")
    (unless (derived-mode-p 'look-welcome-mode) (look-welcome-mode))
    (look--welcome-draw)
    (current-buffer)))

;;; Explorer: Finder's rows — a chevron, the desktop's WhiteSur icon, the name,
;;; and a rounded pill for the selected row. Drawn as SVG at the unit's scale.

(defun look--data-file (rel)
  "First REL under the XDG data dirs."
  (cl-some (lambda (d) (let ((f (expand-file-name rel d))) (and (file-exists-p f) f)))
           (split-string (or (getenv "XDG_DATA_DIRS") "/run/current-system/sw/share") ":")))

(defun look--mime-extensions ()
  "Alist of (ICON-NAME . EXTENSIONS) from the shared MIME globs."
  (let ((globs (look--data-file "mime/globs2"))
        (table (make-hash-table :test #'equal)))
    (when globs
      (with-temp-buffer
        (insert-file-contents globs)
        (goto-char (point-min))
        (while (re-search-forward "^[0-9]+:\\([^:]+\\):\\*\\.\\([a-z0-9+_-]+\\)$" nil t)
          (let ((icon (replace-regexp-in-string "/" "-" (match-string 1)))
                (ext (match-string 2)))
            (cl-pushnew ext (gethash icon table) :test #'equal)))))
    (let (out)
      (maphash (lambda (k v) (push (cons k v) out)) table)
      out)))

(defvar look--icon-doms (make-hash-table :test #'equal) "Icon file -> parsed <svg>.")

(defun look--icon-dom (file)
  "FILE's <svg> element, with a viewBox so it can be placed at any size."
  (or (gethash file look--icon-doms)
      (puthash file
               (with-temp-buffer
                 (insert-file-contents file)
                 (let* ((dom (libxml-parse-xml-region (point-min) (point-max)))
                        (w (dom-attr dom 'width)) (h (dom-attr dom 'height)))
                   (unless (dom-attr dom 'viewBox)
                     (dom-set-attribute dom 'viewBox
                                        (format "0 0 %s %s" (string-to-number (or w "16"))
                                                (string-to-number (or h "16")))))
                   dom))
               look--icon-doms)))

(defun look--place-icon (svg file x y size)
  "Nest FILE's icon inside SVG at X, Y, SIZE square."
  (let ((icon (copy-tree (look--icon-dom file))))
    (dom-set-attribute icon 'x (number-to-string x))
    (dom-set-attribute icon 'y (number-to-string y))
    (dom-set-attribute icon 'width (number-to-string size))
    (dom-set-attribute icon 'height (number-to-string size))
    (dom-append-child svg icon)))

;; A row, left to right: pill inset | pill end | chevron | gap | icon | gap | name.
;; Each level of nesting moves the next level's chevron under this level's icon.
(defun look--row-height () (look--px 1.3))
(defun look--pill-inset () (look--px 0.4))
(defun look--pill-radius () (look--px 0.3))
(defun look--chevron-width () (look--icon-size))
(defun look--chevron-gap () (look--px 0.4))
(defun look--icon-size () (look--px 0.8))
(defun look--name-gap () (look--px 0.35))
(defun look--level-indent () (+ (look--chevron-width) (look--chevron-gap)))

(defun look--image (svg)
  (let ((img (svg-image svg :ascent 'center :scale 1)))
    (propertize " " 'display img)))

(defun look--row-icon (file &optional chevron)
  "A row's icon: CHEVRON (`open', `closed' or nil), then FILE's icon."
  (let* ((h (look--row-height))
         (cw (look--chevron-width))
         (is (look--icon-size))
         ;; a folder's chevron, then its icon; a file's icon takes the
         ;; chevron's place, so files line up with their sibling folders'
         ;; chevrons
         (x (if chevron (+ cw (look--chevron-gap)) 0))
         (svg (svg-create (+ x is (look--name-gap)) h)))
    (when chevron
      ;; drawn pointing right and turned: 0 degrees closed, 90 open, anything
      ;; between while a folder opens or closes
      (let* ((s (* 0.2 (look--u)))
             (cx (/ cw 2.0)) (cy (/ h 2.0))
             (angle (pcase chevron ('open 90) ('closed 0) (_ chevron))))
        (svg-polyline svg (list (cons (- cx (* s 0.5)) (- cy s))
                                (cons (+ cx (* s 0.5)) cy)
                                (cons (- cx (* s 0.5)) (+ cy s)))
                      :fill "none" :stroke (plist-get look--palette :dim)
                      :stroke-width (max 1.2 (* 0.075 (look--u)))
                      :stroke-linecap "round" :stroke-linejoin "round"
                      :transform (format "rotate(%s %s %s)" angle cx cy))))
    (when file
      (look--place-icon svg file x (/ (- h is) 2.0) is))
    (look--image svg)))

(defun look--spacer (width)
  (let ((svg (svg-create (max 1 width) (look--row-height))))
    (look--image svg)))

(defun look--cap-image (side)
  "The pill's rounded end, SIDE `left' or `right', as an image."
  (get-text-property 0 'display (look--cap side)))

(defun look--cap (side &optional face)
  "Half of the pill's rounded end, SIDE `left' or `right', in FACE's colour."
  (let* ((h (look--row-height))
         (r (look--pill-radius))
         (svg (svg-create r h)))
    (svg-rectangle svg (if (eq side 'left) 0 (- r)) 0 (* 2 r) h
                   :rx r :fill (face-background (or face 'look-pill) nil t))
    (propertize " " 'display (svg-image svg :ascent 'center :scale 1))))

(defvar look--themes-made nil)

(defun look--explorer-icons ()
  (when (and (featurep 'treemacs) (display-graphic-p))
    (when-let* ((index (look--data-file "icons/WhiteSur-light/index.theme")))
      (let* ((root (file-name-directory index))
             (name (format "look-%s-%s-%d" look-variant look-appearance (look--u)))
             (f (lambda (rel) (expand-file-name rel root))))
        (unless (member name look--themes-made)
          (push name look--themes-made)
          (let ((mimes (look--mime-extensions))
                (fallback (look--row-icon (funcall f "mimes/scalable/text-x-generic.svg"))))
            (eval
             `(treemacs-create-theme ,name
                :config
                (progn
                  (treemacs-create-icon :icon ,(look--spacer 1) :extensions (root-open root-closed) :fallback "")
                  (treemacs-create-icon :icon ,(look--row-icon (funcall f "places/scalable/folder.svg") 'open)
                                        :extensions (dir-open) :fallback "")
                  (treemacs-create-icon :icon ,(look--row-icon (funcall f "places/scalable/folder.svg") 'closed)
                                        :extensions (dir-closed) :fallback "")
                  (treemacs-create-icon :icon ,fallback :extensions (fallback) :fallback "")
                  ,@(cl-loop for (icon . exts) in mimes
                             for file = (funcall f (format "mimes/scalable/%s.svg" icon))
                             when (file-exists-p file)
                             collect `(treemacs-create-icon :icon ,(look--row-icon file)
                                                            :extensions ,exts :fallback ""))))
             t)))
        (treemacs-load-theme name)
        ;; top-level rows start at the pill's inner edge; every deeper level
        ;; one indent further (treemacs repeats this list per level)
        (setq treemacs-indentation-string
              (cons "" (make-list 40 (propertize " " 'display `(space :width (,(look--level-indent)))))))
        (look--pill-refresh)))))

;; The selected row: hl-line still tracks it, but is drawn as a pill.
(defvar-local look--pill nil)
(defvar-local look--arrow nil "Overlay giving the whole explorer the arrow pointer.")

(defun look--pill-put (ov face pos)
  "Draw pill OV in FACE on POS's row: a rounded cap in the line-prefix, the
face extended from the newline to the text area's edge by Emacs itself, and a
rounded cap in the right margin (see `look--explorer-edges')."
  (save-excursion
    (goto-char pos)
    (move-overlay ov (line-beginning-position) (min (point-max) (1+ (line-end-position))))
    (overlay-put ov 'face face)
    ;; the caps are the row too: hand pointer and the row's hover hook
    (let ((row (look--row-props (line-beginning-position))))
      (overlay-put ov 'line-prefix
                   (apply #'propertize
                          (concat (propertize " " 'display `(space :width (,(look--pill-inset))))
                                  (look--cap 'left face))
                          row))
      ;; the right cap goes into the row's own margin string: two overlays'
      ;; margin strings on one row would both be drawn
      (look--row-margin (line-beginning-position) face))))

(defun look--row-margin (bol &optional face)
  "Set the right-margin piece of the row at BOL: FACE's rounded cap, or blank."
  (when-let* ((o (seq-find (lambda (o) (overlay-get o 'look-row)) (overlays-at bol))))
    ;; the image goes straight into the margin spec (a display property
    ;; nested inside a display string isn't drawn); pointer and hover hook on
    ;; the string itself
    (overlay-put o 'before-string
                 (propertize " "
                             'display `((margin right-margin)
                                        ,(if face
                                             (look--margin-cap face)
                                           (make-string (look--margin-columns) ?\s)))
                             'pointer 'hand
                             'help-echo (overlay-get o 'help-echo)))
    (when-let* ((sp (overlay-get o 'look-spacer)))
      (overlay-put sp 'before-string
                   (propertize " " 'display `(space :width (,(overlay-get sp 'look-width)))
                               'face (or face 'look-sidebar)
                               'pointer 'hand)))))

(defun look--row-margins-reset ()
  (dolist (o look--row-overlays)
    (when (and (overlay-buffer o) (overlay-get o 'look-row))
      (look--row-margin (overlay-start o)))))

(defun look--row-props (bol)
  "The hand pointer and hover hook of the row starting at BOL, as a plist."
  (let ((o (seq-find (lambda (o) (overlay-get o 'look-row)) (overlays-at bol))))
    (and o (list 'pointer 'hand 'help-echo (overlay-get o 'help-echo)))))

(defun look--row-selectable-p (pos)
  "Whether POS's row is a file or folder (not the project's title, not empty)."
  (save-excursion
    (goto-char pos)
    (let ((btn (ignore-errors (treemacs-current-button))))
      (and btn
           (/= (line-beginning-position) (line-end-position))
           (not (memq (treemacs-button-get btn :state) '(root-node-open root-node-closed)))))))

(defun look--pill-update (&rest _)
  "Draw the selection pill on the explorer's current row."
  (when (derived-mode-p 'treemacs-mode)
    (unless (overlayp look--pill)
      (setq look--pill (make-overlay 1 1))
      (overlay-put look--pill 'priority 100))
    (let* ((win (get-buffer-window nil t))
           ;; the explorer's own cursor, which is not the buffer's while
           ;; another window has focus
           (pos (and win (window-point win))))
      (look--row-margins-reset)
      (if (and pos (look--row-selectable-p pos))
          (look--pill-put look--pill 'look-pill pos)
        (delete-overlay look--pill))
      (look--hover-draw))))

;; Hover: a muted pill on the row under the pointer, and the hand pointer.
;; Every row carries an overlay whose help-echo function Emacs calls when the
;; pointer enters that row (a distinct function per row, or Emacs wouldn't call
;; it again on the next); show-help-function is called with nil when the
;; pointer leaves for something without one.
(defvar-local look--hover nil "The hover pill's overlay.")
(defvar-local look--hover-row nil "Marker at the hovered row, or nil.")
(defvar-local look--row-overlays nil)

(defun look--hover-draw ()
  (unless (overlayp look--hover)
    (setq look--hover (make-overlay 1 1))
    (overlay-put look--hover 'priority 90))
  ;; the previous hover row gets its plain margin back
  (when (overlay-buffer look--hover)
    (look--row-margin (overlay-start look--hover)))
  (let ((pos (and look--hover-row (marker-position look--hover-row))))
    (if (and pos
             (look--row-selectable-p pos)
             ;; the selected row keeps its own pill
             (not (and (overlay-buffer look--pill)
                       (= (save-excursion (goto-char pos) (line-beginning-position))
                          (overlay-start look--pill)))))
        (look--pill-put look--hover 'look-hover pos)
      (when (overlay-buffer look--hover)
        (look--row-margin (overlay-start look--hover)))
      (delete-overlay look--hover))))

(defun look--hover-set (buf marker)
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (unless (equal marker look--hover-row)
        (setq look--hover-row marker)
        (look--hover-draw)))))

(defun look--row-under-pointer (buf)
  "A marker at the selectable explorer row of BUF under the pointer, or nil.
Asked inside the text area at the pointer's height: over the right margin Emacs
reports the next row's position."
  (pcase-let ((`(,frame ,x . ,y) (mouse-pixel-position)))
    (when (and frame x)
      (let* ((win (window-at-x-y x y frame))
             (edges (and win (eq (window-buffer win) buf) (window-inside-pixel-edges win)))
             (posn (and edges (< y (nth 3 edges)) (>= y (nth 1 edges))
                        (posn-at-x-y (+ (nth 0 edges) 40) y frame)))
             (pt (and posn (posn-point posn))))
        (when (and pt (with-current-buffer buf (look--row-selectable-p pt)))
          (with-current-buffer buf
            (copy-marker (save-excursion (goto-char pt) (line-beginning-position)))))))))

;; Hover. While the pointer is over the explorer, Emacs's mouse tracking is on
;; and every movement arrives as an event with its exact position (handled as a
;; special event, so commands aren't disturbed). Help-echo events can't drive
;; it: pgtk re-examines the pointer only when it leaves the last glyph's
;; rectangle, and over the explorer's image rows that happens rarely.
;;
;; Tracking starts when the pointer enters the explorer: with
;; `mouse-autoselect-window' on, pgtk emits a select-window event for every
;; window the pointer enters; that event is taken here and used only to start
;; tracking (windows are not actually selected on hover). No such event fires
;; for the selected window, so while the explorer has focus tracking stays on.
;; It stops when the pointer is elsewhere and the explorer isn't focused.
(defvar look--hover-tracking nil "The explorer buffer whose hover is tracked.")

(defun look--row-from-posn (win posn)
  "Marker at the selectable row of WIN that POSN is on, or nil.
By screen-row index: the event's pixel coordinates are measured from different
origins depending on which window has focus, and over the right margin its
buffer position is the next row's. (Not `mouse-pixel-position' either: in
pgtk that also resets the glyph rectangle Emacs uses to notice movement, and
right after a click it recorded one that swallowed the next moves.)"
  (let ((row (cdr (posn-actual-col-row posn))))
    (when (and row (>= row 0))
      (with-current-buffer (window-buffer win)
        (save-excursion
          (goto-char (window-start win))
          (when (zerop (forward-line row))
            (and (look--row-selectable-p (point)) (copy-marker (point)))))))))

(defun look--explorer-focused-p (buf)
  (eq (window-buffer (selected-window)) buf))

(defun look--hover-motion (event)
  "Follow the pointer over the explorer; stop tracking once it's gone."
  (interactive "e")
  (let* ((posn (event-start event))
         (win (posn-window posn))
         (buf look--hover-tracking))
    (cond
     ((null buf))
     ((and (windowp win) (eq (window-buffer win) buf)
           (not (memq (posn-area posn) '(header-line mode-line))))
      (look--hover-set buf (look--row-from-posn win posn)))
     ((look--explorer-focused-p buf)
      (look--hover-set buf nil))
     (t (look--hover-stop)))))

(defun look--hover-start (buf &optional row)
  "Track the pointer over BUF's explorer. ROW, when known (after a click, the
clicked row), saves asking where the pointer is."
  (unless (eq look--hover-tracking buf)
    (setq look--hover-tracking buf
          track-mouse t)
    (define-key special-event-map [mouse-movement] #'look--hover-motion))
  (if row
      (look--hover-set buf (if (eq row 'none) nil row))
    (look--hover-sync buf)))

(defun look--hover-stop ()
  (when look--hover-tracking
    (let ((buf look--hover-tracking))
      (setq look--hover-tracking nil
            track-mouse nil)
      (define-key special-event-map [mouse-movement] nil)
      (look--hover-set buf nil))))

(defun look--hover-sync (buf)
  (when (buffer-live-p buf)
    (look--hover-set buf (look--row-under-pointer buf))))

(defun look--pointer-entered (event)
  "The pointer entered a window: start hover tracking if it's the explorer."
  (interactive "e")
  (let ((win (car (cadr event))))
    (when (and (windowp win)
               (with-current-buffer (window-buffer win) (derived-mode-p 'treemacs-mode)))
      (look--hover-start (window-buffer win)))))

(setq mouse-autoselect-window t)
(define-key special-event-map [select-window] #'look--pointer-entered)

;; focusing the explorer (a click, C-b) keeps tracking on; leaving it for
;; another window stops tracking once the pointer is elsewhere
(add-hook 'window-selection-change-functions
          (lambda (_frame)
            (let ((buf (window-buffer (selected-window))))
              (when (and (with-current-buffer buf (derived-mode-p 'treemacs-mode))
                         ;; a click has already started it
                         (not (eq look--hover-tracking buf)))
                (look--hover-start buf)))))

;; the pointer left the frame
(defvar look--leave-timer nil)

(defun look--leave-check ()
  (when (and look--hover-tracking
             (null (look--row-under-pointer look--hover-tracking)))
    (if (look--explorer-focused-p look--hover-tracking)
        (look--hover-set look--hover-tracking nil)
      (look--hover-stop))))

;; Checked a moment later: asking where the pointer is (in pgtk) also resets
;; the glyph rectangle Emacs uses to notice movement, and asked while the
;; explorer is being redrawn (right after a click) it recorded one that
;; swallowed the next moves.
(add-function :before show-help-function
              (lambda (msg)
                (when (and (null msg) look--hover-tracking)
                  (when (timerp look--leave-timer) (cancel-timer look--leave-timer))
                  (setq look--leave-timer (run-at-time 0.1 nil #'look--leave-check)))))

(defun look--hover-poke (&optional _buf)
  "Rows' help-echo: nothing to do any more (see above).")

(defun look--row-overlays-update ()
  "Give every row the hand pointer and a hover hook of its own."
  (mapc #'delete-overlay look--row-overlays)
  (setq look--row-overlays nil)
  (let ((buf (current-buffer)))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (when (look--row-selectable-p (point))
          (let* ((m (copy-marker (line-beginning-position)))
                 (o (make-overlay (line-beginning-position) (min (point-max) (1+ (line-end-position))))))
            (overlay-put o 'look-row t)
            (overlay-put o 'pointer 'hand)
            (overlay-put o 'help-echo
                         (lambda (&rest _)
                           (look--hover-poke buf)
                           ;; names cut short show in full as a tooltip
                           (save-excursion
                             (goto-char m)
                             (when (seq-some (lambda (c) (overlay-get c 'look-cut))
                                             (overlays-in (point) (line-end-position)))
                               (let ((path (treemacs-button-get (treemacs-current-button) :path)))
                                 (and (stringp path) (file-name-nondirectory path)))))))
            ;; the row's inset and its right margin carry the same pointer
            ;; and hook as its text
            (overlay-put o 'line-prefix
                         (propertize " " 'display
                                     `(space :width (,(+ (look--pill-inset) (look--pill-radius))))
                                     'pointer 'hand 'help-echo (overlay-get o 'help-echo)))
            ;; the rest of the row, from the end of the name to the edge, as
            ;; a spacer of its own: otherwise it's empty space, which takes
            ;; the void-area pointer (the arrow, right for below the tree)
            (let* ((win (get-buffer-window nil t))
                   (used (and win (car (window-text-pixel-size
                                        win (line-beginning-position) (line-end-position) 100000))))
                   (sp (make-overlay (line-end-position) (line-end-position))))
              (overlay-put sp 'look-width (max 0 (- (if win (window-body-width win t) 0) (or used 0) 2)))
              (overlay-put o 'look-spacer sp)
              (push sp look--row-overlays))
            (push o look--row-overlays)
            (look--row-margin (line-beginning-position))))
        (forward-line 1)))))

;;; Folders open and close with a short animation: the child rows unroll
;;; from the top (or roll up from the bottom), and the chevron turns.

(defconst look--anim-time 0.16 "Seconds a folder takes to open or close.")
(defconst look--anim-ticks 8)
(defvar-local look--anim nil "The running animation's cleanup function.")

(defun look--children-end (btn)
  "Where the rows below BTN's folder end."
  (save-excursion
    (goto-char btn)
    (let ((depth (treemacs-button-get btn :depth)))
      (forward-line 1)
      (while (let ((b (ignore-errors (treemacs-current-button))))
               (and b (> (treemacs-button-get b :depth) depth) (zerop (forward-line 1)))))
      (point))))

(defun look--chevron-frame (btn angle)
  "BTN's folder icon with its chevron turned to ANGLE."
  (look--row-icon (expand-file-name "places/scalable/folder.svg"
                                    (file-name-directory (look--data-file "icons/WhiteSur-light/index.theme")))
                  angle))

(defun look--animate (btn opening done)
  "Unroll (OPENING) or roll up the rows under BTN, turning its chevron; then
call DONE."
  (when look--anim (funcall look--anim))
  (let* ((buf (current-buffer))
         (rows-start (save-excursion (goto-char btn) (line-beginning-position 2)))
         (rows-end (look--children-end btn))
         (lines (count-lines rows-start rows-end))
         (hide (make-overlay rows-start rows-end))
         (icon (make-overlay (1- (treemacs-button-start btn)) (treemacs-button-start btn)))
         (tick 0) timer finish)
    (overlay-put hide 'invisible t)
    (overlay-put icon 'priority 200)
    (setq finish (lambda ()
                   (when (timerp timer) (cancel-timer timer))
                   (delete-overlay hide) (delete-overlay icon)
                   (with-current-buffer buf (setq look--anim nil))
                   (when done (funcall (prog1 done (setq done nil))))))
    (setq look--anim finish)
    (unless opening (overlay-put hide 'invisible nil))
    (setq timer
          (run-at-time
           0 (/ look--anim-time look--anim-ticks)
           (lambda ()
             (if (not (buffer-live-p buf))
                 (funcall finish)
               (with-current-buffer buf
                 (setq tick (1+ tick))
                 (let* ((f (min 1.0 (/ (float tick) look--anim-ticks)))
                        ;; ease out: quick start, gentle landing
                        (e (- 1 (expt (- 1 f) 3)))
                        (shown (round (* lines (if opening e (- 1 e))))))
                   (overlay-put icon 'display (look--chevron-frame btn (* 90 (if opening e (- 1 e)))))
                   (overlay-put hide 'invisible t)
                   (move-overlay hide (save-excursion (goto-char rows-start) (forward-line shown) (point))
                                 rows-end)
                   (when (>= f 1.0) (funcall finish))))))))))

(defvar look--anim-inhibit nil)

(with-eval-after-load 'treemacs
  (advice-add 'treemacs--expand-dir-node :after
              (lambda (btn &rest _)
                (unless look--anim-inhibit
                  (look--animate btn t nil))))
  (advice-add 'treemacs--collapse-dir-node :around
              (lambda (orig btn &rest args)
                (if (or look--anim-inhibit
                        (not (get-buffer-window nil t))
                        (<= (look--children-end btn)
                            (save-excursion (goto-char btn) (line-beginning-position 2))))
                    (apply orig btn args)
                  ;; roll up first; treemacs removes the rows afterwards
                  (let ((buf (current-buffer)))
                    (look--animate btn nil
                                   (lambda ()
                                     (with-current-buffer buf
                                       (let ((look--anim-inhibit t))
                                         (save-excursion (apply orig btn args)))))))))))

;; Names too long for the explorer end in an ellipsis, as in Finder: the cut
;; tail is hidden and an ellipsis shown. An overflowing row would otherwise get
;; a white fringe beside it.
(defvar-local look--cut-overlays nil)

(defun look--fit-names (&rest _)
  (when-let* (((derived-mode-p 'treemacs-mode))
              (win (get-buffer-window nil t)))
    ;; the last row needs a newline too: the pill's colour runs on from it
    (unless (eq (char-before (point-max)) ?\n)
      (let ((inhibit-read-only t))
        (with-silent-modifications
          (save-excursion (goto-char (point-max)) (insert "\n")))))
    (mapc #'delete-overlay look--cut-overlays)
    (setq look--cut-overlays nil)
    (let* ((avail (- (window-body-width win t) 2))
           (dots (propertize "…" 'face 'look-sidebar-dim))
           (dots-w (string-pixel-width dots)))
      (save-excursion
        (goto-char (window-start win))
        (let ((end (window-end win t)))
          (while (< (point) end)
            (let ((bol (line-beginning-position)) (eol (line-end-position)))
              ;; measured without the window's width as a limit
              (when (> (car (window-text-pixel-size win bol eol 100000)) avail)
                ;; walk back until the rest plus an ellipsis fits
                (let ((cut eol))
                  (while (and (> cut bol)
                              (> (+ dots-w (car (window-text-pixel-size win bol cut 100000))) avail))
                    (setq cut (1- cut)))
                  (let ((o (make-overlay cut eol)))
                    (overlay-put o 'display dots)
                    (overlay-put o 'look-cut t)
                    (push o look--cut-overlays)))))
            (forward-line 1)))))
    (look--row-overlays-update)
    (look--pill-update)))

(defvar-local look--fit-pending nil)

(defun look--fit-names-soon (&rest _)
  "Fit names once the current change to the tree is done."
  (unless look--fit-pending
    (setq look--fit-pending t)
    (let ((buf (current-buffer)))
      (run-at-time 0 nil (lambda ()
                           (when (buffer-live-p buf)
                             (with-current-buffer buf
                               (setq look--fit-pending nil)
                               (look--fit-names))))))))

(defvar-local look--pill-at nil "Where the explorer's cursor was when the pill was drawn.")

(defun look--pill-follow (win)
  (let ((pt (window-point win)))
    (unless (eql pt look--pill-at)
      (setq look--pill-at pt)
      (look--pill-update))))

(defun look--arrow-refresh (&rest _)
  (when (and (derived-mode-p 'treemacs-mode) (overlayp look--arrow))
    (move-overlay look--arrow (point-min) (point-max))))

(defun look--pill-refresh ()
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (derived-mode-p 'treemacs-mode)
        (look--sidebar-setup)
        (look--pill-update)))))

(defun look--sidebar-setup ()
  (setq-local face-remapping-alist nil)
  (face-remap-add-relative 'default 'look-sidebar)
  (face-remap-add-relative 'fringe 'look-sidebar)
  ;; treemacs's current-line overlay draws nothing: the pill is the highlight
  (face-remap-add-relative 'hl-line 'look-nothing)
  (face-remap-add-relative 'header-line 'look-sidebar-header)
  (face-remap-add-relative 'header-line-active 'look-sidebar-header)
  (face-remap-add-relative 'header-line-inactive 'look-sidebar-header)
  ;; an arrow over the whole explorer, no text cursor; no hover highlight
  ;; (treemacs's button type asks for one; mouse-highlight isn't buffer-local)
  (put 'treemacs-button 'mouse-face nil)

  (add-hook 'after-change-functions #'look--fit-names-soon nil t)
  ;; the explorer's cursor moves from commands, clicks and treemacs's follow
  ;; timer alike; redraw the pill whenever it has moved, just before display
  (add-hook 'pre-redisplay-functions #'look--pill-follow nil t)
  (add-hook 'window-size-change-functions #'look--fit-names-soon nil t)
  (unless (overlayp look--arrow)
    (setq look--arrow (make-overlay (point-min) (point-max) nil nil t))
    (overlay-put look--arrow 'pointer 'arrow)
    ;; below the rows' own overlays, which give the hand
    (overlay-put look--arrow 'priority -10))
  (setq-local line-spacing 0
              left-fringe-width 0
              right-fringe-width 1
              right-margin-width (look--margin-columns)
              auto-hscroll-mode nil
              header-line-format '((:eval (look--traffic-lights)))
              line-prefix (propertize " " 'display `(space :width (,(+ (look--pill-inset) (look--pill-radius)))))))

(with-eval-after-load 'treemacs
  (look--explorer-icons)
  (advice-add 'hl-line-highlight :after #'look--pill-update)
  (add-hook 'treemacs-mode-hook
            (lambda ()
              (look--sidebar-setup)
              (add-hook 'post-command-hook #'look--pill-update nil t)))
  ;; the tree is redrawn without a command (startup, file changes)
  (add-hook 'treemacs-post-buffer-init-hook #'look--pill-update)
  (add-hook 'treemacs-post-refresh-hook #'look--pill-update)
  ;; treemacs's follow moves the explorer's cursor from a timer
  (dolist (f '(treemacs--follow treemacs-goto-file-node))
    (advice-add f :after (lambda (&rest _)
                           (when-let* ((w (treemacs-get-local-window)))
                             (with-current-buffer (window-buffer w)
                               (look--pill-update))))))
  (add-hook 'treemacs-post-refresh-hook #'look--arrow-refresh)
  (add-hook 'treemacs-post-refresh-hook #'look--fit-names)
  (add-hook 'treemacs-post-buffer-init-hook #'look--arrow-refresh))

;;; Light and dark, following the desktop

(require 'dbus)

(defun look--scheme->appearance (value)
  ;; the portal wraps the uint in variants; 1 is prefer-dark
  (while (consp value) (setq value (car value)))
  (if (eql value 1) 'dark 'light))

(defun look--portal-appearance ()
  (condition-case nil
      (look--scheme->appearance
       (dbus-call-method :session "org.freedesktop.portal.Desktop" "/org/freedesktop/portal/desktop"
                         "org.freedesktop.portal.Settings" "ReadOne"
                         "org.freedesktop.appearance" "color-scheme"))
    (error 'light)))

(let ((forced (getenv "LOOK_APPEARANCE")))
  (look-apply (if forced (intern forced) (look--portal-appearance)))
  (unless forced
    (ignore-errors
      (dbus-register-signal :session "org.freedesktop.portal.Desktop" "/org/freedesktop/portal/desktop"
                            "org.freedesktop.portal.Settings" "SettingChanged"
                            (lambda (ns key value)
                              (when (and (equal ns "org.freedesktop.appearance")
                                         (equal key "color-scheme"))
                                (look-apply (look--scheme->appearance value))))))))
