;;; ob-verb.el --- Babel integration for Verb  -*- lexical-binding: t -*-

;; Copyright (C) 2020  Federico Tedin

;; Author: Federico Tedin <federicotedin@gmail.com>
;; Maintainer: Federico Tedin <federicotedin@gmail.com>
;; Homepage: https://github.com/federicotdn/verb
;; Keywords: tools
;; Package-Version: 2.0.0
;; Package-Requires: ((emacs "26"))

;; This file is NOT part of GNU Emacs.

;; verb is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; verb is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
;; License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with verb.  If not, see http://www.gnu.org/licenses.

;;; Commentary:

;; This file contains the necessary functions to integrate Verb with
;; Org mode's Babel.

;;; Code:
(require 'verb)

(defun org-babel-execute:verb (body params)
  "Exeucute an action on the selected Babel source block.
BODY should contain the body of the source block, and PARAMS any
header arguments passed to it.  This function is called by
`org-babel-execute-src-block'.

PARAMS may contain an (:op . OPERATION) element.  If it does, use
string OPERATION to decide what to do with the code block.  Valid
options are:

  \"send\": Send the HTTP request specified in the source block.
  \"export curl\": Export request spec to curl format.
  \"export human\": Export request spec to human-readable format.
  \"export verb\": Export request spec to verb format.

The default value for OPERATION is \"send\"."
  (let* ((rs (verb--request-spec-from-babel-src-block (point) body))
	 (processed-params (org-babel-process-params params))
	 (op (or (cdr (assoc :op processed-params))
		"send")))
    (pcase op
      ("send"
       (ob-verb--send-request rs))
      ((guard (string-prefix-p "export " op))
       (ob-verb--export-request rs (nth 1 (split-string op))))
      (_
       (user-error "Invalid value for :op argument: %s" op)))))

(defun ob-verb--export-request (rs name)
  "Export the request specified by the selected Babel source block.
RS should contain the request spec extracted from the source block.
NAME should be the name of a request export function.  Return a string
with the contents of the exported request.

Called when :op `export' is passed to `org-babel-execute:verb'."
  (pcase name
    ("human"
     (save-window-excursion
       (with-current-buffer (verb--export-to-human rs)
	 (buffer-string))))
    ("verb"
     (save-window-excursion
       (with-current-buffer (verb--export-to-verb rs)
	 (buffer-string))))
    ("curl"
     (verb--export-to-curl rs t t))
    (_
     (user-error "Invalid export function: %s" name))))

(defun ob-verb--send-request (rs)
  "Send the request specified by the selected Babel source block.
RS should contain the request spec extracted from the source block.
Note that Emacs will be blocked while waiting for a response.  The
timeout for this can be configured via the `verb-babel-timeout'
variable.  Return the contents of the response as a string.

Called when :op `send' is passed to `org-babel-execute:verb'."
  (let* ((start (time-to-seconds))
	 (buf (verb--request-spec-send rs nil)))
    (while (and (eq (buffer-local-value 'verb-http-response buf) t)
		(< (- (time-to-seconds) start) verb-babel-timeout))
      (sleep-for 0.1))
    (with-current-buffer buf
      (if (eq verb-http-response t)
	  (format "(Request timed out after %.4g seconds)"
		  (- (time-to-seconds) start))
	(verb-response-to-string verb-http-response)))))

;;;###autoload
(define-derived-mode ob-verb-response-mode special-mode "ob-verb"
  "Major mode for displaying HTTP responses with Babel."
  (font-lock-add-keywords
   nil `(;; HTTP/1.1 200 OK
	 ("^HTTP/1\\.[01]\\s-+[[:digit:]]\\{3\\}.*$"
	  (0 'verb-http-keyword))
	 ;; Key: Value
	 (,verb--http-header-regexp
	  (1 'verb-header)))))

(provide 'ob-verb)
;;; ob-verb.el ends here