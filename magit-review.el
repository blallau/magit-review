;;; magit-review.el --- Magit plugin for git review command
;;
;; Copyright (C) 2015 Bertrand Lallau
;;
;; Author: Bertrand Lallau <bertrand.lallau@gmail.com>
;; URL: https://github.com/blallau/magit-review
;; Version: 0.0.1
;; Keywords: tools gerrit git
;; Package-Requires: ((emacs "25.0") (magit "2.4.0"))
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see http://www.gnu.org/licenses/.

;;; Commentary:
;;
;; Magit plugin for git review commands (list, download, browse, review)
;;
;;; To Use:
;;
;; (require 'magit-review)
;;
;;
;; M-x `magit-status'
;; h R  <= magit-review uses the R prefix, see help
;;
;;; Other Comments:
;; If your git remote for gerrit is not the default "origin", then
;; `magit-review-remote' should be adjusted accordingly (e.g. "gerrit")
;;
;; `magit-review' will be enabled automatically on `magit-status' if
;; the git review is configured (.gitreview fle exists)
;;
;;; Code:

(require 'json)
(require 'magit)

(defvar git-review-file ".gitreview" "git review conf file name")

(defvar gerrit-review-url "https://review.openstack.org/#q,%s,n,z" "Gerrit review URL")
(defvar gerrit-review-recent 24 "Time (in hours) when reviews are declare recent")

(defvar magit-review-remote "origin"
  "Default remote name to use for gerrit (e.g. \"origin\", \"gerrit\")")

(defvar-local git-review-protocol nil "Git protocol used")

(defgroup magit-review nil
  "magit review custom group"
  :group 'magit-review)

(defcustom magit-review-popup-prefix (kbd "R")
  "Key code to open magit-review popup"
  :group 'magit-review
  :type 'key-sequence)

(defun review-command (cmd &rest args)
  (let ((gcmd (concat
	       " "
	       cmd
	       " "
	       (mapconcat 'identity args " ")
	       )))
;;    (message (format "Using cmd:%s" gcmd))
    gcmd))

(defun review-query ()
  (review-command "-v -l"))

(defun magit-review-get-remote-url ()
  (magit-git-string "ls-remote" "--get-url" magit-review-remote))

(defun magit-review-string-trunc (str maxlen)
  (if (> (length str) maxlen)
      (concat (substring str 0 maxlen)
	      "...")
    str))

(defun is-new-review (create update)
  (let* ((current (current-time))
	 (review-update (if (string= git-review-protocol "https")
			    (date-to-time update)
			  (seconds-to-time update))))
    (time-less-p (time-subtract current review-update)
		 (seconds-to-time (* 60 60 gerrit-review-recent)))))

(defface magit-review-number-bold
  '((t :foreground "#ff8700" :weight bold))
  "Face for the new Gerrit review."
  :group 'review-faces)

(defface magit-review-number
  '((t :foreground "#ff8700"))
  "Face for Gerrit review."
  :group 'review-faces)

(defface magit-review-title-merg
  '((t :foreground "#a1db00"))
  "Face for review mergeable."
  :group 'review-faces)

(defface magit-review-title-not-merg
  '((t :foreground "red"))
  "Face for review not mergeable."
  :group 'review-faces)

(defun magit-review-pp-commit (commit-msg)
  (let ((commit-msg-str (propertize (format "%s" commit-msg) 'face 'magit-refname)))
    (format "%s" commit-msg-str)))

(defun magit-review-pp-https-review (num subj branch topic create update &optional merg ins_num del_num)
  ;; window-width - two prevents long line arrow from being shown
  (let* ((wid (window-width))

	 (numstr (propertize (format "%-8s" num)
			     'face
			     (if (is-new-review create update)
			      	 'magit-review-number-bold
			       'magit-review-number)
			     ))
	 (nlen (length numstr))

	 (diff (concat "["
		       (propertize (if (> ins_num 0) (format "+%s" ins_num) (format "%s" ins_num))
				   'face '(:foreground "green yellow" :weight bold))
		       " "
		       (propertize (if (> del_num 0) (format "-%s" del_num) (format "%s" del_num))
				   'face '(:foreground "red" :weight bold))
		       "]"))

	 (difflen (length diff))
	 (btmaxlen (/ wid 3))
	 (bt (propertize (magit-review-string-trunc (if topic
							(format "%s (%s)" branch topic)
						      (format "%s" branch))
						    btmaxlen)
			 'face '(:foreground "deep sky blue")))

	 (subjmaxlen (min 50 (- wid nlen btmaxlen difflen 5)))
	 (subjstr (propertize (magit-review-string-trunc subj subjmaxlen)
			      'face
			      (if (equal merg :json-false)
				  'magit-review-title-not-merg
				'magit-review-title-merg)))
	 (padding (make-string
		     (max 0 (- wid (+ nlen 1 (length bt) 2 difflen (length subjstr))))
		     ? )))
    (format "%s%s  %s%s%s\n" numstr subjstr diff padding bt)))

(defun magit-review-pp-ssh-review (num subj branch topic create update &optional owner)
  ;; window-width - two prevents long line arrow from being shown
  (let* ((wid (window-width))
	 (numstr (propertize (format "%-8s" num)
			     'face
			     (if (is-new-review create update)
			      	 'magit-review-number-bold
			       'magit-review-number)
			     ))
	 (nlen (length numstr))
	 (btmaxlen (/ wid 3))
	 (ownermaxlen (/ wid 4))

	 (bt (propertize (magit-review-string-trunc (if topic
							(format "%s (%s)" branch topic)
						      (format "%s" branch))
						    btmaxlen)
			 'face '(:foreground "deep sky blue")))

	 (owner (propertize (magit-review-string-trunc owner ownermaxlen)
			    'face 'magit-log-author))

	 (subjmaxlen (min 50 (- wid nlen ownermaxlen btmaxlen 6)))

	 (subjstr (propertize (magit-review-string-trunc subj subjmaxlen)
			      'face 'magit-review-title-merg))
	 (padding (make-string
		     (max 0 (- wid (+ nlen 1 (length subjstr) 1 (length owner) 1 (length bt))))
		     ? )))
    (format "%s%s %s %s%s\n" numstr subjstr owner padding bt)))

(defun json-review-https-list-to-clean ()
  (if (search-forward-regexp "^)\\]}'$" (point-max) t)
      t
    nil))

(defun json-review-ssh-list-to-clean ()
  (if (search-forward-regexp "^{\"type\":\"stats\",\"rowCount\":[0-9]+.*}$" (point-max) t)
      t
    nil))

(defun magit-review-wash-review ()
  (cond
   ((string= git-review-protocol "https")
    (progn
      ;; clean review list
      (let ((json-to-clean (save-excursion (json-review-https-list-to-clean))))
	(when json-to-clean
	  (let ((beg (point)))
	    (search-forward-regexp "^\\[.?$")
	    (forward-line)
	    (delete-region beg (point-at-bol)))
	  (search-forward-regexp "^.?\\]$")
	  (delete-region (point-at-bol) (point-max))
	  (goto-char (point-min))))
      ;; process JSON
      (let* ((beg (point))
	     (jobj (json-read))
	     (end (point-at-eol))
	     (branch (cdr-safe (assoc 'branch jobj)))
	     (topic (cdr-safe (assoc 'topic jobj)))
	     (change_id (cdr-safe (assoc 'change_id jobj)))
	     (subj (cdr-safe (assoc 'subject jobj)))
	     ;; "created": "2016-01-12 20:38:22.000000000",
	     ;; "updated": "2016-01-12 20:43:10.000000000",
	     (create (cdr-safe (assoc 'created jobj)))
	     (update (cdr-safe (assoc 'updated jobj)))
	     (merg (cdr-safe (assoc 'mergeable jobj)))
	     (ins_num (cdr-safe (assoc 'insertions jobj)))
	     (del_num (cdr-safe (assoc 'deletions jobj)))
	     (num (cdr-safe (assoc '_number jobj))))
	(if (and beg end)
	    (delete-region beg end))
	(when (and num subj branch)
	  (magit-insert-section (section subj)
	    (insert (propertize
		     (magit-review-pp-https-review num subj branch topic create update merg ins_num del_num)
		     'magit-review-jobj
		     jobj))
	    (add-text-properties beg (point) (list 'magit-review-jobj jobj)))
	  t))))

   ((string= git-review-protocol "ssh")
    (progn
      ;; clean review list
      (let ((json-to-clean (save-excursion (json-review-ssh-list-to-clean))))
	(when json-to-clean
	  (let ((beg (point)))
	    (search-forward-regexp (format ".* Running: ssh -x.* %s query --format=JSON project:.* status:open$" magit-review-remote))
	    (forward-line)
	    (delete-region beg (point-at-bol)))
	  (search-forward-regexp "^{\"type\":\"stats\",\"rowCount\":[0-9]+,\"runTimeMilliseconds\":[0-9]+,\"moreChanges\":false}$")
	  (delete-region (point-at-bol) (point-max))
	  (goto-char (point-min))))

      ;; process JSON
      (let* ((beg (point))
	     (jobj (json-read))
	     (end (point-at-eol))
	     (branch (cdr-safe (assoc 'branch jobj)))
	     (topic (cdr-safe (assoc 'topic jobj)))
	     (change_id (cdr-safe (assoc 'id jobj)))
	     (num (cdr-safe (assoc 'number jobj)))
	     (subj (cdr-safe (assoc 'subject jobj)))
	     (owner (cdr-safe (assoc 'owner jobj)))
	     (owner-name (cdr-safe (assoc 'name owner)))
	     (commit-msg (cdr-safe (assoc 'commitMessage jobj)))
	     ;;createdOn":1452631102,"lastUpdated":1452631390
	     (create (cdr-safe (assoc 'createdOn jobj)))
	     (update (cdr-safe (assoc 'lastUpdated jobj))))
	(if (and beg end)
	    (delete-region beg end))
	(when (and num subj branch)
	  (magit-insert-section (section subj)
	    (insert (propertize
		     (magit-review-pp-ssh-review num subj branch topic create update owner-name)
		     'magit-review-jobj
		     jobj))
	    (unless (magit-section-hidden (magit-current-section))
	      (magit-insert-section (section commit-msg)
		(insert (magit-review-pp-commit commit-msg) "\n")))
	    (add-text-properties beg (point) (list 'magit-review-jobj jobj)))
	  t))))))

(defun magit-review-wash-reviews (&rest args)
  (magit-wash-sequence #'magit-review-wash-review))

(defun magit-review-section (section title washer &rest args)
  (let ((magit-git-executable "git-review")
	(magit-git-global-arguments nil))
    (magit-insert-section (section title)
      (magit-insert-heading title)
      (magit-git-wash washer (split-string (car args)))
      (insert "\n"))))

(defun magit-review-remote-update (&optional remote)
  nil)

(defun magit-review-at-point ()
  (get-text-property (point) 'magit-review-jobj))

(defun magit-review-number-at-point ()
  (let ((jobj (magit-review-at-point)))
    (if jobj
	(cond
	 ((string= git-review-protocol "https")
	  (number-to-string (cdr (assoc '_number jobj))))
	 ((string= git-review-protocol "ssh")
	  (cdr (assoc 'number jobj))))
      nil)))

;;;###autoload
(defun magit-review-download-review ()
  "Download a Gerrit Review"
  (interactive)
  (let ((jobj (magit-review-at-point)))
    (when jobj
      (let ((ref (magit-review-number-at-point))
	    (topic (cdr (assoc 'topic jobj)))
	    (dir default-directory))
	(let* ((magit-proc (magit-run-git-async-no-revert "review" "-d" ref)))
	  (message (format "Waiting git review -d %s to complete..." ref))
	  (magit-process-wait))
	(message (format "Checking out to %s in %s" topic dir))))))

;;;###autoload
(defun magit-review-browse-review ()
  "Browse the Gerrit Review with a browser."
  (interactive)
  (let ((number (magit-review-number-at-point)))
    (when number
      (let ((gerrit-url (format gerrit-review-url number)))
	(browse-url gerrit-url)))))

(defun magit-insert-reviews ()
  (magit-review-section 'gerrit-reviews
			"Reviews:" 'magit-review-wash-reviews
			(review-query)))

(defun magit-review-popup-args (&optional something)
  (or (magit-review-arguments) (list "")))

(defun magit-review-push-review (status)
  (let* ((branch (or (magit-get-current-branch)
		     (error "Don't push a detached head. That's gross")))
	 (commitid (or (when (eq (magit-section-type (magit-current-section))
				 'commit)
			 (magit-section-value (magit-current-section)))
		       (error "Couldn't find a commit at point")))
	 (rev (magit-rev-parse (or commitid
				   (error "Select a commit for review"))))
	 (branch-remote (and branch (magit-get "branch" branch "remote"))))

      (when (string= branch-remote ".")
	(setq branch-remote magit-review-remote))
      (if (string= status "drafts")
	  (magit-run-git-async "review -D")
	(magit-run-git-async "review"))))

;;;###autoload
(defun magit-review-create-review ()
  (interactive)
  (magit-review-push-review 'publish))

;;;###autoload
(defun magit-review-create-draft ()
  (interactive)
  (magit-review-push-review 'drafts))

(defun magit-review-create-branch (branch parent))

;;;###autoload (autoload 'magit-review-popup "magit-review" nil t)
(magit-define-popup magit-review-popup
  "Popup console for magit review commands."
  'magit-review
  :man-page "git-review"
  :actions '((?P "Push Commit For Review"                          magit-review-create-review)
	     (?W "Push Commit For Draft Review"                    magit-review-create-draft)
	     (?b "Browse Review"                                   magit-review-browse-review)
	     ;;	     (?A "Add Reviewer"                                    magit-review-add-reviewer)
	     (?d "Download Review"                                 magit-review-download-review)
	     )
  :default-action 'magit-review-browse-review
  :max-action-columns 3)

;; Attach Magit Review to Magit's default help popup
(magit-define-popup-action 'magit-dispatch-popup ?R "Review"
  'magit-review-popup)

;;; Sections
(defvar magit-review-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [remap magit-visit-thing] 'magit-review-browse-review)
    (define-key map magit-review-popup-prefix 'magit-review-popup)
    map)
  "Keymap for `Reviews' section.")

(define-minor-mode magit-review-mode "Review support for Magit"
  :lighter " Review"
  :keymap 'magit-review-mode-map
  (or (derived-mode-p 'magit-mode)
      (error "This mode only makes sense with magit"))
  (or (magit-review-get-remote-url)
      (error "You *must* set `magit-review-remote' to a valid Gerrit remote"))
  (cond
   (magit-review-mode
    ;; add magit-insert-reviews section next to magit-insert-stashes section
    (magit-add-section-hook 'magit-status-sections-hook
			    'magit-insert-reviews
			    'magit-insert-stashes t t)
    (add-hook 'magit-create-branch-command-hook
	      'magit-review-create-branch nil t)
    (add-hook 'magit-remote-update-command-hook
	      'magit-review-remote-update nil t)
    (add-hook 'magit-push-command-hook
	      'magit-review-push nil t))

   (t
    (remove-hook 'magit-after-insert-stashes-hook
		 'magit-insert-reviews t)
    (remove-hook 'magit-create-branch-command-hook
		 'magit-review-create-branch t)
    (remove-hook 'magit-remote-update-command-hook
		 'magit-review-remote-update t)
    (remove-hook 'magit-push-command-hook
		 'magit-review-push t)))
  (when (called-interactively-p 'any)
    (magit-refresh)))

(defun magit-review-check-gerrit-enabled ()
  (let ((project-root (magit-toplevel)))
    (if (file-exists-p (concat project-root git-review-file))
	t
      nil)))

(defun magit-review-enable ()
  ;;  check git review
  (when (magit-review-check-gerrit-enabled)
    (let* ((remote-url (magit-review-get-remote-url))
	   (url-type (url-type (url-generic-parse-url remote-url))))
      (cond
       ((string= url-type "ssh")
	(set (make-local-variable 'git-review-protocol) "ssh"))
       ((string= url-type "https")
	(set (make-local-variable 'git-review-protocol) "https")))
      ;; update keymap with prefix incase it has changed
      (define-key magit-review-mode-map magit-review-popup-prefix 'magit-review-popup)
      (magit-review-mode t))))

;; Hack in dir-local variables that might be set for magit review
(add-hook 'magit-status-mode-hook #'hack-dir-local-variables-non-file-buffer t)

(add-hook 'magit-status-mode-hook #'magit-review-enable t)
(add-hook 'magit-log-mode-hook #'magit-review-enable t)

(provide 'magit-review)

;;; magit-review.el ends here
