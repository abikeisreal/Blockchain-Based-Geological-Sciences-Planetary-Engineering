;; Engineering Protocol Contract
;; Manages planetary modification protocols and procedures

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_PROTOCOL_EXISTS (err u201))
(define-constant ERR_PROTOCOL_NOT_FOUND (err u202))
(define-constant ERR_INVALID_PARAMETERS (err u203))
(define-constant ERR_INSUFFICIENT_CERTIFICATION (err u204))

(define-map engineering-protocols
  { protocol-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    required-certification: uint,
    risk-level: uint,
    created-by: principal,
    created-at: uint,
    approved: bool,
    active: bool
  }
)

(define-map protocol-parameters
  { protocol-id: uint, param-key: (string-ascii 50) }
  { param-value: (string-ascii 100) }
)

(define-data-var next-protocol-id uint u1)

;; Create a new engineering protocol
(define-public (create-protocol
  (name (string-ascii 100))
  (description (string-ascii 500))
  (required-certification uint)
  (risk-level uint)
)
  (let ((protocol-id (var-get next-protocol-id)))
    (asserts! (and (>= required-certification u1) (<= required-certification u5)) ERR_INVALID_PARAMETERS)
    (asserts! (and (>= risk-level u1) (<= risk-level u10)) ERR_INVALID_PARAMETERS)

    ;; Check if entity is authorized (simplified check)
    (asserts! (not (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)

    (map-set engineering-protocols
      { protocol-id: protocol-id }
      {
        name: name,
        description: description,
        required-certification: required-certification,
        risk-level: risk-level,
        created-by: tx-sender,
        created-at: block-height,
        approved: false,
        active: false
      }
    )

    (var-set next-protocol-id (+ protocol-id u1))
    (ok protocol-id)
  )
)

;; Approve a protocol (only contract owner)
(define-public (approve-protocol (protocol-id uint))
  (let ((protocol (unwrap! (map-get? engineering-protocols { protocol-id: protocol-id }) ERR_PROTOCOL_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set engineering-protocols
      { protocol-id: protocol-id }
      (merge protocol { approved: true, active: true })
    )
    (ok true)
  )
)

;; Add parameter to protocol
(define-public (add-protocol-parameter
  (protocol-id uint)
  (param-key (string-ascii 50))
  (param-value (string-ascii 100))
)
  (let ((protocol (unwrap! (map-get? engineering-protocols { protocol-id: protocol-id }) ERR_PROTOCOL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get created-by protocol)) ERR_UNAUTHORIZED)
    (asserts! (not (get approved protocol)) ERR_UNAUTHORIZED)

    (map-set protocol-parameters
      { protocol-id: protocol-id, param-key: param-key }
      { param-value: param-value }
    )
    (ok true)
  )
)

;; Get protocol details
(define-read-only (get-protocol (protocol-id uint))
  (map-get? engineering-protocols { protocol-id: protocol-id })
)

;; Get protocol parameter
(define-read-only (get-protocol-parameter (protocol-id uint) (param-key (string-ascii 50)))
  (map-get? protocol-parameters { protocol-id: protocol-id, param-key: param-key })
)

;; Check if protocol is executable by entity
(define-read-only (can-execute-protocol (protocol-id uint) (entity-address principal))
  (match (get-protocol protocol-id)
    protocol (and
      (get approved protocol)
      (get active protocol)
      ;; In real implementation, would check entity verification contract
      true
    )
    false
  )
)
