;; Register

(require 'text-translator)


;; set global key

(global-set-key "\C-x\M-t" 'text-translator)
(global-set-key "\C-x\M-T" 'text-translator-translate-last-string)
;; translate all sites.
;; for example, if you specify "enja", text-translator use google.com_enja, yahoo.com_enja, ... .
(global-set-key "\C-x\M-a" 'text-translator-all)


;; add keys to major-mode

(add-hook
 'text-translator-mode-hook
 (lambda()
   ;; if you do not change prefix-key, it is executed by C-c M-a
   (define-key text-translator-mode-pkey-map "\M-a" 'text-translator-translate-recent-type)))


;; use proxy

;; ;; if you are setting environment variables HTTP_PROXY,
;; ;; you have not to set this.
;; (setq text-translator-proxy-server "proxy.hogehoge.com")
;; (setq text-translator-proxy-port   8080)

