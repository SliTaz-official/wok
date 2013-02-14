;; lua-mode start file for SliTaz
;; Last update: 2013-02-08
;;
;; To set up Emacs to automatically edit files ending in .lua using Lua-mode

(autoload 'lua-mode "lua-mode" "Lua editing mode." t)
(add-to-list 'auto-mode-alist '("\\.lua$" . lua-mode))
(add-to-list 'interpreter-mode-alist '("lua" . lua-mode))


