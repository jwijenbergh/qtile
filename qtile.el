;;; qtile.el -*- lexical-binding: t; -*-

(load "/home/jerry/Repos/qtile/buffer-focus-hook.el")
(require 'buffer-focus-hook)

(define-derived-mode qtile-mode nil "Qtile"
  ;; Change major-mode is not allowed
  (add-hook 'change-major-mode-hook #'kill-buffer nil t)
  ;; Killing the buffer needs qtile to close the window!
  (add-hook 'kill-buffer-query-functions #'qtile--kill-buffer-query-function nil t)
  (setq buffer-read-only t
        cursor-type nil
        left-margin-width nil
        right-margin-width nil
        left-fringe-width 0
        right-fringe-width 0
        vertical-scroll-bar nil))

(defvar qtile--skip-buffer-list-update nil)
(defvar qtile--buffers nil)
(defvar qtile--frame nil)
(defvar-local qtile--buffer-wid nil)
(defvar qtile--socket nil)

(defun qtile--kill-buffer-query-function ()
  (let ((buf (current-buffer)))
    (when (derived-mode-p #'qtile-mode)
      (qtile--send-cmd "emacs_remove_wid" qtile--buffer-wid))))

(defun qtile--refresh (&optional frame)
  (unless frame
    (setq frame (selected-frame)))
  (when (eq frame qtile--frame)
    (qtile--send-cmd "emacs_refresh" (qtile--buffers-pos))))

(defun qtile--buffers-pos ()
  (let ((hsh (make-hash-table))
	(windows (window-list qtile--frame 'nomini))) ; windows excluding minibuffer
    (dolist (window windows)
      (with-current-buffer (window-buffer window)
	(when (derived-mode-p #'qtile-mode)
	  (puthash (number-to-string qtile--buffer-wid) (window-inside-absolute-pixel-edges window) hsh))))
    (json-encode-hash-table hsh)))

(defun qtile--send-cmd (msg &optional args)
  (when qtile--socket
    (let ((socket (make-network-process
		   :name "qtile"
		   :buffer "qtile-socket"
		   :host "local"
		   :remote qtile--socket)))
      (if args
	  (process-send-string socket (format "[[[\"layout\", null]], \"%s\", [%s], {}]" msg (json-serialize args)))
	(process-send-string socket (format "[[[\"layout\", null]], \"%s\", [], {}]" msg)))
      (process-send-eof socket))))

(defun qtile--init (socket)
  (setq qtile--frame (selected-frame))
  (setq qtile--socket socket)
  (setq qtile--buffers (make-hash-table))
  (add-hook 'focus-out-hook #'qtile--refresh)
  (add-hook 'focus-in-hook #'qtile--refresh)
  (add-hook 'window-size-change-functions #'qtile--refresh)
  (add-hook 'window-configuration-change-hook #'qtile--refresh))

(defun qtile--focus-in ()
  ;(redirect-frame-focus (selected-frame) nil)
  (qtile--send-cmd "emacs_focus_wid" qtile--buffer-wid))

(defun qtile--fixup-focus ()
  ;(redirect-frame-focus (selected-frame) nil)
  (with-current-buffer (current-buffer)
    (message (buffer-name))
    (when (derived-mode-p #'qtile-mode)
	(qtile--send-cmd "emacs_focus_wid" qtile--buffer-wid))))
  

(defun qtile-create-buffer (name wid)
  (let ((qtile--skip-buffer-list-update t))
    (let ((buf (generate-new-buffer name)))
      (puthash wid buf qtile--buffers)
      (with-current-buffer buf
	(qtile-mode)
	(setq-local qtile--buffer-wid wid)
	(buffer-focus-in-callback 'qtile--focus-in)))))

(defun qtile-switch-buffer (wid)
  (let ((buf (gethash wid qtile--buffers)))
    (when buf
      ;; check if this window is already present somewhere, then we will not switch to it but focus it
      (if (not (get-buffer-window buf))
	  (switch-to-buffer buf)
	;; Just select it
	(select-window (get-buffer-window buf))))))

(defun qtile-close-buffer (wid)
  (let ((buf (gethash wid qtile--buffers)))
    (when buf
      (remhash wid qtile--buffers)
      (kill-buffer buf)
      (with-current-buffer (window-buffer (selected-window))
	(when (derived-mode-p #'qtile-mode)
	  qtile--buffer-wid)))))


      ;; handle focus
      ;(with-current-buffer (current-buffer)
      ;	(message (buffer-name))
      ;	(if (derived-mode-p #'qtile-mode)
      ;	    (qtile--send-cmd "emacs_focus_wid" qtile--buffer-wid)
      ;	  (qtile--send-cmd "focus_emacs"))))))
