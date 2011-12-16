(require 'xml-rpc)
(require 'versions)
(defconst min-xml-rpc-version "1.6.8.1" "minimum version requirement for xml-rpc mode")

;; To install:
;;   copy or link to this file to a directory in Emacs' load-path (view with C-h v load-path)
;;   and add this line to your .emacs or preferences file:
;;     (autoload 'ltc-mode "ltc-mode" "" t)
;; To run:
;;   make sure that LTC server is running
;;   M-x ltc-mode to toggle
;;   M-x ltc-update to run update

;;; ----------------------------------------------------------------------------
;;; constants
;;;

(defconst on_disk "on disk" "SHA1 used for files with modifications on disk.")
(defconst modified "modified" "SHA1 used for files with modifications in buffer.")
(defconst edit-insert "INSERT" "edit key for insertions")
(defconst edit-remove "REMOVE" "edit key for removals")
(defconst edit-delete "DELETE" "edit key for deletions")

;;; ----------------------------------------------------------------------------
;;; minor mode declarations
;;;

(defgroup ltc nil
  "Latex Track Changes mode."
  :tag "LTC"
  :prefix "ltc-"
  :group 'tex)

(defcustom ltc-port 7777
  "Port on localhost used for communication with an LTC server."
  :type '(integer)
  :tag "Port"
  :group 'ltc)

;;; keeping track of filtering settings

(defvar ltc-show-deletions t "Show deletions")
(defvar ltc-show-small t "Show small changes")
(defvar ltc-show-preamble nil "Show changes in preamble")
(defvar ltc-show-comments nil "Show changes in comments")
(defvar ltc-show-commands t "Show changes in commands")
(defconst show-map
  '((ltc-show-deletions . "DELETIONS")
    (ltc-show-small . "SMALL")
    (ltc-show-preamble . "PREAMBLE")
    (ltc-show-commands . "COMMANDS")
    (ltc-show-comments . "COMMENTS"))
  "define mappings from custom options to show/hide changes to the string used in command.")
;;; the following filters are buffer-local:
(defvar ltc-limiting-authors nil "Set of authors to limit commit graph.")
(defvar ltc-limiting-date nil "Date to limit commit graph.")
(defvar ltc-limiting-rev nil "Revision to limit commit graph.")
(defconst limit-vars 
  '(ltc-limiting-authors ltc-limiting-date ltc-limiting-rev)
  "all variables that are affecting buffer-local limiting")
(mapc 'make-variable-buffer-local limit-vars)

(defvar session-id nil "current LTC session ID.")
(make-variable-buffer-local 'session-id)

(defvar commit-graph nil 
  "Commit graph structure containing one element per commit: 
(sha1 date (author-name author email) message isActive (list-of-parents) (list-of-children))")
(make-variable-buffer-local 'commit-graph)

(defvar self nil "3-tuple of current author when session is initialized.")
(make-variable-buffer-local 'self)

(defvar recent-edits nil "collect recent edits between LTC calls.")
(make-variable-buffer-local 'recent-edits)

(defvar ltc-minor-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-lu" 'ltc-update)
    (define-key map "\C-lq" 'ltc-mode)
    (define-key map "\C-lla" 'ltc-limit-authors)
    (define-key map "\C-lld" 'ltc-limit-date)
    (define-key map "\C-llr" 'ltc-limit-rev)
    (define-key map "\C-lc" 'ltc-commit)
    map)
  "LTC minor-mode keymap.")

(define-minor-mode ltc-mode
  "Toggle LTC mode.

     With no argument, this command toggles the mode.
     Non-null prefix argument turns on the mode.
     Null prefix argument turns off the mode.
     
     When LTC (Latex Track Changes) mode is enabled, 
     it shows all changes in the history of the current
     buffer file as obtained from the underlying git repository."
  :init-value nil
  :lighter " LTC"
  :keymap ltc-minor-mode-map
  :group 'ltc
  (if ltc-mode
      (progn
	;; Mode was turned on
	(easy-menu-add ltc-minor-mode-menu ltc-minor-mode-map)
	(ltc-mode-start))
    ;; Mode was turned off
    (ltc-mode-stop)
    (easy-menu-remove ltc-minor-mode-menu))
  )

;; adding LTC to context menu of latex mode
(if (fboundp 'add-minor-mode)
    (progn
      (put 'ltc-mode :included '(eq major-mode 'latex-mode))
      (put 'ltc-mode :menu-tag "LTC Mode")
      (add-minor-mode 'ltc-mode
		      " LTC" 
		      ltc-minor-mode-map
		      nil
		      'ltc-mode))
  (unless (assoc 'ltc-mode minor-mode-alist)
    (push '(ltc-mode " LTC") minor-mode-alist))
  (unless (assoc 'ltc-mode minor-mode-map-alist)
    (push (cons 'ltc-mode ltc-minor-mode-map) minor-mode-map-alist)))

(easy-menu-define
  ltc-minor-mode-menu ltc-minor-mode-map "Menu keymap for LTC."
 '("LTC"
   ["Update buffer" ltc-update]
   "--"
   "FILTERING"
   ("Show/Hide" :filter (lambda (ignored)  
    			  (mapcar (lambda (show-var) (vector  
						      (documentation-property show-var 'variable-documentation) 
						      (list 'list
						       (list 'setq show-var (list 'not show-var)) 
						       (list 'ltc-method-call 
							     "set_show" 
							     (list 'cdr (list 'assoc (list 'quote show-var) 'show-map)) 
							     show-var) 
						       '(ltc-update)) 
						      :style 'toggle :selected show-var :key-sequence nil)
				    ) (mapcar 'car show-map))
    			  ))
   ("Limit by"
    ["Set of authors..." ltc-limit-authors
     :label (concat "Set of authors" 
		    (if ltc-limiting-authors
			;; show a list of initials
			(concat " ["
				(mapconcat (lambda (name) (mapconcat (lambda (word) (substring word 0 1)) 
								     (split-string (upcase name)) "")) 
					   (mapcar 'car ltc-limiting-authors) " ")
				"]...")
		      "..."))]
    ["Until date..." ltc-limit-date
     :label (concat "Until date" 
      		    (if (or (not ltc-limiting-date) (string= "" ltc-limiting-date))
      			"..."
      		      (concat " [" ltc-limiting-date "]...")))]
    ["Until revision..." ltc-limit-rev 
     :label (concat "Until revision" 
		    (if (or (not ltc-limiting-rev) (string= "" ltc-limiting-rev))
			"..."
		      (concat " [" (shorten 7 ltc-limiting-rev) "]...")))]
    )
   ;; "--"
   ;; ["Commit..." ltc-commit]
   ;; ["Pull from remote..." nil :active nil]
   ;; ["Push to remote..." nil :active nil]
   "--"
   ["Turn LTC off" ltc-mode]
   ))

;;; ----------------------------------------------------------------------------
;;; mode implementation
;;;

(defvar ltc-info-buffer "" "string for temp buffer with LTC info")
(make-variable-buffer-local 'ltc-info-buffer)

(defun ltc-mode-start ()
  "start LTC mode"
  (message "Starting LTC mode for file \"%s\"..." (buffer-file-name))
  (if (not (condition-case err 
	       (progn
		 ;; testing xml-rpc version
		 (message "Using `xml-rpc' package version: %s" xml-rpc-version)
		 (and (version< xml-rpc-version min-xml-rpc-version)
		      (error "`ltc-mode' requires `xml-rpc' package v%s or later" min-xml-rpc-version))
		 ;; init session with file name and buffer contents if modified (or "" if not)
		 (setq session-id 
		       (ltc-method-call "init_session" 
					(buffer-file-name) 
					(if (buffer-modified-p) 
					    (buffer-string) 
					  ""))))
	     ;; handling any initialization errors
	     ('error 
	      (message "Error while initializing session: %s" (error-message-string err))
	      nil))) ; 
      (ltc-mode 0) ; an error occurred: toggle mode off again
    ;; else-forms: initialization of session was successful:
    (message "LTC session ID = %d" session-id)
    (setq ltc-info-buffer (concat "LTC info (session " (number-to-string session-id) ")"))
    ;; update filtering settings
    (mapc (lambda (show-var) 
	    (set show-var (ltc-method-call "get_show" (cdr (assoc show-var show-map))))) (mapcar 'car show-map))
    (mapc (lambda (var) 
	    (set var 'nil)) 
	  limit-vars)
    (font-lock-mode 0) ; turn-off latex font-lock mode
    (add-hook 'write-file-functions 'ltc-hook-before-save nil t) ; add (local) hook to intercept saving to file
    (add-hook 'kill-buffer-hook 'ltc-hook-before-kill nil t) ; add hook to intercept closing buffer
    ;; initialize known authors, commit graph and self
    (init-commit-graph)
    (setq self (ltc-method-call "get_self" session-id)) ; get current author and color
    (ltc-update)))

(defun ltc-mode-stop ()
  "stop LTC mode"  
  (setq self nil) ; reset information about current author
  (ltc-remove-edit-hooks) ; remove (local) hooks to capture user's edits
  (remove-hook 'write-file-functions 'ltc-hook-before-save t) ; remove (local) hook to intercept saving to file
  (remove-hook 'kill-buffer-hook 'ltc-hook-before-kill t) ; remove hook to intercept closing buffer
  ;; close session and obtain text for buffer without track changes
  (if session-id
      (let ((text (ltc-method-call "close_session" session-id (compile-recent-edits)))
	    (old-buffer-modified-p (buffer-modified-p))) ; maintain modified flag
	(message "Stopping LTC mode for file \"%s\"..." (buffer-file-name))
	;; replace text in buffer with return value from closing session
	(erase-buffer)
	(insert text)
	(set-buffer-modified-p old-buffer-modified-p)
	(setq session-id nil)))
  ;; close any open temp info buffer 
  (when (setq b (get-buffer ltc-info-buffer))
    (delete-windows-on b t) ; kill window containing temp buffer
    (kill-buffer b)) ; kill temp buffer
  (setq ltc-info-buffer "")
  (font-lock-mode 1) ; turn latex font-lock mode back on
  )

(defun ltc-update ()
  "updating changes for current session"
  (interactive)
  (if ltc-mode
      (let* ((map (ltc-method-call "get_changes" session-id (compile-recent-edits)))
	     (old-buffer-modified-p (buffer-modified-p)) ; maintain modified flag
	     ;; build color table for this update: int -> color name
	     (color-table (mapcar (lambda (four-tuple)
				    (cons (string-to-number (nth 0 four-tuple)) (nth 3 four-tuple)))
				  (cdr (assoc-string "authors" map))))
	     (styles (cdr (assoc-string "styles" map)))
	     )
	(message "LTC updates received")
	(ltc-remove-edit-hooks) ; remove (local) hooks to capture user's edits temporarily
	;; obtain and replace text in buffer
	(erase-buffer)
	(insert (cdr (assoc-string "text" map)))
	;; apply styles to new buffer
	(if (and styles (car styles))  ; sometimes STYLES = '(nil)
	    (mapc (lambda (style) 
		    (put-text-property (1+ (car style)) (1+ (nth 1 style)) 'face 
				       (list 
					(if (= '1 (nth 2 style)) :underline :strike-through) t 
					:foreground (cdr (assoc (nth 3 style) color-table))))
		    ) styles))
	(ltc-add-edit-hooks) ; add (local) hooks to capture user's edits
	;; update commit graph in temp info buffer
	(init-commit-graph (cdr (assoc-string "sha1" map)))
	(with-output-to-temp-buffer ltc-info-buffer
	  (let ((old-buffer (current-buffer))
		(old-window (get-buffer-window (current-buffer)))
	 	(temp-buffer (get-buffer-create ltc-info-buffer))
		(temp-output (pretty-print-commit-graph)))
	    (set-buffer temp-buffer)
	    (set (make-variable-buffer-local 'parent-window) old-window)
	    (insert temp-output)
	    (set-buffer old-buffer)
	    ))
	;; TODO: hide cursor (using Cursor Parameters)?
	;; adjust height of temp info buffer
	(with-selected-window (get-buffer-window ltc-info-buffer)
	  (shrink-window (- (window-height) 7)))
	(set-buffer-modified-p old-buffer-modified-p) ; restore modification flag
	))
  )

;;; --- capture save, close, and TODO: save-as (set-visited-file-name) operations 

(defun ltc-hook-before-save ()
  "Let LTC base system save the correct text to file."
  (if (not ltc-mode)
      nil
    (message "Before saving file %s for session %d" (buffer-file-name) session-id)
    (ltc-method-call "save_file" session-id (compile-recent-edits))
    (clear-visited-file-modtime) ; prevent Emacs from complaining about modtime diff's as we are writing file from Java
    (set-buffer-modified-p nil)
    t)) ; prevents actual saving in Emacs as we have already written the file

(defun ltc-hook-before-kill ()
  "Close session before killing."
  (message "Before killing buffer in session %d for file %s" session-id (buffer-file-name))
  (if ltc-mode (ltc-mode 0)) ; turn LTC mode off (includes closing session)
  nil)

;;; --- limiting functions: authors, date, revision

(defun ltc-limit-authors (authors)
  "Set or reset limiting AUTHORS for commit graph.  If empty list, no limit is used.  Updates automatically unless user chooses to quit input."
  (interactive
   (if ltc-mode
       (let ((completion-list (cons "" (mapcar 'author-to-string (mapcar 'caddr (cdr commit-graph)))))
	     (author-list nil)
	     (n 1)
	     (old-spc (lookup-key minibuffer-local-completion-map " "))
	     )
	 (setq completion-ignore-case t)
	 ;; allow space in input, so modify minibuffer-local-completion-map temporarily
	 (define-key minibuffer-local-completion-map " " nil)
	 (while (let ((author (completing-read (format "Enter author [%d] or empty to stop: " n) completion-list nil nil)))
		  (setq n (+ 1 n))
		  (if (string< "" author)
		      (setq author-list (cons author author-list)))))
	 ;; reset minibuffer-local-completion-map binding
	 (define-key minibuffer-local-completion-map " " old-spc)
	 (list (mapcar 'string-to-author (nreverse author-list))))
     '(nil))) ; sets authors = nil
  (when ltc-mode
    (setq ltc-limiting-authors (ltc-method-call "set_limited_authors" 
						session-id 
						(if authors (list :array authors) [])))
    (message "Limiting Authors: %S" ltc-limiting-authors)
    (ltc-update)))

(defun ltc-limit-date (date)
  "Set or reset limiting DATE for commit graph.  If empty string, no limit is used.  Updates automatically unless user chooses to quit input."
  (interactive
   (if ltc-mode
       (list (completing-read "Limit by date: " 
			      (cons "" (mapcar 'cadr (cdr commit-graph)))
			      nil nil))
     '(nil))) ; sets date = nil
  (when date
    (setq ltc-limiting-date (ltc-method-call "set_limited_date" session-id date))
    (ltc-update)))

(defun ltc-limit-rev (rev)
  "Set or reset limiting REV for commit graph.  If empty string, no limit is used.  Offers currently known sha1s from commit graph for completion.  Updates automatically unless user chooses to quit input."
  (interactive
   (if ltc-mode
       (list (completing-read "Limit by revision: " 
			      (cons "" (mapcar (apply-partially 'shorten 7) (mapcar 'car (cdr commit-graph))))
			      nil nil))
     '(nil))) ; sets rev = nil
  (when rev
    (setq ltc-limiting-rev (ltc-method-call "set_limited_rev" session-id rev))
    (ltc-update)))

;;; --- other interactive functions

(defun ltc-commit (msg)
  "Commit file to git if user interactively provides a commit message."
  ;; TODO: throw error message if ltc-mode not running
  (interactive
   (if ltc-mode
       (list (read-string "Commit message: "))
     '(nil))) ; sets msg = nil
  (if msg 
      (condition-case err
	  (ltc-method-call "commit_file" session-id msg)
	('error 
	 ;; TODO: handle 'Nothing to commit' && buffer-modified-p
	 (message "Error while committing file: %s" (error-message-string err)))))
  )

;;; --- info buffer functions

(defun init-commit-graph (&optional sha1s)
  "Init commit graph from git.  If a list of SHA1S is given (optional), those will be used to determine the activation state.  In this case, the first entry of the list is left untouched if it exists.  The author in the first entry in the list will be the current self."
  (if ltc-mode
    ;; build commit graph from LTC session
    (let ((commits (ltc-method-call "get_commits" session-id)) ; list of 6-tuple strings
	  (authors (mapcar (lambda (v) (cons (list (car v) (cadr v)) (nth 2 v))) 
			   (ltc-method-call "get_authors" session-id)))
	  (self (ltc-method-call "get_self" session-id)))
      ;; init graph with first item for self:
      ;; - if optional SHA1S given, look at last item and keep it if MODIFIED or ON_DISK, else 
      ;; - if prior graph not empty, keep first sha1, otherwise "" 
      (setq commit-graph (list
			  ;; determine sha1 of first item:
			  (if sha1s
			      (concat "" (car (member (car (last sha1s)) (list modified on_disk))))
			    (if commit-graph (caar commit-graph) "")) ; keep first sha1 if prior graph exists
			  ;; set rest of first item to empty and self:
			  "" (list (car self) (nth 1 self)) "" t nil nil (nth 2 self)))
      ;; build up list from first entry and current commits
      (setq commit-graph 
	    (cons
	     commit-graph
	     (mapcar (lambda (raw-commit)
		       (let ((sha1 (car raw-commit))
			     (author (list (nth 2 raw-commit) (nth 3 raw-commit)))
			     (parents (nth 5 raw-commit)))
			 (list 
			  sha1 ; SHA1
			  (nth 4 raw-commit) ; date
			  author ; (author-name author-email)
			  (nth 1 raw-commit) ; message
			  (or (not sha1s) (not (not (member sha1 sha1s)))) ; isActive: if no SHA1S, then t, otherwise look up 
			  (if parents (split-string parents) nil) ; list of parents
			  nil ; list of children (initially empty)
			  (cdr (assoc author authors)) ; color of author
			  )))
		     commits)))
      ;; TODO: build up list of children for each entry by going through one more time
      ;; TODO (if original order?): create column locations if plotting graph structure
      )
    (setq commit-graph nil) ; LTC session not valid
    ))

(defun pretty-print-commit-graph ()
  "Create string representation with text properties from current commit graph."
  (if commit-graph
      (let ((map (make-sparse-keymap)))
	(define-key map [mouse-1] 'ltc-select-color)
	;; first loop: calculate longest author string for padding to next column
	(setq msg-column (+ 2 (apply 'max (mapcar 'length (mapcar (lambda (commit)
								    (author-to-string (nth 2 commit)))
								  commit-graph)))))
	;; second loop: build return value
	(mapconcat (function (lambda (commit) 
			       (let* ((is-active (nth 4 commit))
				      (author (author-to-string (nth 2 commit)))
				      (disabledcolor "#7f7f7f")
				      (facevalue (if is-active nil (list :foreground disabledcolor))))
				 (concat
				  (propertize 
				   (format " %c %8s  %25s  " 
					   (if is-active ?* ?\s) ; whether active
					   (shorten 8 (car commit)) ; short SHA1
					   (nth 1 commit) ; date
					   )
				   'face facevalue)
				  (propertize 
				   (format (concat "%-" (number-to-string msg-column) "s") 
					   author)
				   'mouse-face 'highlight ;(list :foreground foreground 'highlight)
				   'help-echo (if is-active "click to change color")
				   'keymap map
				   'face (list :foreground (if is-active (car (last commit)) disabledcolor)))
				  (propertize 
				   (format "%s" 
					   (nth 3 commit) ; message
					   )
				   'face facevalue)
				  ))))
		   commit-graph 
		   "\n")
	)
    "<commit graph is empty>"))

(defun ltc-select-color (event)
  "Select color for indicated author in mouse event."
  (interactive "e")
  (let* ((window (posn-window (event-end event)))
	 (pos (posn-point (event-end event)))
	 (action (get-text-property pos 'action)) ; obtain action parameters from text properties
	 (old-color (car action))
	 )
    (select-window parent-window)
    (when ltc-mode
      ;; open color list and then prompt user for input
      (list-colors-display)
      (condition-case nil
	  (let* ((new-color 
		  (read-color (format "Color for %s (name or #RGB): " (author-to-string (cdr action))) t))
		 (new-color-short 
		  (concat "#" (substring new-color 1 3) (substring new-color 5 7) (substring new-color 9 11)))
		 )
	    (if (not (string= old-color new-color-short))
		(ltc-method-call "set_color" (cadr action) (caddr action) new-color-short))
	    )	
	(error nil)) ; no handlers
      ;; remove *Colors* buffer if still visible
      (when (setq b (get-buffer "*Colors*"))
	(delete-windows-on b t)
	(kill-buffer b))
      (ltc-update) ; not only applies new color (if any) but also resizes temp info buffer
      )))

;;; --- functions to handle online editing

(defun compile-recent-edits ()
  "Turn local variable with list of recent edits into an empty vector, if list is empty, 
or into a list with the keyword :array after reversing and compressing the underlying list."
  (if recent-edits
      (let ((result (reverse recent-edits)))
	(setq result
	      (let ((compressed) ; collects compressed result
		    (zero-type (caar result)) (zero-pos (string-to-number (cadar result))) (zero-contents (caddar result)) 
		    (index 1)) ; start with second list item (if it exists)
		(while (< index (length result)) 
		  (let* ((curr-elem (nth index result)) 
			 (curr-type (car curr-elem)) (curr-pos (string-to-number (cadr curr-elem))) (curr-contents (caddr curr-elem)))
		    (if (string= zero-type curr-type)
			(cond ((and (string= "DELETE" zero-type) (= zero-pos curr-pos)) 
			       (setq zero-contents (concat zero-contents curr-contents)))
			      ((and (string= "REMOVE" zero-type) (= (+ zero-pos (string-to-number zero-contents)) curr-pos)) 
			       (setq zero-contents (number-to-string (+ (string-to-number zero-contents) (string-to-number curr-contents)))))
			      ((and (string= "INSERT" zero-type) (= (+ zero-pos (length zero-contents)) curr-pos)) 
			       (setq zero-contents (concat zero-contents curr-contents)))
			      (t
			       ;; same type but non-matching position: write out
			       (setq compressed (append compressed (list (list zero-type (number-to-string (1- zero-pos)) zero-contents))))
			       ;; reset reference variables:
			       (setq zero-pos curr-pos) 
			       (setq zero-contents curr-contents)))
		      ;; new type: write out
		      (setq compressed (append compressed (list (list zero-type (number-to-string (1- zero-pos)) zero-contents))))
		      ;; reset reference variables:
		      (setq zero-type curr-type)
		      (setq zero-pos curr-pos)
		      (setq zero-contents curr-contents)))
		  (setq index (1+ index)))
		;; write out last reference variables and return as result: 
		(append compressed (list (list zero-type (number-to-string (1- zero-pos)) zero-contents)))))
	(setq recent-edits nil) ; reset recent edits
	(message "Compiled recent edits are: %S" result)
	(list :array result)) ; return result as a labeled :array
    [] ; return empty vector
    ))

(defun ltc-add-edit-hooks ()
  "Add hooks to capture user's edits."
  (add-hook 'before-change-functions 'ltc-hook-before-change nil t)
  (add-hook 'after-change-functions 'ltc-hook-after-change nil t)  
  )

(defun ltc-remove-edit-hooks ()
  "Remove hooks to capture user's edits."
  (remove-hook 'before-change-functions 'ltc-hook-before-change t)
  (remove-hook 'after-change-functions 'ltc-hook-after-change t)
  )

(defun ltc-hook-after-change (beg end len)
  "Hook to capture user's insertions while LTC mode is running."
  (message " --- LTC: after change with beg=%d and end=%d and len=%d" beg end len)
  (when (and self (= 0 len))
    ;; color text and underline
    (add-text-properties beg end (list 'face 
				       (list :underline t :foreground (car (last self)))))
    ;; add INSERT entry in front of recent edits
    (setq recent-edits (cons 
			(list edit-insert 
			      (number-to-string beg) 
			      (buffer-substring-no-properties beg end)) 
			recent-edits))
    ))

(defun ltc-hook-before-change (beg end)
  "Hook to capture user's deletions while LTC mode is running."
  (message " --- LTC: before change with beg=%d and end=%d" beg end)
  (when (and self (not (= beg end)))
    (setq self-color (caddr self))
    ;; use idiom to manipulate deletion string in temp buffer before returning to current buffer
    (setq delstring (buffer-substring beg end)) ; string /w text props about to be deleted
    (setq insstring  ; calculate insertion string
	  (with-temp-buffer
	    (insert delstring)
	    ;; prepare new text properties for characters that are inserted by other or not marked up:
	    (setq newface nil)
	    ;;(setq newface (plist-put newface :underline nil))
	    (setq newface (plist-put newface :strike-through t))
	    (setq newface (plist-put newface :foreground self-color))
	    ;; collect indices which need new text properties here:
	    (setq newindices nil)
	    ;; go through upcoming deletion's characters one-by-one
	    (setq index 1)
	    (while (< index (point-max))
	      (let ((delface (get-text-property index 'face)) ; face properties (if any)
		    )
		(if (plist-get delface :strike-through)
		    ;; character already deleted: keep with same properties
		    (setq index (1+ index))
		  (if (and (plist-get delface :underline)
			   (equal (color-values (plist-get delface :foreground))
				  (color-values self-color))) ; text underlined with color for self
		      ;; text inserted by self: add DELETE element to recent edits and remove character
		      (progn
			;; add DELETE entry in front of recent edits
			(setq recent-edits (cons 
					    (list edit-delete 
						  (number-to-string (1- (+ beg index))) 
						  (buffer-substring-no-properties index (1+ index))) 
					    recent-edits))
			(delete-region index (1+ index)) ; delete character and don't advance index in this branch!
			)
		    ;; text inserted by other or not marked up: 
		    (setq newindices (cons index newindices)) ; collect removal indices for processing later
		    ;; add REMOVE entry in front of recent edits
		    (setq recent-edits (cons 
					(list edit-remove (number-to-string (1- (+ beg index))) "1") 
					recent-edits))
		    (setq index (1+ index))
		    ))))
	    ;; change text properties for collected indices:
	    ;;   keep text but as strike-through and change foreground to self
	    (setq newindices (reverse newindices))
	    ;; blow-up list to contain consecutive duplicates for indices to be deleted
	    (setq newindices (mapcan (lambda (x) (list x (1+ x))) newindices))
	    ;; reduce list by removing duplicate indices
	    (let ((index 0)) 
	      (while (< index (1- (length newindices))) 
		(let ((curr (nth index newindices)) 
		      (next (nth (1+ index) newindices))) 
		  (if (= curr next) 
		      (setq newindices (delq curr newindices)) ; if current and next match, delete both from list
		    (setq index (1+ index)))))) ; otherwise advanve index
	    ;; interpret list of indices as pairs to set new text property on
	    (let ((index 0)) 
	      (while (< index (1- (length newindices)))
		(put-text-property (nth index newindices) (nth (1+ index) newindices) 'face newface)
		(setq index (+ 2 index))))
	    (cons (buffer-string) recent-edits)))
    (insert (car insstring)) ; this moves point to end of insertion
    (if (eq 'backspace last-input-char) (goto-char beg)) ; if last key was BACKSPACE, move point to beginning
    (setq recent-edits (append (cdr insstring) recent-edits))
    ))

;;; --- accessing API of base system

(defvar ltc-server-address 
  (concat "http://localhost:" (number-to-string ltc-port) "/xmlrpc"))

(defun ltc-method (name)
  (concat "com.sri.ltc.server.LTCserverInterface." name))

(defun ltc-method-call (name &rest args)
  (apply 'xml-rpc-method-call ltc-server-address (ltc-method name) args))

;;; --- helper functions

(defun trim (str)
  "Trim leading and tailing whitespace from STR."
  (let ((s (if (symbolp str) (symbol-name str) str)))
    (replace-regexp-in-string "\\(^[[:space:]\n]*\\|[[:space:]\n]*$\\)" "" s)))

(defun shorten (max str)
  "Shorten STR to MAX characters if it is that long."
  (if (> (length str) max)
      (substring str 0 max)
    str))

(defun author-to-string (author)
  "Convert AUTHOR given as pair '(NAME EMAIL) into git representation of form \"NAME <EMAIL>\"."
  (let ((name (car author))
	(email (cadr author)))
    (if (or (not email) (string= "" email))
	name ; only name if email is NULL or empty
      (concat name " <" email ">"))))

(defun string-to-author (str)
  "Convert STR as an author's git representation of form \"NAME <EMAIL>\" or \"NAME\" into a pair of strings '(NAME EMAIL) with EMAIL potentially the empty string.  Returns nil if str cannot be parsed according to format above."
  (let ((author (trim str)))
    (if (string-match "^\\([^<>]*\\)\\(<\\(.*\\)>\\)?$" author)
	(list 
	 (trim (match-string 1 author)) ; name
	 (if (> (length (match-data)) 7)
	     (match-string 3 author) ; email
	   "")))))

;;; old code:

(defun ltc-parse-file (file)
  (let* ((cmd (concat "java -cp /homes/owre/LTC/build/change-tracking.jar "
		      "com.sri.latexdiff.Lexer "
		      file))
	 (str (shell-command-to-string cmd)))
    (ltc-parse-list str 0)))

(defvar ltc-parse-regexp
  "\\([^ ]+\\) \\([^\(]+\\)(\\([^,]+\\),\\([^\)]+\\)) \\([^\n]+\\)\n")

(defun ltc-parse-list (str pos)
  (let ((plist nil))
    (while (string-match ltc-parse-regexp str pos)
      (let ((type (substring str (match-beginning 1) (match-end 1)))
	    (contents (substring str (match-beginning 2) (- (match-end 2) 2)))
	    (line (substring str (match-beginning 3) (match-end 3)))
	    (column (substring str (match-beginning 4) (match-end 4)))
	    (length (substring str (match-beginning 5) (match-end 5))))
	(push (list type contents line column length) plist)
	(setq pos (match-end 0))))
    (nreverse plist)))

(defface ltc-paragraph
  '((((class color) (background dark)) 
     (:foreground "lightgrey" :bold t)) 
    (((class color) (background light)) 
     ( :foreground "lightgrey" :bold t)) 
    (t (:bold t :underline t))) 
  "Face used to visualize paragraph char mapping. 

See `blank-display-mappings'." 
  :group 'blank)

;; 2230 = \x8B6
;(setq buffer-display-table (make-display-table)) 
;(aset buffer-display-table 10
;      (vector 32 (make-glyph-code 2230 'ltc-paragraph) 10))


(provide 'ltc-mode)