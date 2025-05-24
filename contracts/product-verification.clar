;; Product Verification Contract
;; Validates items entering the circular economy platform

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PRODUCT_EXISTS (err u101))
(define-constant ERR_PRODUCT_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Product verification statuses
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_REJECTED u2)

;; Data structures
(define-map products
  { product-id: uint }
  {
    manufacturer: principal,
    product-type: (string-ascii 50),
    serial-number: (string-ascii 100),
    verification-status: uint,
    verified-at: uint,
    verifier: (optional principal)
  }
)

(define-map authorized-verifiers principal bool)

(define-data-var next-product-id uint u1)

;; Authorization functions
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-set authorized-verifiers verifier true))
  )
)

(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-delete authorized-verifiers verifier))
  )
)

;; Product registration
(define-public (register-product (product-type (string-ascii 50)) (serial-number (string-ascii 100)))
  (let ((product-id (var-get next-product-id)))
    (asserts! (is-none (map-get? products { product-id: product-id })) ERR_PRODUCT_EXISTS)
    (map-set products
      { product-id: product-id }
      {
        manufacturer: tx-sender,
        product-type: product-type,
        serial-number: serial-number,
        verification-status: STATUS_PENDING,
        verified-at: u0,
        verifier: none
      }
    )
    (var-set next-product-id (+ product-id u1))
    (ok product-id)
  )
)

;; Product verification
(define-public (verify-product (product-id uint) (approved bool))
  (let ((product (unwrap! (map-get? products { product-id: product-id }) ERR_PRODUCT_NOT_FOUND)))
    (asserts! (default-to false (map-get? authorized-verifiers tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get verification-status product) STATUS_PENDING) ERR_INVALID_STATUS)
    (map-set products
      { product-id: product-id }
      (merge product {
        verification-status: (if approved STATUS_VERIFIED STATUS_REJECTED),
        verified-at: block-height,
        verifier: (some tx-sender)
      })
    )
    (ok approved)
  )
)

;; Read-only functions
(define-read-only (get-product (product-id uint))
  (map-get? products { product-id: product-id })
)

(define-read-only (is-verified (product-id uint))
  (match (map-get? products { product-id: product-id })
    product (is-eq (get verification-status product) STATUS_VERIFIED)
    false
  )
)

(define-read-only (is-authorized-verifier (verifier principal))
  (default-to false (map-get? authorized-verifiers verifier))
)
