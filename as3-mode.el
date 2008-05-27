;;; as3-mode.el --- A simple mode for editing Actionscript 3 files

;; Copyright (C) 2007  Aemon Cannon

;; Author: Aemon Cannon
;; Keywords: language modes

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:
;; 
;;; Code:

(eval-when-compile (require 'cl))

(require 'project-helper)
(require 'compile)
(require 'fdb)
(require 'flymake)
(require 'flyparse-mode)
(require 'font-lock)
(require 'cc-mode)
(require 'abbrev-extensions)
(eval-when-compile (require 'regexp-opt))
(add-to-list 'load-path "~/etc/emacs/site-lisp/yasnippet/")
(require 'yasnippet)


(defvar as3-build-and-run-command nil)
(make-variable-buffer-local 'as3-build-and-run-command)

(defvar as3-flymake-build-command nil)
(make-variable-buffer-local 'as3-flymake-build-command)

(defvar as3-flyparse-parse-cmd 
  '("java" "emacs.flyparse.as3.AS3Driver")
  "The shell command used to invoke the actionscript 3 parser.")

(defvar as3-flyparse-path-to-import-def
  '("COMPILATION_UNIT" "PACKAGE_DECL" "IMPORT_DEF"))

(defvar as3-flyparse-path-to-class-def
  '("COMPILATION_UNIT" "PACKAGE_DECL" "CLASS_DEF"))

(defvar as3-flyparse-path-to-class-ident
  (append as3-flyparse-path-to-class-def '("CLASS_NAME" "NAME")))

(defvar as3-flyparse-path-to-class-name
  (append as3-flyparse-path-to-class-ident '(*)))

(defvar as3-flyparse-path-to-extends-clause
  (append as3-flyparse-path-to-class-def '("EXTENDS_CLAUSE")))

(defvar as3-flyparse-path-to-extends-name
  (append as3-flyparse-path-to-extends-clause '("NAME" *)))

(defvar as3-flyparse-path-to-class-block
  (append as3-flyparse-path-to-class-def '("TYPE_BLOCK")))

(defvar as3-flyparse-path-to-class-member
  (append as3-flyparse-path-to-class-block '("CLASS_MEMBER")))

(defvar as3-flyparse-path-to-method-def
  (append as3-flyparse-path-to-class-member '("METHOD_DEF")))

(defvar as3-flyparse-path-to-method-name
  (append as3-flyparse-path-to-method-def '("METHOD_NAME" "NAME")))

(defvar as3-flyparse-path-to-method-param
  (append as3-flyparse-path-to-method-def '("PARAMS" "PARAM")))

(defvar as3-flyparse-path-to-method-return-type
  (append as3-flyparse-path-to-method-def '("TYPE_SPEC" "TYPE")))

(defvar as3-flyparse-path-to-method-name-text
  (append as3-flyparse-path-to-method-def '("METHOD_NAME" "NAME" *)))

(defvar as3-flyparse-path-to-method-def-block
  (append as3-flyparse-path-to-method-def '("BLOCK")))

(defvar as3-flyparse-path-to-variable-def
  (append as3-flyparse-path-to-class-member '("VARIABLE_DEF")))

(defvar as3-flyparse-path-to-variable-def-name
  (append as3-flyparse-path-to-variable-def '("VAR_DECLARATION" "NAME")))


(defvar as3-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") 'comment-region)
    map)
  "Keymap for `as3-mode'.")

(defvar as3-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?\" "\""   st)
    (modify-syntax-entry ?\' "\""   st)
    (modify-syntax-entry ?_  "w"    st)
    (modify-syntax-entry ?\\ "\\"   st)
    (modify-syntax-entry ?{ "("   st)
    (modify-syntax-entry ?} ")"   st)
    (modify-syntax-entry ?\[ "("   st)
    (modify-syntax-entry ?\] ")"   st)
    (modify-syntax-entry ?\( "("   st)
    (modify-syntax-entry ?\) ")"   st)
    (modify-syntax-entry ?+  "."    st)
    (modify-syntax-entry ?-  "."    st)
    (modify-syntax-entry ?=  "."    st)
    (modify-syntax-entry ?%  "."    st)
    (modify-syntax-entry ?<  "."    st)
    (modify-syntax-entry ?>  "."    st)
    (modify-syntax-entry ?&  "."    st)
    (modify-syntax-entry ?|  "."    st)
    (modify-syntax-entry ?\240 "."  st)
    (modify-syntax-entry ?/  ". 124b" st)
    (modify-syntax-entry ?*  ". 23"   st)
    (modify-syntax-entry ?\n "> b"  st)
    (modify-syntax-entry ?\^m "> b" st)
    st)
  "Syntax table for `as3-mode'.")

(defvar as3-font-lock-default-face 'as3-font-lock-default-face)

(defconst as3-font-lock-keywords
  (append
   (list
    '("\\<\\(get\\|set\\)\\>\\(?:\\s-+\\(\\sw+\\)\\)?"
      (1 font-lock-type-face)
      (2 font-lock-function-name-face nil t))
    '("\\<\\(function\\)\\>\\(?:\\s-+\\(\\sw+\\)\\)?"
      (1 font-lock-keyword-face)
      (2 font-lock-function-name-face nil t))
    '("\\<\\(function\\)\\>"
      (1 font-lock-keyword-face))
    '("\\<\\([A-Z_]+\\)\\>"
      (1 font-lock-constant-face))
    '("\\<\\([A-Z]\\sw+\\)\\>"
      (1 font-lock-type-face))
    '("\\<\\(var\\)\\>\\(?:\\s-+\\(_?\\sw+\\)\\)?"
      (1 font-lock-keyword-face)
      (2 font-lock-variable-name-face nil t))
    '("\\(_\\sw+\\)"
      (1 font-lock-variable-name-face nil t))
    '("\\<\\(\\|this\\|super\\|debugger\\|delete\\|export\\|in\\|is\\|typeof\\|with\\)\\>"
      (1 font-lock-builtin-face))
    '("\\<\\(public\\|private\\|override\\|protected\\|import\\|package\\|static\\|class\\|const\\|extends\\|implements\\)\\>"
      (1 font-lock-keyword-face))
    '("\\<\\(return\\|new\\|if\\|else\\|while\\|for\\|throw\\)\\>"
      (1 font-lock-keyword-face))
    '("\\<\\(default\\)\\>\\(?:\\s-+\\(\\sw+\\)\\)?"
      (1 font-lock-keyword-face)
      (2 font-lock-variable-name-face nil t))
    '("\\<\\(void\\)\\>\\(?:\\s-+\\(\\sw+\\)\\)?"
      (1 font-lock-keyword-face t)
      (2 as3-font-lock-default-face t t))
    '("\\<\\(Infinity\\|NaN\\|undefined\\)\\>" 
      0 font-lock-constant-face t)
    )
   )
  "Subdued level highlighting for As3 mode.")

(defvar as3-event-options
  `(("MouseEvent.MOUSE_DOWN" . ("MouseEvent" "MOUSE_DOWN" "onMouseDown"))
    ("MouseEvent.MOUSE_UP" . ("MouseEvent" "MOUSE_UP" "onMouseUp"))
    ("MouseEvent.ROLL_OUT" . ("MouseEvent" "MOUSE_OUT" "onRollOut"))
    ("MouseEvent.ROLL_OVER" . ("MouseEvent" "MOUSE_OVER" "onRollOver"))
    ("KeyboardEvent.KEY_UP" . ("KeyboardEvent" "KEY_UP" "onKeyUp"))
    ("KeyboardEvent.KEY_DOWN" . ("KeyboardEvent" "KEY_DOWN" "onKeyDown"))
    ("TimerEvent.TIMER" . ("TimerEvent" "TIMER" "onTimer"))
    ("Event.ACTIVATE" . ("Event" "ACTIVATE" "onActivate"))
    ("Event.ADDED" . ("Event" "ADDED" "onAdded"))
    ("Event.ADDED_TO_STAGE" . ("Event" "ADDED_TO_STAGE" "onAddedToStage"))
    ("Event.CANCEL" . ("Event" "CANCEL" "onCancel"))
    ("Event.CHANGE" . ("Event" "CHANGE" "onChange"))
    ("Event.CLOSE" . ("Event" "CLOSE" "onClose"))
    ("Event.COMPLETE" . ("Event" "COMPLETE" "onComplete"))
    ("Event.CONNECT" . ("Event" "CONNECT" "onConnect"))
    ("Event.DEACTIVATE" . ("Event" "DEACTIVATE" "onDeactivate"))
    ("Event.ENTER_FRAME" . ("Event" "ENTER_FRAME" "onEnterFrame"))
    ("Event.FULLSCREEN" . ("Event" "FULLSCREEN" "onFullScreen"))
    ("Event.ID3" . ("Event" "ID3" "onId3"))
    ("Event.INIT" . ("Event" "INIT" "onInit"))
    ("Event.MOUSE_LEAVE" . ("Event" "MOUSE_LEAVE" "onMouseLeave"))
    ("Event.OPEN" . ("Event" "OPEN" "onOpen"))
    ("Event.REMOVED" . ("Event" "REMOVED" "onRemoved"))
    ("Event.REMOVED_FROM_STAGE" . ("Event" "REMOVED_FROM_STAGE" "onRemovedFromStage"))
    ("Event.RENDER" . ("Event" "RENDER" "onRender"))
    ("Event.RESIZE" . ("Event" "RESIZE" "onResize"))
    ("Event.SCROLL" . ("Event" "SCROLL" "onScroll"))
    ("Event.SELECT" . ("Event" "SELECT" "onSelect"))
    ("Event.SOUND_COMPLETE" . ("Event" "SOUND_COMPLETE" "onSoundComplete"))
    ("Event.TAB_CHILDREN_CHANGE" . ("Event" "TAB_CHILDREN_CHANGE" "onTabChildrenChange"))
    ("Event.TAB_ENABLED_CHANGE" . ("Event" "TAB_ENABLED_CHANGE" "onTabEnabledChange"))
    ("Event.TAB_INDEX_CHANGE" . ("Event" "TAB_INDEX_CHANGE" "onTabIndexChange"))
    ("Event.UNLOAD" . ("Event" "UNLOAD" "onUnload"))
    ))


(defvar as3-command-library 
  '(("hoist-constant" . "as3-hoist-as-constant")
    ("hoist-method" . "as3-hoist-as-method")
    ("import" . "as3-new-import")
    ("accessors" . "as3-getter-setter")
    ("flip-to-y" . "as3-copy-and-flip-line")
    ("create-getter" . "as3-create-getter-from-var-def-at-point")
    ("create-setter" . "as3-create-setter-from-var-def-at-point")
    ("create-getter-and-setter" . "as3-create-getter-and-setter-from-var-def-at-point")
    ("create-subclass" . "as3-create-subclass")
    ("create-from-template" . "as3-create-from-template")
    ("create-private-var" . "as3-create-private-var-at-point")
    ("goto-def" . "as3-goto-def")
    ("switch-to-super" . "as3-switch-to-super")
    ("switch-to-subclass" . "as3-switch-to-subclass")
    ("organize-imports" . "as3-alphabetize-imports")
    ("asdoc-method" . "as3-asdoc-method")
    ("asdoc-class" . "as3-asdoc-class")
    ("add-event-listener" . "as3-insert-event-listener")
    ))

(defun as3-quick-menu ()
  (interactive)
  (run-command-by-bookmark as3-command-library))

(define-key as3-mode-map (kbd "C-c m") 'as3-quick-menu)
(define-key as3-mode-map (kbd "C-c d") 'as3-goto-def)


(define-derived-mode as3-mode fundamental-mode "as3-mode"
  "A major mode for editing Actionscript 3 files."
  :syntax-table as3-mode-syntax-table
  (set (make-local-variable 'comment-start) "//")
  (set (make-local-variable 'font-lock-defaults) (list as3-font-lock-keywords))
  (set (make-local-variable 'indent-line-function) 'as3-indent-line)
  (setq tab-width 4)
  (setq flyparse-parse-cmd as3-flyparse-parse-cmd)
  (flyparse-mode-on)
  (project-helper-load)
  (flymake-mode-on)
  (yas/initialize)
  (run-hooks 'as3-mode-hook)
  )



;;;;;;;;;;;;;;;;;
;; Indentation ;;
;;;;;;;;;;;;;;;;;

(defun as3-indent-line ()
  "Indent current line of As3 code."
  (interactive)
  (indent-line-to (max 0 (as3-calculate-indentation))))

(defun as3-calculate-indentation ()
  "Return the column to which the current line should be indented."
  (save-excursion
    (as3-maybe-skip-leading-close-delim)
    (let ((pos (point)))
      (beginning-of-line)
      (if (not (search-backward-regexp "[^\n\t\r ]" 1 0))
	  0
	(progn
	  (as3-maybe-skip-leading-close-delim)
	  (+ (current-indentation) (* 4 (as3-count-scope-depth (point) pos))))))))

(defun as3-maybe-skip-leading-close-delim ()
  (beginning-of-line)
  (forward-to-indentation 0)
  (if (looking-at "\\s)")
      (forward-char)
    (beginning-of-line)))

(defun as3-face-at-point (pos)
  "Return face descriptor for char at point."
  (plist-get (text-properties-at pos) 'face))

(defun as3-count-scope-depth (rstart rend)
  "Return difference between open and close scope delimeters."
  ;;Attempting Steve Yegge's solution..
  ;;  (save-excursion
  ;;    (let ((result (parse-partial-sexp rstart rend)))
  ;;      (if (or (nth 3 result) (nth 4 result) (nth 7 result))
  ;;	  0
  ;;	(nth 0 result)))))
  (save-excursion
    (goto-char rstart)
    (let ((open-count 0)
	  (close-count 0)
	  opoint)
      (while (and (< (point) rend)
		  (progn (setq opoint (point))
			 (re-search-forward "\\s)\\|\\s(" rend t)))
	(if (= opoint (point))
	    (forward-char 1)
	  (cond
	   ;; Don't count if in string or comment.
	   ((as3-face-at-point (- (point) 1))) 
	   ((looking-back "\\s)")
	    (incf close-count))
	   ((looking-back "\\s(")
	    (incf open-count))
	   )))
      (- open-count close-count))))


;;;;;;;;;;;;;;;;;;;;;
;; Flymake for AS3 ;;
;;;;;;;;;;;;;;;;;;;;;


(defun flymake-as3-init ()
  (if as3-flymake-build-command
      (progn
	(remove-hook 'after-save-hook 'flymake-after-save-hook t)
	(basic-save-buffer)
	(add-hook 'after-save-hook 'flymake-after-save-hook nil t)
	as3-flymake-build-command)))

(defun flymake-as3-cleanup () ())
(defun flymake-as3-get-real-file-name (tmp-file) tmp-file)

(setq flymake-allowed-file-name-masks
      (cons '(".+\\.as$\\|.+\\.mxml$"
	      flymake-as3-init
	      flymake-as3-cleanup
	      flymake-as3-get-real-file-name)
	    flymake-allowed-file-name-masks))

(setq flymake-err-line-patterns
      (cons '("^\\(.*\\)(\\([0-9]+\\)): col: \\([0-9]+\\) Error: \\(.*\\)$" 1 2 3 4)
	    flymake-err-line-patterns))

;; Find error messages in flex compiler output:
(push '("^\\(.*\\)(\\([0-9]+\\)): col: \\([0-9]+\\) Error: \\(.*\\)$" 1 2 3 2) compilation-error-regexp-alist)


(define-key as3-mode-map (kbd "C-c p") 'flymake-goto-prev-error)
(define-key as3-mode-map (kbd "C-c n") 'flymake-goto-next-error)

;;;;;;;;;;;;;;;;;;;
;; AS3 utilities ;;
;;;;;;;;;;;;;;;;;;;

(defstruct as3-node "An AS3 program node." (tree nil) (file-path ""))

(defun as3-class-for-node (an-as3-node) 
  "Get the as3-class that defined this node."
  (make-as3-class 
   :tree (flyparse-get-cached-tree (as3-node-file-path an-as3-node)) 
   :file-path (as3-node-file-path an-as3-node)))





(defstruct (as3-class (:include as3-node)) "An AS3 class." )

(defun as3-class-named (name)
  "Return the class corresponding with the given name."
  (catch 'return-now 
    (flyparse-for-each-cached-tree
     (lambda (path tree)
       (let ((class-name-tree (flyparse-query-first 
			       as3-flyparse-path-to-class-name tree)))
	 (if class-name-tree
	     (let ((class-name (flyparse-tree-as-text class-name-tree)))
	       (if (equal class-name name)
		   (throw 'return-now 
			  (make-as3-class :tree tree :file-path path))))
	   ))
       ))
    ))

(defun as3-current-class () 
  "Get the class for the current buffer."
  (make-as3-class :tree flyparse-newest-parse-tree :file-path buffer-file-name))

(defun as3-class-name (an-as3-class) 
  "Return the name of the given class."
  (let* ((class-tree (as3-class-tree an-as3-class))
	 (class-ident (flyparse-query-first as3-flyparse-path-to-class-ident class-tree)))
    (if class-ident
	(flyparse-tree-as-text class-ident))))

(defun as3-current-class-name ()
  "Return the name of the current class in the active buffer."
  (as3-class-name (as3-current-class)))

(defun as3-super-class-for-class (an-as3-class)
  "Return the super-class of given class."
  (let* ((class-tree (as3-class-tree an-as3-class))
	 (extends-tree (flyparse-query-first as3-flyparse-path-to-extends-name class-tree)))
    (if extends-tree
	(as3-class-named (flyparse-tree-as-text extends-tree)))))

(defun as3-subclasses-for-class (an-as3-class)
  "Return a list the direct subclasses for an-as3-class."
  (let ((class-name (as3-class-name an-as3-class))
	(subclasses '()))
    (flyparse-for-each-cached-tree 
     (lambda (path tree)
       (let ((subclass-name-tree (flyparse-query-first 
				  as3-flyparse-path-to-class-name tree))
	     (extends-name-tree (flyparse-query-first 
				 as3-flyparse-path-to-extends-name tree)))
	 (if (and extends-name-tree subclass-name-tree)
	     (let ((subclass-name (flyparse-tree-type subclass-name-tree))
		   (extends-name (flyparse-tree-type extends-name-tree)))
	       (if (equal class-name extends-name)
		   (push (make-as3-class :tree tree :file-path path) subclasses))))
	 )))
    subclasses
    ))


(defun as3-class-chain-starting-at (an-as3-class)
  "Return the inheritance chain starting at an-as3-class"
  (let ((super (as3-super-class-for-class class-tree)))
    (if super
	(append (list an-as3-class) (as3-class-chain-starting-at super))
      (list an-as3-class))))





(defstruct (as3-method (:include as3-node)) "An AS3 instance method." )

(defun as3-instance-methods (an-as3-class)
  "Get all instance methods of an-as3-class."
  (let ((class-tree (as3-class-tree an-as3-class)))
    (mapcar (lambda (tree)
	      (make-as3-method :tree tree :file-path (as3-class-file-path an-as3-class)))
	    (flyparse-query-all as3-flyparse-path-to-method-def class-tree))))

(defun as3-method-name (an-as3-method)
  (flyparse-tree-as-text (flyparse-query-first '("METHOD_DEF" "METHOD_NAME" "NAME") (as3-method-tree an-as3-method))))

(defun as3-method-return-type (an-as3-method)
  (let ((type-tree (flyparse-query-first '("METHOD_DEF" "TYPE_SPEC" "TYPE") (as3-method-tree an-as3-method))))
    (if (null type-tree)
	"void"
      (flyparse-tree-as-text type-tree))))

(defun as3-method-modifiers (an-as3-method)
  (mapcar (lambda (ea) (flyparse-tree-as-text ea))
	  (flyparse-query-all '("METHOD_DEF" "MODIFIER_LIST" *) (as3-method-tree an-as3-method))))

(defun as3-method-parameter-types (an-as3-method)
  (mapcar (lambda (ea) (flyparse-tree-as-text ea))
	  (flyparse-query-all '("METHOD_DEF" "PARAMS" "PARAM" "TYPE_SPEC" "TYPE") (as3-method-tree an-as3-method))))

(defun as3-pretty-method-desc (an-as3-method)
  "Return the a pretty stringified description of method."
  (let* ((name (as3-method-name an-as3-method))
	 (type (as3-method-return-type an-as3-method))
	 (param-types (as3-method-parameter-types an-as3-method))
	 (modifiers (as3-method-modifiers an-as3-method))
	 )
    (format "%s %s(%s):%s" (mapconcat 'identity modifiers " ") name (mapconcat 'identity param-types ", ") type)
    ))

(defun as3-method-at-point (pos)
  "The method at pos in current buffer, or nil if not positioned in a method."
  (let ((tree (flyparse-query-first 
	       (append as3-flyparse-path-to-class-block '(("CLASS_MEMBER" in) "METHOD_DEF")))))
    (if tree
	(make-as3-method :tree tree :file-path buffer-file-name))))


(defun as3-methods-named (name &optional type-name)
  "Get all methods with name, for type (if provided)"
  (let ((methods '()))
    (flyparse-for-each-cached-tree 
     (lambda (path tree)
       (let* ((class (make-as3-class :tree tree :file-path path))
	      (class-name (as3-class-name class)))
	 (if (or (null type-name) (equal type-name class-name))
	     (let ((method (as3-method-named class name)))
	       (if method (push method methods)))
	   ))))
    methods
    ))


(defun as3-method-named (an-as3-class name)
  "Return the first method in class for a method names 'name',
   otherwise, if none is found, return nil."
  (let ((method-tree
	 (flyparse-query-first
	  (append 
	   as3-flyparse-path-to-class-member 
	   `(("METHOD_DEF" (has ("METHOD_DEF" "METHOD_NAME" "NAME" ,name))))) (as3-class-tree an-as3-class))))
    (if method-tree
	(make-as3-method :tree method-tree :file-path (as3-class-file-path an-as3-class)))))



(defstruct (as3-member-var (:include as3-node)) "An AS3 member variable." )

(defun as3-member-var-at-point ()
  (let ((var-tree
	 (flyparse-query-first 
	  (append as3-flyparse-path-to-class-block '(("CLASS_MEMBER" in) "VARIABLE_DEF")))))
    (if var-tree
	(make-as3-member-var :tree var-tree :file-path buffer-file-name))))

(defun as3-member-var-named (an-as3-class name)
  "Return the first member variable named 'name' in class, 
   otherwise, if none is found, return nil."
  (let ((var-tree
	 (flyparse-query-first
	  (append 
	   as3-flyparse-path-to-class-member
	   `(("VARIABLE_DEF" (has ("VARIABLE_DEF" "VAR_DECLARATION" "NAME" ,name))))) (as3-class-tree an-as3-class))))
    (if var-tree
	(make-as3-member-var :tree var-tree :file-path (as3-class-file-path an-as3-class)))))

(defun as3-member-var-name (an-as3-member-var)
  "Return name of member var definition."
  (flyparse-tree-as-text (flyparse-query-first 
			  '("VARIABLE_DEF" "VAR_DECLARATION" *) 
			  (as3-member-var-tree an-as3-member-var))))

(defun as3-member-var-type (an-as3-member-var)
  "Return type name for member var definition."
  (flyparse-tree-as-text (flyparse-query-first 
			  '("VARIABLE_DEF" "VAR_DECLARATION" "TYPE_SPEC" "TYPE") 
			  (as3-member-var-tree an-as3-member-var))))

(defun as3-getter-for (an-as3-member-var)
  "Return text of a variable getter for var tree."
  (let ((type (as3-member-var-type an-as3-member-var))
	(name (as3-member-var-name an-as3-member-var)))
    (format "public function get %s():%s { return %s }" (replace-regexp-in-string "_" "" name) type name)))

(defun as3-setter-for (an-as3-member-var)
  "Return text of a variable setter for var-def tree."
  (let ((type (as3-member-var-type an-as3-member-var))
	(name (as3-member-var-name an-as3-member-var)))
    (format "public function set %s(val:%s):void { %s = val }"
	    (replace-regexp-in-string "_" "" name) type name)))






(defstruct (as3-var-declaration (:include as3-node)) "An AS3 local variable declaration." )

(defun as3-var-declaration-named (an-as3-method name)
  "Return the first variable definition for a variable named 'name' in method-tree, 
   otherwise, if none is found, return nil."
  (let ((var-tree
	 (flyparse-search
	  `("VAR_DECLARATION" (has ("VAR_DECLARATION" "NAME" ,name))) (as3-method-tree an-as3-method))))
    (if var-tree
	(make-as3-var-declaration :tree var-tree :file-path (as3-method-file-path an-as3-method)))))


(defun as3-var-declaration-type (an-as3-var-declaration)
  "Return the name of the parameter's type declaration."
  (let ((type-tree 
	 (flyparse-search '("TYPE")
			  (as3-var-declaration-tree an-as3-var-declaration))))
    (if type-tree
	(flyparse-tree-as-text type-tree))))




(defstruct (as3-formal-parameter (:include as3-node)) "An AS3 formal-parameter." )

(defun as3-formal-parameter-named (an-as3-method name)
  "Return the first method parameter with provided name."
  (let ((param-tree
	 (flyparse-query-first `("METHOD_DEF" "PARAMS" ("PARAM" (has ("PARAM" ("NAME" (text-match ,name)))))) 
			       (as3-method-tree an-as3-method))))
    (if param-tree
	(make-as3-formal-parameter :tree param-tree :file-path (as3-method-file-path an-as3-method)))))


(defun as3-formal-parameter-type (an-as3-formal-parameter)
  "Return the name of the parameter's type declaration."
  (let ((type-tree 
	 (flyparse-query-first '("PARAM" "TYPE_SPEC" "TYPE") 
			       (as3-formal-parameter-tree an-as3-formal-parameter))))
    (if type-tree
	(flyparse-tree-as-text type-tree))))


(defun as3-formal-parameter-name (an-as3-formal-parameter)
  "Return the parameter's name."
  (let ((name-tree 
	 (flyparse-query-first '("PARAM" "NAME") 
			       (as3-formal-parameter-tree an-as3-formal-parameter))))
    (if name-tree
	(flyparse-tree-as-text name-tree))))



(defun as3-name-at-point (pos)
  (let ((var-name-tree (flyparse-containing-tree-of-type '("NAME"))))
    (if var-name-tree
	(flyparse-tree-type (flyparse-query-first '("NAME" *) var-name-tree)))))


(defun as3-type-of-literal (constant-tree)
  "Examine a flyparse tree of 'constant' type, and return its actionscript type.'"
  (cond ((flyparse-has-subtree-of-type-p constant-tree "LITERAL_NUMBER") "Number")
	((flyparse-has-subtree-of-type-p constant-tree "LITERAL_STRING") "String")
	((flyparse-has-subtree-of-type-p constant-tree "LITERAL_REGEX") "RegExp")
	((flyparse-has-subtree-of-type-p constant-tree "LITERAL_XML") "XML")
	(t "Object")))


(defun as3-var-type-at-point (name point)
  "For the given name at the given buffer point, what is the name of the type of the variable?"
  (if (equal name "this")
      (as3-current-class-name)
    (let ((current-class (as3-current-class))
	  (current-method (as3-method-at-point point)))
      (if (not current-method)
	  (message "Point is not in a method.")
	(let* ((member-var-def (as3-member-var-named current-class name))
	       (local-var-def (as3-var-declaration-named current-method name))
	       (method-param (as3-formal-parameter-named current-method name)))
	  (cond
	   (local-var-def (as3-var-declaration-type local-var-def))
	   (method-param (as3-formal-parameter-type method-param))
	   (member-var-def (as3-member-var-type member-var-def))
	   )
	  )))))
	

(defun as3-point-after-last-var-def (&optional an-as3-class)
  (flyparse-tree-end-offset 
   (flyparse-query-last as3-flyparse-path-to-variable-def 
			(if an-as3-class (as3-class-tree an-as3-class) flyparse-newest-parse-tree))))

(defun as3-point-after-last-const-def (&optional an-as3-class)
  (flyparse-tree-end-offset 
   (flyparse-query-last (append as3-flyparse-path-to-class-member '(("VARIABLE_DEF" (has ("VARIABLE_DEF" "const")))))
			(if an-as3-class (as3-class-tree an-as3-class) flyparse-newest-parse-tree))))

(defun as3-point-at-beginning-of-type-block (&optional an-as3-class)
  (flyparse-tree-beg-offset 
   (flyparse-query-first as3-flyparse-path-to-class-block
			 (if an-as3-class (as3-class-tree an-as3-class) flyparse-newest-parse-tree))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; AS3 Interactive Commands ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defun as3-alphabetize-imports (pos)
  "Alphabetize the imports in this class."
  (interactive (list (point)))
  (let ((imports (flyparse-query-all as3-flyparse-path-to-import-def)))
    (if imports
	(let ((beg-point (flyparse-tree-beg-offset (first imports))))
	  (goto-char beg-point)
	  (flyparse-kill-region imports)
	  (let ((alphabetized-imports 
		 (sort imports (lambda (a b)
				 (string-lessp (flyparse-tree-as-text a)
					       (flyparse-tree-as-text b))))))
	    (mapc (lambda (ea)
		    (insert (flyparse-tree-as-text ea))
		    (end-of-line)
		    (newline))
		  alphabetized-imports)
	    (indent-region beg-point (point))
	    (kill-line)
	    ))
      (message "Could not find any imports."))))


(defun as3-switch-to-super ()
  "Open the file containing this this class's superclass and switch to it."
  (interactive)
  (let* ((class (as3-current-class))
	 (super (as3-super-class-for-class (as3-current-class))))
    (if super
	(find-file-other-window (as3-class-file-path super))
      (message "Sorry, could not locate superclass of %s." (as3-class-name class)))))


(defun as3-switch-to-subclass ()
  "Offer all subclasses of current class as option, switch to chosen subclass."
  (interactive)
  (let* ((class (as3-current-class))
	 (subclasses (as3-subclasses-for-class class))
	 (choices (mapcar (lambda (c)
			    `(,(as3-class-name c) ,(as3-class-file-path c))
			    ) subclasses)))
    (if (not (null choices))
	(let* ((key (ido-completing-read "Select a subclass: "
					 choices 
					 nil t nil))
	       (path (cdr (assoc key choices))))
	  (find-file-other-window path))
      (message "Sorry, did not find any subclasses for %s." (as3-class-name class))
      )))


(defun as3-hoist-as-method (beg end)
  "Hoist a collection of statements into their own method."
  (interactive (list (mark) (point)))
  (let ((subtrees (flyparse-subtrees-contained-in-region beg end))
	(in-method (flyparse-containing-tree-of-type "METHOD_DEF")))
    
    (if (and in-method (not (null subtrees)))
	(let ((content-string (flyparse-region-to-string subtrees))
	      (method-name (read-string "Method name: ")))
	  (goto-char (+ 1 (flyparse-tree-end-offset in-method)))
	  (insert (format (concat
			   "\n\nprivate function %s(){\n"
			   "%s"
			   "\n}\n"
			   ) method-name content-string))
	  (goto-char (flyparse-tree-beg-offset (first subtrees)))
	  (flyparse-kill-region subtrees)
	  (insert (format "%s();" method-name))
	  (indent-region (point-min) (point-max)))
      (message "Must select at least one statement within a method."))))


(defun as3-new-import (import-name)
  "Add a new import statement."
  (interactive (list (read-string "Import identifier: ")))
  (let ((last-import (flyparse-query-last as3-flyparse-path-to-import-def)))
    (if last-import
	(progn
	  (goto-char (flyparse-tree-end-offset last-import))
	  (end-of-line)
	  (newline)
	  (insert (format "import %s;" import-name))
	  (indent-according-to-mode))
      (message "Could not find import list."))))


(defun as3-clear-this-method (pos)
  "Remove all statements from a method, leaving only the signature and open/close braces."
  (interactive (list (point)))
  (let ((code (flyparse-query-first 
	       (append as3-flyparse-path-to-class-block '(("CLASS_MEMBER" in) "METHOD_DEF" "BLOCK")))))
    (if code
	(progn
	  (goto-char (+ 1 (flyparse-tree-beg-offset code)))
	  (kill-region (+ 1 (flyparse-tree-beg-offset code))
		       (flyparse-tree-end-offset code))
	  (newline)
	  (newline)
	  (indent-according-to-mode)
	  (previous-line)
	  (indent-according-to-mode))
      (message "Not inside a method."))))


(defun as3-create-private-var (name type pos)
  (goto-char pos)
  (end-of-line)
  (newline)
  (insert (format "private var _%s:%s;" name type))
  (indent-according-to-mode))


(defun as3-create-private-var-at-point (pos)
  (interactive (list (point)))
  (let* ((name (read-string "Please enter the variable name: "))
	 (type (read-string "Please enter the variable type: " "Number")))
    (as3-create-private-var name type pos)))


(defun as3-create-getter-and-setter-from-var-def-at-point (pos)
  "Create a getter and a setter for the var definition under point."
  (interactive (list (point)))
  (let ((var-def (as3-member-var-at-point)))
    (if var-def
	(progn
	  (end-of-line)
	  (newline)
	  (insert (as3-getter-for var-def))
	  (indent-according-to-mode)
	  (end-of-line)
	  (newline)
	  (insert (as3-setter-for var-def))
	  (indent-according-to-mode))
      (message "Not inside a variable definition."))))

(defun as3-create-getter-from-var-def-at-point (pos)
  "Create a getter for the var definition under point."
  (interactive (list (point)))
  (let ((var-def (as3-member-var-at-point)))
    (if var-def
	(progn
	  (end-of-line)
	  (newline)
	  (insert (as3-getter-for var-def))
	  (indent-according-to-mode))
      (message "Not inside a variable definition."))))

(defun as3-create-setter-from-var-def-at-point (pos)
  "Create a setter for the var definition under point."
  (interactive (list (point)))
  (let ((var-def (as3-member-var-at-point)))
    (if var-def
	(progn
	  (end-of-line)
	  (newline)
	  (insert (as3-setter-for var-def))
	  (indent-according-to-mode))
      (message "Not inside a variable definition."))))


(defun as3-create-subclass ()
  "Create and switch to a new buffer containing a subclass of the current class."
  (interactive)
  (let ((class-name-tree (flyparse-query-first as3-flyparse-path-to-class-name))
	(extends-clause-tree (flyparse-query-first as3-flyparse-path-to-extends-clause)))
    (if class-name-tree
	(let* ((class-name (flyparse-tree-type class-name-tree))
	       (class-path (buffer-file-name))
	       (class-dir-path (file-name-directory class-path))
	       (newclass-name (replace-regexp-in-string 
			       "\\.as" "" 
			       (read-string "Please enter the subclass name: ")))
	       (newclass-file-name (concat newclass-name ".as"))
	       (newclass-path (concat class-dir-path newclass-file-name)))
	  (copy-file class-path newclass-path)
	  (find-file-other-window newclass-path)
	  (if extends-clause-tree
	      (flyparse-kill-tree extends-clause-tree))
	  (goto-char (+ 1 (flyparse-tree-end-offset class-name-tree)))
	  (insert (format " extends %s" class-name))
	  (goto-char 1)
	  (query-replace-regexp class-name newclass-name)
	  (save-buffer) ;; So kill-buffer doesn't ask 'are you sure?'
	  (let* ((response (read-string "Would you like to keep this class? (yes/no): "))
		 (approved-p (string-match "[yY][eE][sS]" response)))
	    (if (not approved-p)
		(progn
		  (delete-file newclass-path)
		  (kill-buffer-and-window)
		  )))
	  )
      (message "This is not a class.."))
    ))

(defun as3-create-from-template ()
  "Create and switch to a new buffer containing a class similiar to this one, 
   but named differently."
  (interactive)
  (let ((class-name-tree (flyparse-query-first as3-flyparse-path-to-class-name)))
    (if class-name-tree
	(let* ((class-name (flyparse-tree-type class-name-tree))
	       (class-path (buffer-file-name))
	       (class-dir-path (file-name-directory class-path))
	       (newclass-name (replace-regexp-in-string 
			       "\\.as" "" 
			       (read-string "Please enter the new class name: ")))
	       (newclass-file-name (concat newclass-name ".as"))
	       (newclass-path (concat class-dir-path newclass-file-name)))
	  (copy-file class-path newclass-path)
	  (find-file-other-window newclass-path)
	  (goto-char 1)
	  (query-replace-regexp class-name newclass-name)
	  (save-buffer) ;; So kill-buffer doesn't ask 'are you sure?'
	  (let* ((response (read-string "Would you like to keep this class? (yes/no): "))
		 (approved-p (string-match "[yY][eE][sS]" response)))
	    (if (not approved-p)
		(progn
		  (delete-file newclass-path)
		  (kill-buffer-and-window)
		  )))
	  )
      (message "This is not a class.."))
    ))

(defun as3-insert-event-listener (pos)
  "Insert an 'addEventListener' statement - potentially creating the corresponding listener."
  (interactive (list (point)))
  (let* ((type-key (ido-completing-read "Event type: " as3-event-options nil t nil))
	 (type-desc (cdr (assoc type-key as3-event-options)))
	 (event-type (concat (first type-desc) "." (second type-desc)))
	 (listener-trees
	  (flyparse-query-all
	   `("COMPILATION_UNIT" "PACKAGE_DECL" "CLASS_DEF" 
	     "TYPE_BLOCK" "CLASS_MEMBER" 
	     ("METHOD_DEF" (has ("METHOD_DEF" "PARAMS"  "PARAM" "TYPE_SPEC" 
				 ("TYPE" (text-match
					  ,(format "^Event$\\|^%s$" (first type-desc))
					  ))))))))
	 (listener-existing-options (mapcar (lambda (method-def) 
					      (let ((name (as3-method-name method-def))) `(,name . ,name)))
					    listener-trees))
	 (listener-options (append `(("function(..){..}" . ,(format "function(e:%s){}" (first type-desc)))
				     (,(format "(default)%s" (third type-desc)) . ,(third type-desc)))
				   listener-existing-options
				   ))
	 (listener-key  (ido-completing-read 
			 (format "Event listener for %s: " (first type-desc)) 
			 listener-options nil t nil))
	 (listener-desc (cdr (assoc listener-key listener-options))))
    (save-excursion
      (insert (format "addEventListener(%s, %s);"
		      event-type
		      listener-desc))
      (indent-according-to-mode)
      )))


(defun as3-goto-def (pos)
  "Jump to the definition  of the variable or method referenced under cursor, 
   might be in another file."
  (interactive (list (point)))
  (let ((obj-ref (flyparse-directed-search '("NAME"))))
    (if obj-ref
	(let* ((obj-name (flyparse-tree-as-text obj-ref))
	       (found-locations '()))
	  (flyparse-for-each-cached-tree 
	   (lambda (path tree)
	     (let ((found-def 
		    (or (as3-first-member-var-def tree obj-name)
			(as3-first-method-def tree obj-name))))
	       (if found-def 
		   (push `(,(file-name-sans-extension (file-name-nondirectory path)) . (,path ,found-def))
			 found-locations)))))
	  (if (not (null found-locations))
	      (let* ((key (if (= (length found-locations) 1)
			      (first (first found-locations))
			    (ido-completing-read 
			     "Found in these locations, pick one: "
			     found-locations 
			     nil t nil)
			    ))
		     (val (cdr (assoc key found-locations)))
		     (path (first val))
		     (def-tree (second val))
		     (offset (flyparse-tree-beg-offset def-tree)))
		(if (equal path buffer-file-name)
		    (goto-char offset)
		  (progn
		    (find-file-other-window path)
		    (goto-char offset))))
	    (message "Definition for %s not found." obj-name)))
      (message "Not positioned in variable or method name."))))
(define-key as3-mode-map (kbd "C-c j") 'as3-goto-def)


(defun as3-show-method-signatures (methods)
  "Show the signature for given methods in a temporary buffer."
  (if (not (null methods))
      (progn
	(let ((buffer-name "*AS3 Method Help*"))
	  (if (get-buffer buffer-name)
	      (kill-buffer buffer-name))
	  (switch-to-buffer-other-window buffer-name)
	  (insert "\n")
	  (mapc
	   (lambda (ea)
	     (insert (format "%s#       %s"
			     (as3-class-name (as3-class-for-node ea))
			     (as3-pretty-method-desc ea)))
	     (make-button (point-at-bol) (point-at-eol)
			  'face font-lock-constant-face
			  'action `(lambda (x)
				     (find-file-other-window ,(as3-method-file-path ea))
				     (goto-char ,(flyparse-tree-beg-offset (as3-method-tree ea)))
				     ))
	     (insert "\n"))
	   methods)
	  (setq buffer-read-only t)
	  (use-local-map (make-sparse-keymap))
	  (define-key (current-local-map) (kbd "q") 'kill-buffer-and-window)
	  (goto-char (point-min))
	  ))))


(defun as3-show-quick-method-help (an-as3-method)
  "Show the signature for given method in the mini-buffer"
  (message (format "%s" (as3-pretty-method-desc an-as3-method))))


(defun as3-show-members-of (name)
  "List the members of the class with name."
  (let ((class (as3-class-named name)))
    (if class
	(let ((buffer-name "*AS3 Class Help*"))
	  (if (get-buffer buffer-name)
	      (kill-buffer buffer-name))
	  (switch-to-buffer-other-window buffer-name)
	  (insert (format " Members of class '%s':\n----------------------------\n" name))
	  (let* ((methods (as3-instance-methods class)))
	    (mapc
	     (lambda (ea)
	       (insert (format "%s"(as3-pretty-method-desc ea)))
	       (make-button (point-at-bol) (point-at-eol)
			    'face font-lock-constant-face
			    'action `(lambda (x)
				       (find-file-other-window ,(as3-method-file-path ea))
				       (goto-char ,(flyparse-tree-beg-offset (as3-method-tree ea)))
				       ))
	       (insert "\n"))
	     methods))
	  (setq buffer-read-only t)
	  (use-local-map (make-sparse-keymap))
	  (define-key (current-local-map) (kbd "q") 'kill-buffer-and-window)
	  (goto-char (point-min)))
      (message "Sorry, did not find class for %s." name))))


(defun as3-hoist-as-constant (pos)
  "Create a new const static class-member with value equal to the constant
   under the cursor. Replace current literal value with reference to newly created
   constant. "
  (interactive (list (point)))
  (let ((constant (flyparse-containing-tree-of-type "CONSTANT" pos)))
    (if constant
	(let* ((const-type (as3-type-of-literal constant))
	       (last-const 
		(flyparse-query-last
		 (append as3-flyparse-path-to-variable-def '("const"))))
	       (last-var 
		(flyparse-query-last as3-flyparse-path-to-variable-def))
	       (type-block 
		(flyparse-query-first as3-flyparse-path-to-class-block))
	       (insertion-point 
		(cond (last-const (flyparse-tree-end-offset last-const))
		      (last-var (flyparse-tree-end-offset last-var))
		      (type-block (flyparse-tree-beg-offset type-block))
		      (t (throw 'FAILURE "Nowhere to insert constant :("))
		      )))
	  (let ((const-name (read-string "Name of constant: " ))
		(const-value (flyparse-tree-buffer-substring constant)))
	    (save-excursion
	      (goto-char (flyparse-tree-beg-offset constant))
	      (flyparse-kill-tree constant)
	      (insert const-name)
	      (goto-char insertion-point)
	      (end-of-line)
	      (newline)
	      (insert (format "public static const %s:%s = %s;" const-name const-type const-value))
	      (beginning-of-line)
	      (indent-according-to-mode))
	    (query-replace-regexp const-value const-name)))
      (message "Not positioned in constant."))))


(defun as3-copy-and-flip-line (pos)
  "Copy current line, insert it below, flipping width to height, x to y etc."
  (interactive (list (point)))
  (let* ((cur-line (buffer-substring-no-properties (point-at-bol) (point-at-eol)))
	 (new-line (replace-regexp-in-string 
		    "horiz" "vert" 
		    (replace-regexp-in-string 
		     "width" "height"
		     (replace-regexp-in-string 
		      "x" "y" cur-line)))))
    (end-of-line)
    (newline)
    (beginning-of-line)
    (insert new-line)
    (indent-according-to-mode)
    ))


(defun as3-show-help-at-point (pos)
  "Display contextual help for thing at point."
  (interactive (list (point)))
  (save-excursion
    (let ((start-point (point))
	  (case-fold-search nil)) ;; Enable case sensitive searching.
      (cond

       ;; Class name, starting with capital letter
       ((flyparse-re-search-containing-point "\\W\\([A-Z][A-Za-z]+\\)" (point-at-bol) (point-at-eol) 1 (point))
	(as3-show-members-of (match-string 1)))

       ;; Variable name, with or without leading underscore
       ((flyparse-re-search-containing-point "\\W\\([a-z_][A-Za-z_]*\\)[^_A-Za-z(]" (point-at-bol) (point-at-eol) 1 (point))
	(as3-show-members-of (as3-var-type-at-point (match-string 1) (point))))

       ;; Method invocation, pointer over the method name, target is 'this' (because there is leading whitespace)
       ((flyparse-re-search-containing-point "\\s \\([a-z_][A-Za-z]+\\)(" (point-at-bol) (point-at-eol) 1 (point))
	(as3-show-method-signatures (as3-methods-named (match-string 1) (as3-var-type-at-point "this" (point)))))

       ;; Method invocation, pointer over the method name, target unknown
       ((flyparse-re-search-containing-point "\\W\\([a-z_][A-Za-z]+\\)(" (point-at-bol) (point-at-eol) 1 (point))
	(as3-show-method-signatures (as3-methods-named (match-string 1))))

       ;; Method invocation, pointer after the open parenthesis, target unknown
       ((flyparse-re-search-containing-point "\\W\\([a-z_][A-Za-z]+\\)(\\()?\\)" (point-at-bol) (point) 2 (point))
	(let ((method-descriptions (as3-methods-named (match-string 1))))
	  (if method-descriptions
	      (as3-show-quick-method-help (first (as3-methods-named (match-string 1)))))))

       ;; Method invocation, pointer after the open parenthesis and some other crud, now positioned after a comma, target unknown
       ((flyparse-re-search-containing-point "\\W\\([a-z_][A-Za-z]+\\)(.*\,[ ]*\\()?\\)" (point-at-bol) (point) 2 (point))
	(let ((method-descriptions (as3-methods-named (match-string 1))))
	  (if method-descriptions
	      (as3-show-quick-method-help (first (as3-methods-named (match-string 1)))))))

       ;; Member access - target is a variable name
       ((flyparse-re-search-containing-point "\\W\\([a-z_][A-Za-z_]*\\)\.\\(\\)" (point-at-bol) (point-at-eol) 2 (point))
	(as3-show-members-of (as3-var-type-at-point (match-string 1) (point))))

       )
      )))
(define-key as3-mode-map (kbd "C-c h") 'as3-show-help-at-point)


(defun as3-asdoc-method (pos)
  (interactive (list (point)))
  (let ((method-def (flyparse-containing-tree-of-type "METHOD_DEF")))
    (if method-def
	(let* ((params (flyparse-query-all '("METHOD_DEF" "PARAMS" "PARAM") method-def))
	       (return-type (flyparse-query-first '("METHOD_DEF" "TYPE_SPEC" "TYPE") method-def)))
	  (goto-char (flyparse-tree-beg-offset method-def))
	  (newline)
	  (previous-line)
	  (insert
	   (concat
	    "/**\n"
	    " * \n"
	    " * \n"
	    (mapconcat (lambda (param)
			 (concat "* @param " 
				 (flyparse-tree-as-text 
				  (flyparse-query-first '("PARAM" "NAME") param))
				 " \n"
				 )) params "")
	    " * @return \n"
	    "*/"
	    ))
	  (indent-region (flyparse-tree-beg-offset method-def)
			 (flyparse-tree-end-offset method-def)))
      (message "Not in a method."))))


(defun as3-asdoc-class (pos)
  (interactive (list (point)))
  (let ((class-def (flyparse-containing-tree-of-type "CLASS_DEF")))
    (if class-def
	(progn
	  (goto-char (flyparse-tree-beg-offset class-def))
	  (newline)
	  (previous-line)
	  (insert
	   (concat
	    "/**\n"
	    " * \n "
	    "*/"
	    ))
	  (indent-region (flyparse-tree-beg-offset class-def) (+ (point) 300)))
      (message "Not in a class."))))


;;;;;;;;;;;;;;
;; snippets ;;
;;;;;;;;;;;;;;

(yas/define 'as3-mode "fu" "function(${arg}){
    $0
}" "function(...){ ... }"
)


;;;;;;;;;;;;;;;;;;;;;;
;; Regression Tests ;;
;;;;;;;;;;;;;;;;;;;;;;



(defun as3-mode-run-tests ()
  "Regression tests for as3-mode ."
  (interactive)
  (let ((cmd as3-flyparse-parse-cmd))
    
    ;; Simple queries on imports
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{ import com.aemon; import dog; import horse.*; public class Dude{}}")))
      (assert (= 3 
		 (length (flyparse-query-all as3-flyparse-path-to-import-def tree)))))

    ;; Simple queries on a class
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{}}")))
      (assert (= 1 
		 (length (flyparse-query-all as3-flyparse-path-to-class-def tree))))
      (assert (equal
	       "Dude"
	       (flyparse-tree-type (flyparse-query-first as3-flyparse-path-to-class-name tree)))))
    
    ;; Simple queries on a class's extends clause
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude extends Man{}}")))
      (assert (equal "EXTENDS_CLAUSE" 
		     (flyparse-tree-type (flyparse-query-first as3-flyparse-path-to-extends-clause tree))))
      (assert (equal "Man" 
		     (flyparse-tree-type (flyparse-query-first as3-flyparse-path-to-extends-name tree)))))
    
    ;; Query for different types of for loop
    (let* ((tree (flyparse-tree-for-string cmd (concat "package aemon{class Dude{"
						       "public function Dude(){"
						       "   for(var name in hash){trace(name)}"
						       "   for(var i:Number = 0; i < 20; i++){trace(i);}"
						       "   for each(var ea:Thing in myThings){trace(ea);}"
						       "}"
						       "}}"))))
      (assert (= 1 (length
		    (flyparse-query-all (append as3-flyparse-path-to-method-def-block '("FOR_LOOP")) tree))))
      (assert (= 1 (length
		    (flyparse-query-all (append as3-flyparse-path-to-method-def-block '("FOR_IN_LOOP")) tree))))
      (assert (= 1 (length
		    (flyparse-query-all (append as3-flyparse-path-to-method-def-block '("FOR_EACH_LOOP")) tree)))))
    
    ;; Simple queries on friend class
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{}} class Dudette{private var monkey:Number;}")))
      (assert (equal "CLASS_DEF"
		     (flyparse-tree-type (flyparse-directed-search '("CLASS_DEF") 45 tree))))
      (assert (equal "VARIABLE_DEF"
		     (flyparse-tree-type (flyparse-directed-search '("VARIABLE_DEF") 45 tree)))))
    
    
    ;; Query for constant variable def in a friend class and it's value
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{}} class Dudette{public static const monkey:Number = 20;}")))
      (assert (equal "VARIABLE_DEF"
		     (flyparse-tree-type (flyparse-directed-search '("VARIABLE_DEF" (has ("VARIABLE_DEF" "const"))) 45 tree))))
      (assert (equal "VAR_INITIALIZER"
		     (flyparse-tree-type (flyparse-query-first '(("VARIABLE_DEF" (has ("VARIABLE_DEF" "const"))) 
								 "VAR_DECLARATION" "VAR_INITIALIZER") 
							       (flyparse-directed-search 
								'("VARIABLE_DEF" (has ("VARIABLE_DEF" "const"))) 45 tree))))))

    ;; Check ending position of last var-def
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dudette{public var monkey:Number = 20;}}")))
      (assert (= 58 (as3-point-after-last-var-def (make-as3-class :tree tree)))))

    ;; Check ending position of last constant
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dudette{public static const monkey:Number = 20;}}")))
      (assert (= 67 (as3-point-after-last-const-def (make-as3-class :tree tree)))))
    
    ;; test non-qualified function positioning...
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function Dude(){horse();}}}")))
      (assert (equal "horse"
		     (flyparse-tree-type (flyparse-directed-search '("horse") 52 tree)))))
    
    ;; query for super
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function Dude(){super();}}}")))
      (assert (equal "super" (flyparse-tree-type (flyparse-directed-search '("super") 52 tree)))))
    
    ;; search for constant variable reference
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function Dude(){return MOOSE;}}}")))
      (assert (equal "MOOSE" (flyparse-tree-as-text (flyparse-directed-search '("NAME") 58 tree)))))

    
    ;; literals passed to 'new' expression
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function Dude(){var aemon = new Crap({name: \"lkj\"});}}}")))
      (assert (equal "CONSTANT" (flyparse-tree-type (flyparse-directed-search '("CONSTANT") 78 tree)))))
    
    
    ;; new expression with Non-class expression
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function Dude(){var aemon = new crap({name: \"lkj\"});}}}")))
      (assert (equal "CONSTANT" (flyparse-tree-type (flyparse-directed-search '("CONSTANT") 78 tree)))))
    
    
    ;; Simple queries on a method definition
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function dude(dude:Dude, cat:Cat):Butt {touch()}}}")))
      (assert (= 1 
		 (length (flyparse-query-all as3-flyparse-path-to-method-def tree))))
      (assert (equal "NAME" 
		     (flyparse-tree-type (flyparse-query-first as3-flyparse-path-to-method-name tree))))
      (assert (equal "PARAM" 
		     (flyparse-tree-type (flyparse-query-first as3-flyparse-path-to-method-param tree))))
      (assert (equal "Butt" 
		     (flyparse-tree-as-text (flyparse-query-first as3-flyparse-path-to-method-return-type tree))))
      (assert (equal "dude" 
		     (flyparse-tree-type (flyparse-query-first as3-flyparse-path-to-method-name-text tree))))
      )

    ;; query on ..rest style method param
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function dude(...rest:Array){touch()}}}")))
      (assert (equal "PARAM" 
		     (flyparse-tree-type (flyparse-query-first as3-flyparse-path-to-method-param tree))))
      )
    
    ;; Simple queries on a method call
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function dude(){touch(1,2)}}}")))
      (assert (= 1 
		 (length (flyparse-query-all (append as3-flyparse-path-to-method-def-block '("EXPR_STMNT" "EXPR_LIST" "FUNCTION_CALL")) tree))))
      (assert (= 2
		 (length (flyparse-query-all (append as3-flyparse-path-to-method-def-block '("EXPR_STMNT" "EXPR_LIST" "FUNCTION_CALL" "ARGUMENTS" "EXPR_LIST" *)) tree))))
      )

    ;; Use helpers to get properties of method
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function runHorse(dude:Dude, cat:Cat):Butt{touch()}}}"))
	   (meth (make-as3-method :tree (flyparse-query-first as3-flyparse-path-to-method-def tree))))
      (assert (equal "runHorse" (as3-method-name meth)))
      (assert (equal "Butt" (as3-method-return-type meth)))
      (assert (equal '("public") (as3-method-modifiers meth)))
      (assert (equal '("Dude" "Cat") (as3-method-parameter-types meth)))
      )

    ;; User method-return-type helper on void method
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function runHorse(dude:Dude, cat:Cat):void{touch()}}}"))
	   (meth (make-as3-method :tree (flyparse-query-first as3-flyparse-path-to-method-def tree))))
      (assert (equal "void" (as3-method-return-type meth)))
      )

    ;; Inline function definitions 
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function runHorse(dude){var dude = function(){}; var dude = function(a){return true;}; helloDude()}}}")))
      (assert (equal "FUNC_DEF" 
		     (flyparse-tree-type 
		      (flyparse-directed-search '("FUNC_DEF") 78 tree))))
      (assert (equal "FUNC_DEF" 
		     (flyparse-tree-type 
		      (flyparse-directed-search '("FUNC_DEF") 109 tree)))))


    ;; Inline function definition with missing semicolon. This code fails to parse because of antlr's automatic error correction. After parsing
    ;; 'true', antlr looks for a semi and can't find one - it then tries to correct the situation by deleting the current tokem,  '}', and using
    ;; then following semi. 
    ;; We then end up being short a '}'.
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function runHorse(dude){var dude = function(a){return true}; }}}")))
      ;; WILL FAIL
      (assert (not (equal "FUNC_DEF" 
			  (flyparse-tree-type 
			   (flyparse-directed-search '("FUNC_DEF") 82 tree))))))


    ;; First method with name
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function runHorse(dude:Monk, horse:Horse){}}}"))
	   (class (make-as3-class :tree tree))
	   (method (as3-method-named class "runHorse")))
      (assert (equal "runHorse" 
		     (as3-method-name method))))

    ;; First param in method with name
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function runHorse(dude:Monk, horse:Horse){}}}"))
	   (class (make-as3-class :tree tree))
	   (method (as3-method-named class "runHorse"))
	   (param (as3-formal-parameter-named method "horse")))
      (assert (equal "Horse"
		     (as3-formal-parameter-type param)))
      (assert (equal "horse"
		     (as3-formal-parameter-name param)))
      )


    ;; Test as3-class-name
    (let* ((tree (flyparse-tree-for-string cmd "package aemon{class Dude{public function runHorse(dude:Monk, horse:Horse){}}}")))
      (assert (equal "Dude"
		     (as3-class-name (make-as3-class :tree tree)))))


    (message "All tests passed :)")
    ))


(provide 'as3-mode)
