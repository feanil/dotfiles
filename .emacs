(require 'package)
(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))
(package-initialize)

(require 'evil)
(evil-mode 1)

(require 'powerline)
(powerline-center-evil-theme)
(set-face-attribute 'mode-line nil
		    :background "DarkOrange"
		    :foreground "Black"
		    :box nil)

(load-theme 'zenburn t)

(menu-bar-mode -1)
(tool-bar-mode -1)

(setq
 backup-by-copying t ; don't clobber symlinks
 backup-directory-alist '(("." . "~/.emacs-saves" ))
 delete-old-versions t
 kept-new-versions 6
 kept-old-versions 2
 version-control t)
