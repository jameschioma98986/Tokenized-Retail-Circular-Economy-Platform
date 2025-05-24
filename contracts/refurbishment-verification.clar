;; Refurbishment Verification Contract
;; Validates product restoration and quality assessment

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_REFURBISHMENT_NOT_FOUND (err u401))
(define-constant ERR_INVALID_STATUS (err u402))
(define-constant ERR_PRODUCT_NOT_ELIGIBLE (err u403))

;; Refurbishment statuses
(define-constant STATUS_PENDING u0)
(define-constant STATUS_IN_PROGRESS u1)
(define-constant STATUS_COMPLETED u2)
(define-constant STATUS_VERIFIED u3)
(define-constant STATUS_FAILED u4)

;; Quality grades
(define-constant GRADE_A u90) ;; Like new
(define-constant GRADE_B u75) ;; Excellent
(define-constant GRADE_C u60) ;; Good
(define-constant GRADE_D u45) ;; Fair

;; Data structures
(define-map refurbishments
  { refurbishment-id: uint }
  {
    product-id: uint,
    refurbisher: principal,
    status: uint,
    quality-grade: uint,
    started-at: uint,
    completed-at: uint,
    verification-score: uint,
    verifier: (optional principal),
    cost: uint,
    notes: (string-ascii 500)
  }
)

(define-map refurbishment-steps
  { refurbishment-id: uint, step: uint }
  {
    description: (string-ascii 200),
    completed: bool,
    completed-at: uint,
    quality-check: uint
  }
)

(define-map authorized-refurbishers principal bool)
(define-map authorized-verifiers principal bool)

(define-data-var next-refurbishment-id uint u1)

;; Authorization
(define-public (add-refurbisher (refurbisher principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-set authorized-refurbishers refurbisher true))
  )
)

(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-set authorized-verifiers verifier true))
  )
)

;; Start refurbishment
(define-public (start-refurbishment (product-id uint) (estimated-cost uint) (notes (string-ascii 500)))
  (let ((refurbishment-id (var-get next-refurbishment-id)))
    (asserts! (default-to false (map-get? authorized-refurbishers tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-eligible-for-refurbishment product-id) ERR_PRODUCT_NOT_ELIGIBLE)
    (map-set refurbishments
      { refurbishment-id: refurbishment-id }
      {
        product-id: product-id,
        refurbisher: tx-sender,
        status: STATUS_PENDING,
        quality-grade: u0,
        started-at: block-height,
        completed-at: u0,
        verification-score: u0,
        verifier: none,
        cost: estimated-cost,
        notes: notes
      }
    )
    (var-set next-refurbishment-id (+ refurbishment-id u1))
    (ok refurbishment-id)
  )
)

;; Update refurbishment status
(define-public (update-status (refurbishment-id uint) (new-status uint))
  (let ((refurbishment (unwrap! (map-get? refurbishments { refurbishment-id: refurbishment-id }) ERR_REFURBISHMENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get refurbisher refurbishment)) ERR_UNAUTHORIZED)
    (map-set refurbishments
      { refurbishment-id: refurbishment-id }
      (merge refurbishment {
        status: new-status,
        completed-at: (if (is-eq new-status STATUS_COMPLETED) block-height (get completed-at refurbishment))
      })
    )
    (ok true)
  )
)

;; Add refurbishment step
(define-public (add-step (refurbishment-id uint) (step uint) (description (string-ascii 200)))
  (let ((refurbishment (unwrap! (map-get? refurbishments { refurbishment-id: refurbishment-id }) ERR_REFURBISHMENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get refurbisher refurbishment)) ERR_UNAUTHORIZED)
    (map-set refurbishment-steps
      { refurbishment-id: refurbishment-id, step: step }
      {
        description: description,
        completed: false,
        completed-at: u0,
        quality-check: u0
      }
    )
    (ok true)
  )
)

;; Complete refurbishment step
(define-public (complete-step (refurbishment-id uint) (step uint) (quality-check uint))
  (let ((refurbishment (unwrap! (map-get? refurbishments { refurbishment-id: refurbishment-id }) ERR_REFURBISHMENT_NOT_FOUND))
        (step-data (unwrap! (map-get? refurbishment-steps { refurbishment-id: refurbishment-id, step: step }) ERR_REFURBISHMENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get refurbisher refurbishment)) ERR_UNAUTHORIZED)
    (map-set refurbishment-steps
      { refurbishment-id: refurbishment-id, step: step }
      (merge step-data {
        completed: true,
        completed-at: block-height,
        quality-check: quality-check
      })
    )
    (ok true)
  )
)

;; Verify refurbishment
(define-public (verify-refurbishment (refurbishment-id uint) (quality-grade uint) (verification-score uint))
  (let ((refurbishment (unwrap! (map-get? refurbishments { refurbishment-id: refurbishment-id }) ERR_REFURBISHMENT_NOT_FOUND)))
    (asserts! (default-to false (map-get? authorized-verifiers tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status refurbishment) STATUS_COMPLETED) ERR_INVALID_STATUS)
    (map-set refurbishments
      { refurbishment-id: refurbishment-id }
      (merge refurbishment {
        status: STATUS_VERIFIED,
        quality-grade: quality-grade,
        verification-score: verification-score,
        verifier: (some tx-sender)
      })
    )
    (ok true)
  )
)

;; Helper functions
(define-private (is-eligible-for-refurbishment (product-id uint))
  ;; Simplified eligibility check
  true
)

;; Read-only functions
(define-read-only (get-refurbishment (refurbishment-id uint))
  (map-get? refurbishments { refurbishment-id: refurbishment-id })
)

(define-read-only (get-step (refurbishment-id uint) (step uint))
  (map-get? refurbishment-steps { refurbishment-id: refurbishment-id, step: step })
)

(define-read-only (is-verified (refurbishment-id uint))
  (match (map-get? refurbishments { refurbishment-id: refurbishment-id })
    refurbishment (is-eq (get status refurbishment) STATUS_VERIFIED)
    false
  )
)

(define-read-only (get-quality-grade (refurbishment-id uint))
  (match (map-get? refurbishments { refurbishment-id: refurbishment-id })
    refurbishment (some (get quality-grade refurbishment))
    none
  )
)
