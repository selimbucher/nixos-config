;;; explorer.el --- the explorer's mouse and file handling  -*- lexical-binding: t -*-
;;
;; Finder/VS Code behaviour on top of treemacs:
;; - one click anywhere on a row opens the file or folds the folder;
;; - dragging shows the folder the item will land in, and asks before moving
;;   (treemacs itself moves on release, with no sign of where);
;; - right-click and F2 / Delete for creating, renaming and trashing.

(require 'treemacs)
(require 'seq)

(defface explorer-drop '((t)) "The folder a dragged item will land in.")

(defconst explorer--drag-threshold 6
  "Pixels the pointer must travel before a press becomes a drag.")

;;; Rows

(defun explorer--button (pos)
  "The treemacs button on POS's line, or nil."
  (and pos (save-excursion (goto-char pos) (ignore-errors (treemacs-current-button)))))

(defun explorer--state (btn) (treemacs-button-get btn :state))

(defun explorer--root-p (btn)
  (memq (explorer--state btn) '(root-node-open root-node-closed)))

(defun explorer--dir-p (btn)
  (memq (explorer--state btn) '(dir-node-open dir-node-closed root-node-open root-node-closed)))

(defun explorer--file-p (btn)
  (memq (explorer--state btn) '(file-node-open file-node-closed dir-node-open dir-node-closed)))

(defun explorer--root ()
  (save-excursion
    (goto-char (point-min))
    (let (btn)
      (while (and (not (setq btn (explorer--button (point)))) (zerop (forward-line 1))))
      btn)))

(defun explorer--editor-window ()
  "The most recently used window that is not a side panel."
  (car (sort (seq-remove (lambda (w) (window-parameter w 'window-side))
                         (window-list nil 'nomini))
             (lambda (a b) (> (window-use-time a) (window-use-time b))))))

(defun explorer--open (btn)
  (pcase (explorer--state btn)
    ((or 'dir-node-open 'dir-node-closed)
     (goto-char btn)
     (treemacs-toggle-node))
    ((or 'file-node-open 'file-node-closed)
     (let ((path (treemacs-button-get btn :path)))
       (select-window (explorer--editor-window))
       (find-file path)))))

;;; Dragging

(defun explorer--drop-folder (src pos)
  "The folder button a drop at POS puts SRC into, or nil where that is no move."
  (let* ((btn (or (explorer--button pos) (explorer--root)))
         (dst (if (explorer--dir-p btn) btn (treemacs-button-get btn :parent)))
         (from (treemacs-button-get src :path))
         (into (and dst (treemacs-button-get dst :path))))
    (when (and into
               (not (string= (directory-file-name (file-name-directory from))
                             (directory-file-name into)))
               (not (string= from into))
               (not (string-prefix-p (file-name-as-directory from) into)))
      dst)))

(defvar-local explorer--drop-overlay nil)
(defvar-local explorer--drop-margins nil "The tint's right-margin pieces, one per row.")

(defun explorer--show-drop (dst)
  "Tint DST's row and everything shown inside it; nil clears."
  (unless (overlayp explorer--drop-overlay)
    (setq explorer--drop-overlay (make-overlay 1 1))
    (overlay-put explorer--drop-overlay 'face 'explorer-drop)
    (overlay-put explorer--drop-overlay 'priority 50)
    ;; the tint starts where the selection pill does
    (overlay-put explorer--drop-overlay 'line-prefix
                 (concat (propertize " " 'display `(space :width (,(look--pill-inset))))
                         (propertize " " 'face 'explorer-drop
                                     'display `(space :width (,(look--pill-radius)))))))
  (mapc #'delete-overlay explorer--drop-margins)
  (setq explorer--drop-margins nil)
  (if (null dst)
      (delete-overlay explorer--drop-overlay)
    (save-excursion
      (goto-char dst)
      (let ((start (line-beginning-position))
            (depth (treemacs-button-get dst :depth))
            (block (look--margin-block 'explorer-drop)))
        (forward-line 1)
        (while (let ((b (explorer--button (point))))
                 (and b (> (treemacs-button-get b :depth) depth) (zerop (forward-line 1)))))
        (move-overlay explorer--drop-overlay start (point))
        ;; the tint runs on into the right margin, as far as the pill does
        (let ((end (point)))
          (goto-char start)
          (while (< (point) end)
            (let ((o (make-overlay (point) (point))))
              (overlay-put o 'before-string
                           (propertize " " 'display `((margin right-margin) ,block)))
              (push o explorer--drop-margins))
            (forward-line 1)))))))

(defun explorer--name (btn)
  (file-name-nondirectory (directory-file-name (treemacs-button-get btn :path))))

(defun explorer--ask (question verb)
  "A native yes/no dialog: QUESTION, with VERB as the yes button."
  (condition-case nil
      (x-popup-dialog t `(,question (,verb . t) ("Cancel" . nil)))
    (error (y-or-n-p (concat question " ")))))

(defun explorer--move (from into)
  "Move FROM into the folder INTO; buffers visiting it follow.
Done here rather than by treemacs, whose own drop fails on a collapsed folder."
  (let ((to (expand-file-name (file-name-nondirectory (directory-file-name from)) into)))
    (if (file-exists-p to)
        (x-popup-dialog t `(,(format "“%s” already contains an item named “%s”."
                                      (file-name-nondirectory (directory-file-name into))
                                      (file-name-nondirectory to))
                            ("OK" . nil)))
      (rename-file from to)
      (treemacs--reload-buffers-after-rename from to)
      (treemacs--replace-recentf-entry from to)
      (let ((treemacs-silent-refresh t))
        (treemacs-refresh))
      (ignore-errors (treemacs-goto-file-node to)))))

(defconst explorer--dwell 0.6
  "Seconds a dragged item must rest on a closed folder before it opens.")

;; The ghost: the dragged item's icon and name on a pill, following the
;; pointer, in a transparent child frame so only the pill shows.
(defvar explorer--ghost nil "The ghost's child frame.")

(defun explorer--icon-file (path)
  "The desktop's WhiteSur icon file for PATH."
  (let ((root (file-name-directory (look--data-file "icons/WhiteSur-light/index.theme"))))
    (if (file-directory-p path)
        (expand-file-name "places/scalable/folder.svg" root)
      (or (seq-some (lambda (entry)
                      (and (member (downcase (or (file-name-extension path) "")) (cdr entry))
                           (let ((f (expand-file-name (format "mimes/scalable/%s.svg" (car entry)) root)))
                             (and (file-exists-p f) f))))
                    (look--mime-extensions-cached))
          (expand-file-name "mimes/scalable/text-x-generic.svg" root)))))

(defvar explorer--mime-cache nil)
(defun look--mime-extensions-cached ()
  (or explorer--mime-cache (setq explorer--mime-cache (look--mime-extensions))))

(defun explorer--ghost-image (path)
  "The dragged item as a small opaque label: icon and name, hairline border.
(Opaque, square-cornered: Emacs draws an image's transparent pixels on the
face background, so rounded corners or a shadow came out as white boxes.)"
  (let* ((name (file-name-nondirectory (directory-file-name path)))
         (face `(:family ,(face-attribute 'variable-pitch :family) :height ,(face-attribute 'look-sidebar :height)))
         (tw (string-pixel-width (propertize name 'face face)))
         (h (look--row-height)) (is (look--icon-size))
         (pad (look--px 0.4)) (gap (look--px 0.35))
         (w (+ pad is gap tw pad))
         (svg (svg-create w h)))
    (svg-rectangle svg 0.5 0.5 (- w 1) (- h 1)
                   :fill (face-background 'default nil t)
                   :stroke (look--mix (face-background 'default nil t) (face-foreground 'default nil t) 0.18)
                   :stroke-width 1)
    (look--place-icon svg (explorer--icon-file path) pad (/ (- h is) 2.0) is)
    (svg-text svg name :x (+ pad is gap) :y (/ h 2.0)
              :dominant-baseline "central"
              :font-family (plist-get face :family)
              :font-size (* 0.1 (plist-get face :height) (/ 96.0 72))
              :fill (face-foreground 'default nil t))
    (list (svg-image svg :scale 1) w h)))

(defun explorer--ghost-show (path)
  (pcase-let* ((`(,img ,w ,h) (explorer--ghost-image path))
               (buf (get-buffer-create " *explorer-ghost*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t)) (erase-buffer) (insert (propertize " " 'display img)))
      (setq-local mode-line-format nil header-line-format nil cursor-type nil
                  left-fringe-width 0 right-fringe-width 0))
    (explorer--ghost-frame)
    (set-window-buffer (frame-root-window explorer--ghost) buf)
    (set-window-dedicated-p (frame-root-window explorer--ghost) t)
    (set-frame-size explorer--ghost w h t)))

(defun explorer--ghost-frame ()
  "The ghost's frame, made once and kept hidden: creating a child frame while
the button is held stalled the pointer's events for a second."
  (unless (frame-live-p explorer--ghost)
    (let ((buf (get-buffer-create " *explorer-ghost*")))
      (setq explorer--ghost
            (make-frame `((parent-frame . ,(selected-frame)) (minibuffer . nil)
                          (undecorated . t) (no-accept-focus . t) (no-focus-on-map . t)
                          (no-other-frame . t) (skip-taskbar . t) (unsplittable . t)
                          (internal-border-width . 0) (child-frame-border-width . 0)
                          (left-fringe . 0) (right-fringe . 0) (vertical-scroll-bars . nil)
                          (menu-bar-lines . 0) (tool-bar-lines . 0) (tab-bar-lines . 0)
                          (min-width . 1) (min-height . 1) (line-spacing . 0)
                          (alpha-background . 0) (visibility . nil))))
      (set-window-buffer (frame-root-window explorer--ghost) buf)))
  explorer--ghost)

;; made as soon as the explorer exists, hidden
(add-hook 'treemacs-mode-hook (lambda () (run-at-time 0.5 nil #'explorer--ghost-frame)))

;; Positions during a drag come from its movement events: asking pgtk where
;; the pointer is (`mouse-pixel-position') inside a tracking loop resets the
;; flags Emacs needs to report the next movement, and the drag stalled.
(defun explorer--posn-frame-xy (posn)
  "POSN's position relative to its frame: the event's own coordinates are
relative to its window's text area."
  (let ((win (posn-window posn)) (xy (posn-x-y posn)))
    (when (and (windowp win) xy)
      (let ((e (window-inside-pixel-edges win)))
        (cons (+ (nth 0 e) (car xy)) (+ (nth 1 e) (cdr xy)))))))

(defun explorer--ghost-move (posn)
  (when-let* (((frame-live-p explorer--ghost))
              (xy (explorer--posn-frame-xy posn)))
    (set-frame-position explorer--ghost (+ (car xy) (look--px 0.6)) (+ (cdr xy) (look--px 0.3)))
    (unless (frame-visible-p explorer--ghost) (make-frame-visible explorer--ghost))))

(defun explorer--ghost-hide ()
  (when (frame-live-p explorer--ghost) (make-frame-invisible explorer--ghost)))

(defun explorer--editor-window-at (posn)
  "The editor window POSN is in, if any (not a side panel)."
  (let ((w (and posn (posn-window posn))))
    (and (windowp w) (not (window-parameter w 'window-side)) w)))

(defun explorer--edge-scroll (win posn)
  "Scroll WIN a row when the pointer (last at POSN) rests near its top or
bottom edge."
  (when (eq (posn-window posn) win)
    (let ((y (cdr (posn-x-y posn)))
          (h (window-body-height win t))
          (band (look--row-height)))
      (cond ((< y band)
             (ignore-errors (with-selected-window win (scroll-down 1))) t)
            ((> y (- h band))
             (ignore-errors (with-selected-window win (scroll-up 1))) t)))))

(defun explorer-press (event)
  "Click, or drag to move, the row under EVENT."
  (interactive "e")
  (let* ((start (event-start event))
         (win (progn (select-window (posn-window start))
                     ;; select-window leaves the current buffer alone until the
                     ;; command ends; the row has to be read from the explorer's
                     (set-buffer (window-buffer (posn-window start)))
                     (posn-window start)))
         (xy0 (posn-x-y start))
         (src (explorer--button (posn-point start)))
         (message-log-max nil)
         dragging dst end dwell-row dwell-since last-posn)
    ;; the row is selected as soon as the button goes down; it opens on release
    (when (and src (look--row-selectable-p src))
      (set-window-point win src)
      (look--pill-update)
      (redisplay))
    (setq end
          ;; the drag reads its own movements: hover tracking's handler is
          ;; hidden from it, and otherwise left running (stopping and
          ;; restarting it around the press lost the first movement after)
          (let ((special-event-map (let ((m (copy-keymap special-event-map)))
                                     (define-key m [mouse-movement] nil)
                                     m)))
           (track-mouse
            (catch 'done
              (while t
                ;; while dragging, wake every 100ms: resting on a closed
                ;; folder opens it, resting at the edge scrolls
                (let ((e (read-event nil nil (and dragging 0.1))))
                  (cond
                   ((null e)
                    (when (and last-posn (explorer--edge-scroll win last-posn))
                      (setq dwell-row nil))
                    (when (and dst dwell-row (eq dst dwell-row)
                               (eq (explorer--state dst) 'dir-node-closed)
                               (> (float-time (time-since dwell-since)) explorer--dwell))
                      (save-excursion (goto-char dst) (treemacs-toggle-node))
                      (setq dwell-row nil)
                      (explorer--show-drop dst)))
                   ((not (mouse-movement-p e))
                    (throw 'done e))
                   (t
                    (let* ((p (event-start e))
                           (xy (posn-x-y p)))
                      (when (and (not dragging) src (not (explorer--root-p src)) xy
                                 (> (+ (abs (- (car xy) (car xy0))) (abs (- (cdr xy) (cdr xy0))))
                                    explorer--drag-threshold))
                        (setq dragging t)
                        (explorer--ghost-show (treemacs-button-get src :path)))
                      (when dragging
                        (setq last-posn p)
                        (explorer--ghost-move p)
                        (setq dst (and (eq (posn-window p) win)
                                       (explorer--drop-folder src (posn-point p))))
                        (unless (eq dst dwell-row)
                          (setq dwell-row dst dwell-since (current-time)))
                        (explorer--show-drop dst)
                        (message "%s"
                                 (cond (dst (format "Move %s  →  %s" (explorer--name src) (explorer--name dst)))
                                       ((explorer--editor-window-at last-posn)
                                        (format "Open %s" (explorer--name src)))
                                       (t (format "Move %s" (explorer--name src)))))))))))))))
    (explorer--ghost-hide)
    (explorer--show-drop nil)
    (message nil)
    ;; hover follows the pointer again; it's on the row just clicked, which
    ;; carries the selection, so there's nothing to hover yet
    (look--hover-start (window-buffer win) 'none)
    (cond
     ;; Escape, or any other key, cancels
     ((not (memq (event-basic-type end) '(mouse-1)))
      nil)
     ((not dragging)
      (when src (explorer--open src)))
     (dst
      (when (explorer--ask (format "Move “%s” into “%s”?" (explorer--name src) (explorer--name dst))
                           "Move")
        (explorer--move (treemacs-button-get src :path) (treemacs-button-get dst :path))))
     ;; dropped on the editor: open it there, as VS Code does
     ((and (explorer--editor-window-at last-posn)
           (not (file-directory-p (treemacs-button-get src :path))))
      (let ((path (treemacs-button-get src :path)))
        (select-window (explorer--editor-window-at last-posn))
        (find-file path))))))

;;; File operations

(defmacro explorer--in-tree (&rest body)
  "Run BODY with the explorer's window selected, keeping its row."
  `(let ((pos (point)))
     (with-selected-window (treemacs-get-local-window)
       (goto-char pos)
       ,@body)))

(defun explorer--at-event (event)
  "Put point on EVENT's row in the explorer; return that row's button."
  (let ((p (event-start event)))
    (select-window (posn-window p))
    (set-buffer (window-buffer (posn-window p)))
    (when (posn-point p) (goto-char (posn-point p)))
    (treemacs-current-button)))

(defun explorer-new-file ()
  "Create a file in the folder at point, and open it."
  (interactive)
  (let ((btn (explorer--in-tree (treemacs-create-file) (treemacs-current-button))))
    (when (and btn (eq (explorer--state btn) 'file-node-closed))
      (explorer--in-tree (goto-char btn) (explorer--open btn)))))

(defun explorer-new-folder ()
  "Create a folder in the folder at point."
  (interactive)
  (explorer--in-tree (treemacs-create-dir)))

(defun explorer-rename ()
  "Rename the file or folder at point."
  (interactive)
  (explorer--in-tree (treemacs-rename-file)))

(defun explorer-trash ()
  "Move the file or folder at point to the trash, after asking."
  (interactive)
  (when-let* ((btn (treemacs-current-button))
              ((explorer--file-p btn)))
    (when (explorer--ask (format "Move “%s” to the Trash?" (explorer--name btn)) "Move to Trash")
      ;; treemacs asks again with yes-or-no-p; the dialog above already did
      (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
        (explorer--in-tree (treemacs-delete-file))))))

(defun explorer-copy-path (&optional relative)
  "Copy the path at point; RELATIVE to the project."
  (interactive)
  (when-let* ((btn (treemacs-current-button)))
    (let* ((path (treemacs-button-get btn :path))
           (text (if relative
                     (file-relative-name path (treemacs-project->path (treemacs-project-at-point)))
                   path)))
      (kill-new text)
      (message "Copied %s" text))))

(defun explorer-reveal ()
  "Show the item at point in the file manager."
  (interactive)
  (when-let* ((btn (treemacs-current-button)))
    (let ((path (treemacs-button-get btn :path)))
      (if (executable-find "nautilus")
          (call-process "nautilus" nil 0 nil "--select" path)
        (call-process "xdg-open" nil 0 nil (file-name-directory path))))))

(defun explorer--menu (items)
  "A popup keymap of easy-menu ITEMS, without the empty title row GTK shows."
  (seq-remove #'stringp (easy-menu-create-menu "" items)))

(defun explorer-menu (event)
  "The right-click menu for the row under EVENT."
  (interactive "e")
  (let* ((btn (explorer--at-event event))
         (item (and btn (explorer--file-p btn) t)))
    ;; the row the menu is for is selected before the menu opens
    (look--pill-update)
    (redisplay t)
    (popup-menu
     (explorer--menu
      `(["New File…" explorer-new-file]
        ["New Folder…" explorer-new-folder]
        "---"
        ["Rename…" explorer-rename :active ,item :keys "F2"]
        ["Move to Trash" explorer-trash :active ,item :keys "Delete"]
        "---"
        ["Copy Path" explorer-copy-path :active ,(and btn t)]
        ["Copy Relative Path" (explorer-copy-path t) :active ,item]
        ["Reveal in Files" explorer-reveal :active ,(and btn t)]))
     event)))

;; treemacs asks for names in the bottom line; ask in the same panel as
;; quick open instead
(advice-add 'treemacs--read-string :override
            (lambda (prompt &optional initial)
              ;; no "0/0" counter for a plain name, and the typed name in
              ;; plain text rather than styled as a selected entry
              (let ((vertico-count-format nil))
                (minibuffer-with-setup-hook
                    (lambda () (setq-local face-remapping-alist
                                           (cons '(vertico-current default) face-remapping-alist)))
                  (completing-read prompt nil nil nil initial)))))

;;; Keys

(define-keymap :keymap treemacs-mode-map
  "<down-mouse-1>" #'explorer-press
  "<mouse-1>" #'ignore
  "<drag-mouse-1>" #'ignore
  "<double-mouse-1>" #'ignore
  "<mouse-3>" #'explorer-menu
  "<down-mouse-3>" #'ignore
  "<f2>" #'explorer-rename
  "<delete>" #'explorer-trash
  "<deletechar>" #'explorer-trash)

(provide 'explorer)
