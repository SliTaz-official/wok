;; site-start.el for SliTaz                     -*- no-byte-compile: t -*-
;;
;; (C) GNU gpl v3 - SliTaz GNU/Linux 2009.
;;
;; Default site startup file for Emacs. You may modify this file, replace it by
;; your own site initialisation, or even remove it completely.
;;
;; Load package startups in this site-start.d folder
(if (file-accessible-directory-p "/usr/share/emacs/site-lisp/site-start.d")
	(let ((dir (directory-files "/usr/share/emacs/site-lisp/site-start.d/" t
					".\\.el$")))
		(while dir (load (car dir) nil t t) (setq dir (cdr dir)))))
