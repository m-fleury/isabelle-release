;;; lsp-isar-indent.el --- Indentation of isar files -*- lexical-binding: t; -*-

;; Author: Mathias Fleury <mathias.fleury@protonmail.com>
;; URL: https://bitbucket.org/zmaths/isabelle2019-vsce/

;; Keywords: lisp
;; Version: 0
;; Package-Requires: ((emacs "25.1"))

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and-or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; Initially I tried to follow the corresponding implementation in Isabelle.  However, it is full of
;; special cases and no high level definition is provided.  Finally, I decided to reimplement it from
;; scratch.

;; The overall idea is to split keywords in categories, compare the categories, and finally how much
;; more the indentation must be done.  This assumes that the previous line has been correctly
;; indented.

;; We distinguish between:
;;
;;   - outmost keywords (e.g., lemma, theory, imports, ...) that are always indented at level 0
;;
;;   - "isars" commands (e.g., assumes, shows)
;;
;;   - "isar" commands (e.g., have, show)
;;
;;   - proof (e.g., proof, next) and proof-end (e.g., qed) that open proofs
;;
;;   - proof script (e.g., apply, supply) and proof script end (e.g., by) command
;;
;;   - structuring commands (e.g., subgoal)
;;


;;; Code:

(require 'thingatpt)
(defvar lsp-isar-indent-trace-indent t)

(defun lsp-isar-indent-previous-line-with-word ()
  "Goto previous nonempty line."
  (lsp-isar-indent-trace-indent "lsp-isar-indent-previous-line-with-word, looking at %s" (word-at-point))
  (forward-line -1)
  (let ((finished nil))
    (while (and (not finished)
		(not (= (point) (point-min))))
      (lsp-isar-indent-trace-indent
       "lsp-isar-indent-previous-line-with-word beginning of line, looking at %s, line %s"
       (word-at-point)
       (line-number-at-pos))
      (back-to-indentation) ;; move to first word of the line
      (lsp-isar-indent-trace-indent
       "lsp-isar-indent-previous-line-with-word, looking at %s, line %s"
       (word-at-point)
       (line-number-at-pos))
      (if (word-at-point)
	  (setq finished t)
	(progn
	  (forward-line -1)
	  (beginning-of-line)))))
  (lsp-isar-indent-trace-indent
   "lsp-isar-indent-previous-line-with-word found, looking at %s, line %s"
   (word-at-point)
   (line-number-at-pos)))


(defun lsp-isar-indent-trace-indent (&rest args)
  "Optionally tracing procedure of ARGS."
  (if lsp-isar-indent-trace-indent
      (apply 'message args)))

(defun lsp-isar-indent-current-line-empty-p ()
  "Test if line is nonempty."
  (or (not (thing-at-point 'line)) (string-match-p "^\\s-*$" (thing-at-point 'line))))

(defun lsp-isar-indent-create-regex-from-words (s)
  "Create a regular expression based on the list of words S."
  (concat
   (cl-reduce (lambda (w y) (concat w "\\|" y))
	      (mapcar (lambda (w) (concat "\\(" w "\\)"))
		      s))))


;; Outmost commands; cannot be indented
(defvar lsp-isar-indent-outmost-command-name 'lsp-isar-indent-outmost-command)

(defvar lsp-isar-indent-outmost-command
  (list
   "theory" "imports"
   "begin" "end" "datatype"
   "lemma" "corollary" "theorem" "lemmas" "proposition"
   "sepref_def" "sepref_definition"
   "declare" "notepad"
   "inductive" "inductive_cases" "inductive_set"
   "definition" "fun" "primrec" "corec"
   "abbreviation"
   "text" "section" "subsection" "subsubsection" "paragraph"
   "instantiation" "instance"
   "thm"))

(defvar lsp-isar-indent--outmost-command
  (lsp-isar-indent-create-regex-from-words lsp-isar-indent-outmost-command))



;; proof command

(defvar lsp-isar-indent-proof-command-name 'lsp-isar-indent-proof-command)

(defvar lsp-isar-indent-proof-command
  (list
   "proof"
   "next"))

(defvar lsp-isar-indent--proof-command
  (lsp-isar-indent-create-regex-from-words lsp-isar-indent-proof-command))


;; proof enclosing command

(defvar lsp-isar-indent-proof-end-command-name 'lsp-isar-indent-proof-end-command)

(defvar lsp-isar-indent-proof-end-command
  (list
   "apply_end"
   "qed"))

(defvar lsp-isar-indent--proof-end-command
  (lsp-isar-indent-create-regex-from-words lsp-isar-indent-proof-end-command))

;; isars command

(defvar lsp-isar-indent-isars-command-name 'lsp-isar-indent-isars-command)

(defvar lsp-isar-indent-isars-command
  (list
   "assumes"
   "shows"
   "obtains"))

(defvar lsp-isar-indent--isars-command
  (lsp-isar-indent-create-regex-from-words lsp-isar-indent-isars-command))



;; isar command

(defvar lsp-isar-indent-isar-command-name 'lsp-isar-indent-isar-command)

(defvar lsp-isar-indent-isar-command
  (list
   "then"
   "have" "hence"
   "from" "with"
   "assume"
   "fix"
   "show" "thus"
   "moreover"
   "ultimately"
   "also"
   "finally"
   "case"
   "let"
   "obtain"
   "define"
   "note"))

(defvar lsp-isar-indent--isar-command
  (lsp-isar-indent-create-regex-from-words lsp-isar-indent-isar-command))


;; apply-structuring

(defvar lsp-isar-indent-apply-structuring-command-name 'lsp-isar-indent-apply-structuring-command)

(defvar lsp-isar-indent-apply-structuring-command
  (list
   "subgoal"
   "focus"))

(defvar lsp-isar-indent--apply-structuring-command
  (lsp-isar-indent-create-regex-from-words lsp-isar-indent-apply-structuring-command))


;; apply commands

(defvar lsp-isar-indent-apply-end-command-name 'lsp-isar-indent-apply-end-command)

(defvar lsp-isar-indent-apply-end-command
  (list
   "apply_end"
   "by"
   "done"))

(defvar lsp-isar-indent--apply-end-command
  (lsp-isar-indent-create-regex-from-words lsp-isar-indent-apply-end-command))


;; apply commands

(defvar lsp-isar-indent-apply-command-name 'lsp-isar-indent-apply-command)

(defvar lsp-isar-indent-apply-command
  (list
   "apply"
   "oops"
   "sorry"
   "using"
   "unfolding"
   "supply"
   "for"
   "if"))

(defvar lsp-isar-indent--apply-command
  (lsp-isar-indent-create-regex-from-words lsp-isar-indent-apply-command))


;; quasi commands

(defvar lsp-isar-indent-linking-command-name 'lsp-isar-indent-linking-command)

(defvar lsp-isar-indent-linking-command
  (list
   "and"))

(defvar lsp-isar-indent--linking-command
  (lsp-isar-indent-create-regex-from-words lsp-isar-indent-linking-command))


;; looking-at-p can match the next line...
(defun lsp-isar-indent-looking-at-p-nonempty (a)
  "Test if the line is nonempty and matching A.

Unlike the Emacs version, empty line where the next line match do
not match the pattern A."
  (and
   (lsp-isar-indent-current-line-empty-p)
   (/= 0 (lsp-isar-indent-current-line-empty-p))
   (word-at-point)
   (string-match-p a (word-at-point))))

(defun lsp-isar-indent-move-to-first-word-on-the-line ()
  "Goto first word on the line."
  (lsp-isar-indent-trace-indent "lsp-isar-indent-move-to-first-word-on-the-line, initially looking at %s" (word-at-point))
  (back-to-indentation)
  (lsp-isar-indent-trace-indent "lsp-isar-indent-move-to-first-word-on-the-line, now looking at %s" (word-at-point)))

(defun lsp-isar-indent-command-at-beginning-of-line ()
  "Identifies the command at the current position."
  (cond
   ((lsp-isar-indent-looking-at-p-nonempty lsp-isar-indent--outmost-command)
    lsp-isar-indent-outmost-command-name)

   ((lsp-isar-indent-looking-at-p-nonempty lsp-isar-indent--proof-command)
    lsp-isar-indent-proof-command-name)

   ((lsp-isar-indent-looking-at-p-nonempty lsp-isar-indent--proof-end-command)
    lsp-isar-indent-proof-end-command-name)

   ((lsp-isar-indent-looking-at-p-nonempty lsp-isar-indent--isars-command)
    lsp-isar-indent-isars-command-name)

   ((lsp-isar-indent-looking-at-p-nonempty lsp-isar-indent--isar-command)
    lsp-isar-indent-isar-command-name)

   ((lsp-isar-indent-looking-at-p-nonempty lsp-isar-indent--apply-structuring-command)
    lsp-isar-indent-apply-structuring-command-name)

   ((lsp-isar-indent-looking-at-p-nonempty lsp-isar-indent--apply-command)
    lsp-isar-indent-apply-command-name)

   ((lsp-isar-indent-looking-at-p-nonempty lsp-isar-indent--apply-end-command)
    lsp-isar-indent-apply-end-command-name)

   (t nil)))


(defun lsp-isar-indent-find-previous-command ()
  "Find first previous line starting with a command."
  (lsp-isar-indent-trace-indent "+++++++\nstarting lsp-isar-indent-find-previous-command")
  (let ((finished nil))
    ;; TODO only for debugging
    (while (and (not finished) (not (= (point) (point-min))))
      (beginning-of-line)
      (lsp-isar-indent-previous-line-with-word)
      (lsp-isar-indent-move-to-first-word-on-the-line)
      ;; (lsp-isar-indent-trace-indent "\tlsp-isar-indent-indent_structure '%s' '%s', indent at: '%s'" (word-at-point) depth (lsp-isar-indent-indent_indent))
      (setq finished (lsp-isar-indent-command-at-beginning-of-line)))
    (lsp-isar-indent-trace-indent "+++++++\nfinished lsp-isar-indent-find-previous-command")
    finished))


(defun lsp-isar-indent-indentation-depth ()
  "Give the indenttation depth."
  (save-excursion
    (beginning-of-line)
    (lsp-isar-indent-move-to-first-word-on-the-line)
    (let
	((current-command (lsp-isar-indent-command-at-beginning-of-line))
	 (current-word (word-at-point))
	 (previous-command (lsp-isar-indent-find-previous-command)))
      (lsp-isar-indent-trace-indent "current-word %s" current-word)
      (lsp-isar-indent-trace-indent "current command previous-command %s" (list current-command previous-command))
      (pcase (list current-command previous-command)

	(`(lsp-isar-indent-outmost-command ,_)
	 0)

	(`(lsp-isar-indent-proof-end-command lsp-isar-indent-outmost-command)
	 0)
	(`(lsp-isar-indent-proof-end-command lsp-isar-indent-proof-command)
	 (current-indentation))
	(`(lsp-isar-indent-proof-end-command lsp-isar-indent-proof-end-command)
	 (- (current-indentation) 2))
	(`(lsp-isar-indent-proof-end-command lsp-isar-indent-isar-command)
	 (- (current-indentation) 2))
	(`(lsp-isar-indent-proof-end-command lsp-isar-indent-apply-command)
	 (- (current-indentation) 4))
	(`(lsp-isar-indent-proof-end-command lsp-isar-indent-apply-end-command)
	 (- (current-indentation) 4))

	(`(lsp-isar-indent-proof-end-command ,_) ;; lsp-isar-indent-apply-structuring-command
	 (+ 2 (current-indentation)))

	(`(lsp-isar-indent-proof-command lsp-isar-indent-outmost-command)
	 0)
	(`(lsp-isar-indent-proof-command lsp-isar-indent-proof-command)
	 (current-indentation))
	(`(lsp-isar-indent-proof-command lsp-isar-indent-isars-command)
	 (- (current-indentation) 2))
	(`(lsp-isar-indent-proof-command lsp-isar-indent-isar-command)
	 (if (string= current-word "next")
	     (- (current-indentation) 2)
	   (current-indentation)))
	(`(lsp-isar-indent-proof-command lsp-isar-indent-apply-command)
	 (if (string= current-word "next")
	     (- (current-indentation) 4)
	   (- (current-indentation) 2)))
	(`(lsp-isar-indent-proof-command lsp-isar-indent-apply-end-command)
	 (if (string= current-word "next")
	     (- (current-indentation) 4)
	   (- (current-indentation) 2)))
	(`(lsp-isar-indent-proof-command lsp-isar-indent-proof-end-command)
	 (- (current-indentation) 2))
	(`(lsp-isar-indent-proof-command ,_) ;; lsp-isar-indent-apply-structuring-command
	 (+ 2 (current-indentation)))

	(`(lsp-isar-indent-isars-command lsp-isar-indent-outmost-command)
	 2)
	(`(lsp-isar-indent-isars-command lsp-isar-indent-proof-end-command)
	 (current-indentation))
	(`(lsp-isar-indent-isars-command lsp-isar-indent-proof-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-isars-command lsp-isar-indent-isars-command)
	 (current-indentation))
	(`(lsp-isar-indent-isars-command lsp-isar-indent-isar-command)
	 (current-indentation))
	(`(lsp-isar-indent-isars-command lsp-isar-indent-apply-structuring-command)
	 (- (current-indentation) 2))

	(`(lsp-isar-indent-isar-command lsp-isar-indent-outmost-command)
	 2)
	(`(lsp-isar-indent-isar-command lsp-isar-indent-proof-end-command)
	 (current-indentation))
	(`(lsp-isar-indent-isar-command lsp-isar-indent-proof-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-isar-command lsp-isar-indent-isars-command)
	 (current-indentation))
	(`(lsp-isar-indent-isar-command lsp-isar-indent-isar-command)
	 (current-indentation))
	(`(lsp-isar-indent-isar-command lsp-isar-indent-apply-structuring-command)
	 (- (current-indentation) 2))
	(`(lsp-isar-indent-isar-command lsp-isar-indent-apply-end-command)
	 (- (current-indentation) 2))
	(`(lsp-isar-indent-isar-command lsp-isar-indent-apply-command)
	 (- (current-indentation) 2))

	(`(lsp-isar-indent-apply-structuring-command lsp-isar-indent-outmost-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-apply-structuring-command lsp-isar-indent-proof-end-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-apply-structuring-command lsp-isar-indent-proof-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-apply-structuring-command lsp-isar-indent-isars-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-apply-structuring-command lsp-isar-indent-isar-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-apply-structuring-command lsp-isar-indent-apply-command)
	 (current-indentation))
	(`(lsp-isar-indent-apply-structuring-command lsp-isar-indent-apply-end-command)
	 (- (current-indentation) 2))
	(`(lsp-isar-indent-apply-structuring-command lsp-isar-indent-apply-structuring-command)
	 (current-indentation))

	(`(lsp-isar-indent-apply-command lsp-isar-indent-outmost-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-apply-command lsp-isar-indent-proof-end-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-apply-command lsp-isar-indent-proof-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-apply-command lsp-isar-indent-isars-command)
	 (current-indentation))
	(`(lsp-isar-indent-apply-command lsp-isar-indent-isar-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-apply-command lsp-isar-indent-apply-command)
	 (current-indentation))
	(`(lsp-isar-indent-apply-command lsp-isar-indent-apply-end-command)
	 (current-indentation))
	(`(lsp-isar-indent-apply-command lsp-isar-indent-apply-structuring-command)
	 (+ 2 (current-indentation)))

	(`(lsp-isar-indent-apply-end-command lsp-isar-indent-outmost-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-apply-end-command lsp-isar-indent-proof-end-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-apply-end-command lsp-isar-indent-proof-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-apply-end-command lsp-isar-indent-isars-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-apply-end-command lsp-isar-indent-isar-command)
	 (+ 2 (current-indentation)))
	(`(lsp-isar-indent-apply-end-command lsp-isar-indent-apply-command)
	 (current-indentation))
	(`(lsp-isar-indent-apply-end-command lsp-isar-indent-apply-end-command)
	 (- (current-indentation) 2))
	;; this can lead to bugs for `subgoal apply auto\ndone'
	;; but it works for `subgoal by auto\ndone'
	;; and `subgoal\nby auto\ndone'.
	;; Basically, we favour nicer Isar proof.
	(`(lsp-isar-indent-apply-end-command lsp-isar-indent-apply-structuring-command)
	 (if (string= current-word "by")
	     (+ (current-indentation) 2)
	   (current-indentation)))

	(`(,_ . ,_)
	 (message "unrecognized pattern")
	 (message "previous-command %s" (list current-command previous-command))
	 (+ 2 (current-indentation)))
	(_
	 (message "unrecognized pattern")
	 (message "previous-command %s" (list current-command previous-command))
	 0)
	))))

(defun lsp-isar-indent-line ()
  "Indent current line as Isar code."
  (interactive)
  (lsp-isar-indent-trace-indent "************************")

  (let
      ((cur (lsp-isar-indent-indentation-depth)))
    (lsp-isar-indent-trace-indent "setting indentation to %s" cur)
    (lsp-isar-indent-trace-indent "************************")
    (indent-line-to cur)))


(provide 'lsp-isar-indent)

;;; lsp-isar-indent.el ends here
