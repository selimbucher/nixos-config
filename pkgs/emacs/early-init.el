;;; early-init.el --- before the first frame  -*- lexical-binding: t -*-

(setq gc-cons-threshold (* 64 1024 1024)
      inhibit-startup-screen t
      inhibit-startup-echo-area-message user-login-name
      initial-scratch-message nil
      frame-inhibit-implied-resize t
      frame-resize-pixelwise t
      frame-title-format "%b")

;; No menu, tool or scroll bars; set here so the first frame never draws them.
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(push '(internal-border-width . 0) default-frame-alist)
(setq menu-bar-mode nil
      tool-bar-mode nil
      scroll-bar-mode nil)

;; no "For information about GNU Emacs..." in the echo area
(advice-add 'display-startup-echo-area-message :override #'ignore)

;; No minibuffer line in the window: the minibuffer lives in a frame of its
;; own, made hidden here and turned into a floating panel by look.el.
(push '(minibuffer . nil) default-frame-alist)
(setq minibuffer-frame-alist
      '((visibility . nil) (undecorated . t) (minibuffer . only)
        (width . 80) (height . 1) (menu-bar-lines . 0) (tool-bar-lines . 0)
        (vertical-scroll-bars) (internal-border-width . 0)))
