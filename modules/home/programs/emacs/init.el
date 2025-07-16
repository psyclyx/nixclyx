;;;-*- lexical-binding: t -*-

(eval-and-compile
  (defvar no-littering-etc-directory (expand-file-name "etc/" "~/.local/state/emacs"))
  (defvar no-littering-var-directory (expand-file-name "var/"  "~/.cache/emacs"))
  (require 'no-littering))

(require 'org)

(delete-file (expand-file-name "config.el" user-emacs-directory))
(org-babel-load-file (expand-file-name "config.org" user-emacs-directory))
