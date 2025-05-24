;; Lifecycle Tracking Contract
;; Monitors product usage throughout its lifecycle

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_PRODUCT_NOT_FOUND (err u201))
(define-constant ERR_INVALID_TRANSITION (err u202))

;; Lifecycle stages
(define-constant STAGE_MANUFACTURED u0)
(define-constant STAGE_DISTRIBUTED u1)
(define-constant STAGE_SOLD u2)
(define-constant STAGE_IN_USE u3)
(define-constant STAGE_RETURNED u4)
(define-constant STAGE_REFURBISHED u5)
(define-constant STAGE_RESOLD u6)
(define-constant STAGE_RECYCLED u7)

;; Data structures
(define-map product-lifecycle
  { product-id: uint }
  {
    current-stage: uint,
    current-owner: principal,
    usage-hours: uint,
    last-updated: uint,
    carbon-footprint: uint
  }
)

(define-map lifecycle-history
  { product-id: uint, stage: uint }
  {
    timestamp: uint,
    owner: principal,
    location: (string-ascii 100),
    notes: (string-ascii 200)
  }
)

(define-map authorized-trackers principal bool)

;; Authorization
(define-public (add-tracker (tracker principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-set authorized-trackers tracker true))
  )
)

;; Initialize product lifecycle
(define-public (initialize-lifecycle (product-id uint) (initial-owner principal))
  (begin
    (asserts! (default-to false (map-get? authorized-trackers tx-sender)) ERR_UNAUTHORIZED)
    (map-set product-lifecycle
      { product-id: product-id }
      {
        current-stage: STAGE_MANUFACTURED,
        current-owner: initial-owner,
        usage-hours: u0,
        last-updated: block-height,
        carbon-footprint: u0
      }
    )
    (map-set lifecycle-history
      { product-id: product-id, stage: STAGE_MANUFACTURED }
      {
        timestamp: block-height,
        owner: initial-owner,
        location: "Factory",
        notes: "Product manufactured"
      }
    )
    (ok true)
  )
)

;; Update lifecycle stage
(define-public (update-stage (product-id uint) (new-stage uint) (new-owner principal) (location (string-ascii 100)) (notes (string-ascii 200)))
  (let ((lifecycle (unwrap! (map-get? product-lifecycle { product-id: product-id }) ERR_PRODUCT_NOT_FOUND)))
    (asserts! (default-to false (map-get? authorized-trackers tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-valid-transition (get current-stage lifecycle) new-stage) ERR_INVALID_TRANSITION)
    (map-set product-lifecycle
      { product-id: product-id }
      (merge lifecycle {
        current-stage: new-stage,
        current-owner: new-owner,
        last-updated: block-height
      })
    )
    (map-set lifecycle-history
      { product-id: product-id, stage: new-stage }
      {
        timestamp: block-height,
        owner: new-owner,
        location: location,
        notes: notes
      }
    )
    (ok true)
  )
)

;; Update usage metrics
(define-public (update-usage (product-id uint) (additional-hours uint) (carbon-impact uint))
  (let ((lifecycle (unwrap! (map-get? product-lifecycle { product-id: product-id }) ERR_PRODUCT_NOT_FOUND)))
    (asserts! (default-to false (map-get? authorized-trackers tx-sender)) ERR_UNAUTHORIZED)
    (map-set product-lifecycle
      { product-id: product-id }
      (merge lifecycle {
        usage-hours: (+ (get usage-hours lifecycle) additional-hours),
        carbon-footprint: (+ (get carbon-footprint lifecycle) carbon-impact),
        last-updated: block-height
      })
    )
    (ok true)
  )
)

;; Helper functions
(define-private (is-valid-transition (current-stage uint) (new-stage uint))
  (or
    (and (is-eq current-stage STAGE_MANUFACTURED) (is-eq new-stage STAGE_DISTRIBUTED))
    (and (is-eq current-stage STAGE_DISTRIBUTED) (is-eq new-stage STAGE_SOLD))
    (and (is-eq current-stage STAGE_SOLD) (is-eq new-stage STAGE_IN_USE))
    (and (is-eq current-stage STAGE_IN_USE) (is-eq new-stage STAGE_RETURNED))
    (and (is-eq current-stage STAGE_RETURNED) (is-eq new-stage STAGE_REFURBISHED))
    (and (is-eq current-stage STAGE_REFURBISHED) (is-eq new-stage STAGE_RESOLD))
    (and (is-eq current-stage STAGE_RESOLD) (is-eq new-stage STAGE_IN_USE))
    (and (is-eq current-stage STAGE_IN_USE) (is-eq new-stage STAGE_RECYCLED))
  )
)

;; Read-only functions
(define-read-only (get-lifecycle (product-id uint))
  (map-get? product-lifecycle { product-id: product-id })
)

(define-read-only (get-stage-history (product-id uint) (stage uint))
  (map-get? lifecycle-history { product-id: product-id, stage: stage })
)

(define-read-only (get-current-stage (product-id uint))
  (match (map-get? product-lifecycle { product-id: product-id })
    lifecycle (some (get current-stage lifecycle))
    none
  )
)
