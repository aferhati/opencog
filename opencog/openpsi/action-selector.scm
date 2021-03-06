;
; action-selector.scm
;
; The action selector chooses one (or more) rules to run.
;
; Copyright (C) 2016 OpenCog Foundation

(use-modules (opencog) (opencog exec))

(load "demand.scm")
(load "rule.scm")
(load "utilities.scm")

;; --------------------------------------------------------------
;; Dead code, not used anywhere.
;;
;; (define *-act-sel-node-*
;;     (ConceptNode (string-append psi-prefix-str "action-selector")))
;;
;; (define-public (psi-action-selector-set! dsn)
;; "
;;   psi-action-selector-set! EXE
;;
;;   Sets the executable atom to be used for selecting actions.
;;
;;   EXE can be any executable atom. It will be used to select the psi-rules
;;   that will have their actions and goals executed.
;; "
;;     ; Check arguments
;;     (if (and
;;             (not (equal? (cog-type dsn) 'DefinedSchemaNode))
;;             (not (equal? (cog-type dsn) 'ExecutionOutputLink)))
;;         (error "Expected an executable link, got: " dsn))
;;
;;     (StateLink *-act-sel-node-* dsn)
;; )
;;
;; --------------------------------------------------------------
;; (define-public (psi-get-action-selector-generic)
;; "
;;   Returns a list containing the user-defined action-selector.
;; "
;;     (define action-selector-pattern
;;         ; Use a StateLink instead of an InheritanceLink because there
;;         ; should only be one active action-rule-selector at a time,
;;         ; even though there could be multiple possible action-rule
;;         ; selectors.  This enables dynamically changing the
;;         ; action-rule-selector through learning.
;;         (GetLink (StateLink *-act-sel-node-* (Variable "$dpn"))))
;; FIXME -- use cog-chase-link instead of GetLik, here, it is more
;; efficient.
;;
;;     (cog-outgoing-set (cog-execute! action-selector-pattern))
;; )
;;
;; --------------------------------------------------------------
;;
;; (define-public (psi-select-rules)
;; "
;;   psi-select-rules
;;
;;   Return a list of psi-rules that are satisfiable by using the
;;   current action-selector.
;; "
;;     (let ((dsn (psi-get-action-selector-generic)))
;;         (if (null? dsn)
;;             (psi-default-action-selector)
;;             (let ((result (cog-execute! (car dsn))))
;;                 (if (equal? (cog-type result) 'SetLink)
;;                     (cog-outgoing-set result)
;;                     (list result)
;;                 )
;;             )
;;         )
;;     )
;; )
;;
;; --------------------------------------------------------------
;; (define-public (psi-add-action-selector exec-term name)
;; "
;;   psi-add-action-selector EXE NAME
;;
;;   Return the executable atom that is defined ad the atcion selector.
;;
;;   NAME should be a string naming the action-rule-selector.
;; "
;;     ; Check arguments
;;     (if (not (string? name))
;;         (error "Expected second argument to be a string, got: " name))
;;
;;     ; TODO: Add checks to ensure the exec-term argument is actually executable
;;     (let* ((z-name (string-append
;;                         psi-prefix-str "action-selector-" name))
;;            (selector-dsn (cog-node 'DefinedSchemaNode z-name)))
;;        (if (null? selector-dsn)
;;            (begin
;;                (set! selector-dsn (DefinedSchemaNode z-name))
;;                (DefineLink selector-dsn exec-term)
;;
;;                 (EvaluationLink
;;                     (PredicateNode "action-selector-for")
;;                     (ListLink selector-dsn (ConceptNode psi-prefix-str)))
;;
;;                 selector-dsn
;;            )
;;
;;            selector-dsn
;;        )
;;     )
;; )
;;
;; --------------------------------------------------------------
;; (define-public (psi-default-action-selector)
;; "
;;   psi-default-action-selector
;;
;;   Return highest--weighted psi-rule that is also satisfiable.
;;   If a satisfiable rule doesn't exist then the empty list is returned.
;; "
;;     (define (choose-rules)
;;         ; NOTE: This check is required as ecan isn't being used continuesely.
;;         ; Remove `most-weighted-atoms` version once ecan is integrated.
;;         (if (or (equal? 0 (cog-af-boundary)) (equal? 1 (cog-af-boundary)))
;;             (most-weighted-atoms (psi-get-all-satisfiable-rules))
;;             (most-important-weighted-atoms (psi-get-all-satisfiable-rules))
;;         )
;;     )
;;
;;     (let ((rules (choose-rules)))
;;         (if (null? rules)
;;             '()
;;             (list (list-ref rules (random (length rules))))
;;         )
;;     )
;; )
;;
; ----------------------------------------------------------------------
(define-public (psi-set-action-selector exec-term demand-node)
"
  psi-set-action-selector EXEC-TERM DEMAND-NODE - Sets EXEC-TERM as
  the function used to select rules for the DEMAND-NODE.

  EXEC-TERM should be an executable atom.
  DEMAND-NODE should be any demand that has been defined.
"
    (psi-set-functionality exec-term #f demand-node "action-selector")
)

; ----------------------------------------------------------------------
(define-public (psi-get-action-selector demand-node)
"
  psi-get-action-selector DEMAND-NODE - Gets the action-selector of
  DEMAND-NODE.
"
    (psi-get-functionality demand-node "action-selector")
)

; --------------------------------------------------------------
(define (default-per-demand-action-selector demand)
"
  Return a list containing a single psi-rule, the one psi-rule that has
  the highest weight and is also satisfiable.  If a satisfiable rule
  doesn't exist, then the empty list is returned.
"
    ; This function does NOT examine the attention value, nor does it
    ; use ECAN in any way. And it shouldn't.  The attention-value and
    ; ECAN subsystem should use the psi-set-action-selector function
    ; above, and define a customer selector, as desired.
    (define (choose-rules)
        (most-weighted-atoms (psi-get-weighted-satisfiable-rules demand))
    )

    (let ((rules (choose-rules)))
        (cond
            ((null? rules) '())
            ((equal? (tv-mean (cog-tv (car rules))) 0.0) '())
            (else
                (list (list-ref rules
                    (random (length rules)))))
        )
    )
)

; --------------------------------------------------------------
(define-public (psi-select-rules-per-demand d)
"
  psi-select-rules-per-demand DEMAND

  Run the action selector associated with DEMAND, and return a list
  of psi-rules.  If no custom action selector was specified, then
  a list containing a single rule will be returned; that rule will
  be highest-weight rule that is also satsisfiable.  If there is no
  such rule, then the empty list is returned.
"
    (let ((as (psi-get-action-selector d)))
        (if (null? as)
            ; If the user didn't specify a custom selector, then
            ; run the default selector
            (default-per-demand-action-selector d)

            ; Else run the user's selector.
            (let ((result (cog-execute! (car as))))
                (if (equal? (cog-type result) 'SetLink)
                    (cog-outgoing-set result)
                    (list result)
                )
            )
        )
    )


    ;(let ((demands (psi-get-all-demands)))
    ;    ;NOTE:
    ;    ; 1. If there is any hierarcy/graph, get the information from the
    ;    ;    atomspace and do it here.
    ;    ; 2. Any changes between steps are accounted for, i.e, there is no
    ;    ;    caching of demands. This has a performance penality.
    ;    ; FIXME:
    ;    ; 1. Right now the demands are not separated between those that
    ;    ;    are used for emotiong modeling vs those that are used for system
    ;    ;    such as chat, behavior, ...
    ;    (append-map select-rules demands)
    ;)
)
