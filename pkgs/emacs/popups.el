;;; popups.el --- quick open, command palette, project search  -*- lexical-binding: t -*-
;;
;; The panels at the top of the window, as in VS Code: a prompt with a
;; placeholder, rows with an icon, a name in the interface font and a quiet
;; path, and no Emacs-internal noise (permissions, sizes, docstrings of 4000
;; commands).

(require 'seq)
(require 'project)

(defface popup-name '((t :inherit variable-pitch)) "A name in a popup row.")
(defface popup-dim '((t :inherit (variable-pitch shadow))) "Secondary text in a popup row.")
(defface popup-key '((t :inherit (variable-pitch shadow))) "A shortcut, right-aligned.")
(defface popup-placeholder '((t :inherit (variable-pitch shadow))) "What to type, while nothing is.")

;;; Placeholder: shown after the prompt while the input is empty

(defvar-local popup--placeholder nil)
(defvar-local popup--placeholder-ov nil)

(defun popup--placeholder-update ()
  (when popup--placeholder
    (unless (overlayp popup--placeholder-ov)
      (setq popup--placeholder-ov (make-overlay (point-max) (point-max) nil t t)))
    (move-overlay popup--placeholder-ov (point-max) (point-max))
    (overlay-put popup--placeholder-ov 'after-string
                 (and (string-empty-p (minibuffer-contents-no-properties))
                      (propertize popup--placeholder 'face 'popup-placeholder
                                  'cursor 0)))))

(defun popup-read (prompt placeholder collection &rest args)
  "`completing-read' with PROMPT, a PLACEHOLDER while the input is empty, and
no match counter."
  (let ((vertico-count-format nil))
    (minibuffer-with-setup-hook
        (lambda ()
          (setq popup--placeholder placeholder)
          (add-hook 'post-command-hook #'popup--placeholder-update nil t)
          (popup--placeholder-update))
      (apply #'completing-read (propertize prompt 'face 'minibuffer-prompt) collection args))))

;; what's typed, in the interface font like the placeholder; the results below
;; keep theirs (a code search shows code)
(defun popup--input-face ()
  (when (and (bound-and-true-p vertico-posframe-mode) (bound-and-true-p vertico--input))
    (overlay-put (make-overlay (minibuffer-prompt-end) (point-max) nil nil t)
                 'face 'popup-name)))
(add-hook 'minibuffer-setup-hook #'popup--input-face 90)

;;; Go to File (C-p)

(defvar popup--file-icons (make-hash-table :test #'equal))

(defun popup--file-icon (path)
  "PATH's WhiteSur icon, small, for a popup row."
  (let ((file (explorer--icon-file path)))
    (or (gethash file popup--file-icons)
        (puthash file
                 ;; one text line tall: taller rows would push the last one
                 ;; out of the panel, which is sized in lines
                 (let* ((is (look--icon-size)) (h (look--u))
                        (svg (svg-create (+ is (look--px 0.4)) h)))
                   (look--place-icon svg file 0 (/ (- h is) 2.0) is)
                   (propertize " " 'display (svg-image svg :ascent 'center :scale 1)))
                 popup--file-icons))))

(defun vs-find-file ()
  "Go to a file in the project, by any part of its name or path."
  (interactive)
  (let* ((root (if-let* ((p (project-current))) (project-root p) default-directory))
         (files (if-let* ((p (project-current))) (project-files p)
                  (directory-files-recursively root "" nil)))
         (table (make-hash-table :test #'equal))
         (rows (mapcar (lambda (f)
                         (let* ((rel (file-relative-name f root))
                                (dir (file-name-directory rel))
                                (row (concat (propertize (file-name-nondirectory rel) 'face 'popup-name)
                                             (when dir
                                               (propertize (concat "  " (directory-file-name dir))
                                                           'face 'popup-dim)))))
                           (puthash row f table)
                           row))
                       files))
         (choice (popup-read
                  "" "Go to file by name or path"
                  (lambda (str pred action)
                    (if (eq action 'metadata)
                        `(metadata (category . vs-file)
                                   (affixation-function
                                    . ,(lambda (cands)
                                         (mapcar (lambda (c)
                                                   (list c (popup--file-icon (gethash c table)) ""))
                                                 cands))))
                      (complete-with-action action rows str pred)))
                  nil t)))
    (when-let* ((f (gethash choice table)))
      (find-file f))))

;;; Command palette (C-S-p): what VS Code's has, in its words

(defconst popup-commands
  '(("File: New File" vs-new-buffer "Ctrl+N")
    ("File: Open File…" find-file "Ctrl+O")
    ("File: Open Recent…" consult-recent-file "Ctrl+R")
    ("File: Save" save-buffer "Ctrl+S")
    ("File: Save As…" write-file "Ctrl+Shift+S")
    ("File: Revert File" revert-buffer nil)
    ("View: Close Editor" kill-current-buffer "Ctrl+W")
    ("Go to File…" vs-find-file "Ctrl+P")
    ("Go to Symbol in Editor…" consult-imenu "Ctrl+Shift+O")
    ("Go to Line…" goto-line nil)
    ("Search: Find in File" isearch-forward "Ctrl+F")
    ("Search: Find in Files" vs-search "Ctrl+Shift+F")
    ("Search: Replace in File" query-replace nil)
    ("View: Toggle Explorer" vs-toggle-explorer "Ctrl+B")
    ("View: Toggle Terminal" vs-toggle-terminal "Ctrl+J")
    ("View: Zoom In" text-scale-increase "Ctrl+=")
    ("View: Zoom Out" text-scale-decrease "Ctrl+-")
    ("View: Reset Zoom" (lambda () (text-scale-set 0)) "Ctrl+0")
    ("View: Toggle Word Wrap" visual-line-mode nil)
    ("Edit: Undo" undo "Ctrl+Z")
    ("Edit: Redo" undo-redo "Ctrl+Y")
    ("Edit: Select All" mark-whole-buffer "Ctrl+A")
    ("Edit: Toggle Line Comment" comment-line "Ctrl+/")
    ("Edit: Move Line Up" (lambda () (vs-move-line -1)) "Alt+↑")
    ("Edit: Move Line Down" (lambda () (vs-move-line 1)) "Alt+↓")
    ("Edit: Indent Region" indent-region nil)
    ("Explorer: New File…" explorer-new-file nil)
    ("Explorer: New Folder…" explorer-new-folder nil)
    ("Explorer: Reveal Active File" treemacs-find-file nil)
    ("Explorer: Refresh" treemacs-refresh nil)
    ("Terminal: Clear" vterm-clear nil)
    ("Emacs: Run Any Command…" execute-extended-command nil))
  "The palette: (NAME COMMAND SHORTCUT).")

(defvar popup--command-history nil "Palette entries, most recently run first.")

(defun vs-command-palette ()
  "Run a command by its name, as in VS Code."
  (interactive)
  (let* ((width (lambda (s) (string-pixel-width (propertize s 'face 'popup-name))))
         (entries (append (seq-filter (lambda (e) (assoc e popup-commands)) popup--command-history)
                          (seq-remove (lambda (e) (member e popup--command-history))
                                      (mapcar #'car popup-commands))))
         (rows (mapcar (lambda (name) (propertize name 'face 'popup-name)) entries))
         (choice (popup-read
                  "" "Type the name of a command"
                  (lambda (str pred action)
                    (if (eq action 'metadata)
                        `(metadata (category . vs-command)
                                   (display-sort-function . identity)
                                   (cycle-sort-function . identity)
                                   (affixation-function
                                    . ,(lambda (cands)
                                         (mapcar (lambda (c)
                                                   (let ((key (nth 2 (assoc c popup-commands))))
                                                     (list c ""
                                                           (if key
                                                               (concat (propertize " " 'display
                                                                                   `(space :align-to (- right (,(+ (funcall width key) (look--px 1.2))))))
                                                                       (propertize key 'face 'popup-key))
                                                             ""))))
                                                 cands))))
                      (complete-with-action action rows str pred)))
                  nil t))
         (entry (assoc choice popup-commands)))
    (when entry
      (setq popup--command-history (cons (car entry) (delete (car entry) popup--command-history)))
      (let ((cmd (nth 1 entry)))
        (if (symbolp cmd) (call-interactively cmd) (funcall cmd))))))

;;; Search in files (C-S-f): results grouped under a file row, line numbers
;;; in their own quiet column

(defun popup--prefix-group (cand transform)
  "consult's grouping of \"file:line:code\" candidates, restyled: the group is a
row for the file (name, then its folder quietly), each result a quiet line
number in its own column, then the code."
  (let ((file (get-text-property 0 'consult--prefix-group cand)))
    (if (not transform)
        (and file
             ;; no icon here: an image in a group title emptied the panel
             (concat (propertize (file-name-nondirectory file) 'face '(:inherit popup-name :weight medium))
                     (let ((dir (file-name-directory file)))
                       (and dir (propertize (concat "  " (directory-file-name dir)) 'face 'popup-dim)))))
      (let ((rest (if file (substring cand (min (length cand) (1+ (length file)))) cand)))
        (if (string-match "\\`\\([0-9]+\\):" rest)
            (concat (propertize (format "%5s" (match-string 1 rest)) 'face 'line-number)
                    "   "
                    (substring rest (match-end 0)))
          rest)))))

(with-eval-after-load 'consult
  (advice-add 'consult--prefix-group :override #'popup--prefix-group)
  ;; no "(Project name)" after the prompt: the panel belongs to the project
  (advice-add 'consult--directory-prompt :filter-return
              (lambda (r) (cons "" (cdr r)))))

(with-eval-after-load 'vertico
  ;; a group is a row of its own (the file, for search results), no rules
  (setq vertico-group-format (concat "%s")))

(provide 'popups)
