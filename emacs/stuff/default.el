;; Emacs default file for SliTaz
;; (C) GNU gpl v3 - SliTaz GNU/Linux 2009-2013
;; Last update: 2013-02-21
;;
;; Add support for SliTaz receipt files
;; force emacs in shell-script-mode
(setq auto-mode-alist (cons '("receipt" . shell-script-mode) auto-mode-alist))

;; Force emacs to use tabs
;;  from Scott Hurring's HOWTO
;;  turn on tabs
(setq indent-tabs-mode t)
(setq-default indent-tabs-mode t)

;;  bind the TAB key
(global-set-key (kbd "TAB") 'self-insert-command)

;;  set the tab width
(setq default-tab-width 4)
(setq tab-width 4)
(setq c-basic-indent 4)


;; Following lines has been grabbed from dot emacs file for Maemo:
;; christof sietchtabr at gmail
;;
;; the dired, list-directory, and gzip fixes all come from the
;; packager of the emacs deb and responses from other maemo community members
;; http://danielsz.freeshell.org/code/mine/emacs-for-maemo/index.shtml
;;
;; make dired work
;; --dired option is not supported on busybox ls command
(setq dired-use-ls-dired nil)

;; make list-directory work
;; -F not supported by busybox ls command
(setq list-directory-brief-switches "-C")

;; we *REALLY* don't want to spew file backups all over the fs.
;; code to place all backups in one location
(when (not (file-directory-p "~/.emacs.backup"))
  (make-directory "~/.emacs.backup"))
(if (file-directory-p "~/.emacs.backup")
    (setq backup-directory-alist '(("." . "~/.emacs.backup"))))

;; custom variable setting to make info work using busybox gzip
(custom-set-variables
;; custom-set-variables was added by Custom.
;; If you edit it by hand, you could mess it up, so be careful.
;; Your init file should contain only one such instance.
;; If there is more than one, they won't work right.
 '(jka-compr-compression-info-list (quote (["\\.Z\\(~\\|\\.~[0-9]+~\\)?\\'" \
"compressing" "compress" ("-c") "uncompressing" "uncompress" \
("-c") nil t "^_\x9d"] ["\\.bz2\\(~\\|\\.~[0-9]+~\\)?\\'" "bzip2ing" ^
"bzip2" nil "bunzip2ing" "bzip2" ("-d") nil t "BZh"] ["\\.tbz\\'" "bzip2ing" \
"bzip2" nil "bunzip2ing" "bzip2" ("-d") nil nil "BZh"] \
["\\.tgz\\'" "compressing" "gzip" ("-c") "uncompressing" "gzip" \
("-c" "-q" "-d") t nil "^_\x8b"] ["\\.g?z\\(~\\|\\.~[0-9]+~\\)?\\'" \
"compressing" "gzip" ("-c") "uncompressing" "gzip" ("-c" "-d") t t \
"^_\x8b"] ["\\.dz\\'" nil nil nil "uncompressing" "gzip" ("-c" "-d") nil \
t "^_\x8b"]))))
