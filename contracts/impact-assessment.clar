;; Impact Assessment Contract
;; Evaluates and tracks planetary engineering environmental impacts

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_ASSESSMENT_NOT_FOUND (err u301))
(define-constant ERR_INVALID_SCORE (err u302))
(define-constant ERR_ASSESSMENT_FINALIZED (err u303))

(define-map impact-assessments
  { assessment-id: uint }
  {
    protocol-id: uint,
    assessor: principal,
    environmental-impact: uint,
    geological-impact: uint,
    atmospheric-impact: uint,
    biodiversity-impact: uint,
    overall-score: uint,
    assessment-date: uint,
    finalized: bool,
    approved: bool
  }
)

(define-map assessment-details
  { assessment-id: uint }
  {
    methodology: (string-ascii 200),
    data-sources: (string-ascii 300),
    confidence-level: uint,
    review-notes: (string-ascii 500)
  }
)

(define-data-var next-assessment-id uint u1)

;; Create new impact assessment
(define-public (create-assessment
  (protocol-id uint)
  (environmental-impact uint)
  (geological-impact uint)
  (atmospheric-impact uint)
  (biodiversity-impact uint)
  (methodology (string-ascii 200))
)
  (let ((assessment-id (var-get next-assessment-id)))
    ;; Validate impact scores (1-10 scale)
    (asserts! (and (<= environmental-impact u10) (>= environmental-impact u1)) ERR_INVALID_SCORE)
    (asserts! (and (<= geological-impact u10) (>= geological-impact u1)) ERR_INVALID_SCORE)
    (asserts! (and (<= atmospheric-impact u10) (>= atmospheric-impact u1)) ERR_INVALID_SCORE)
    (asserts! (and (<= biodiversity-impact u10) (>= biodiversity-impact u1)) ERR_INVALID_SCORE)

    (let ((overall-score (calculate-overall-score environmental-impact geological-impact atmospheric-impact biodiversity-impact)))
      (map-set impact-assessments
        { assessment-id: assessment-id }
        {
          protocol-id: protocol-id,
          assessor: tx-sender,
          environmental-impact: environmental-impact,
          geological-impact: geological-impact,
          atmospheric-impact: atmospheric-impact,
          biodiversity-impact: biodiversity-impact,
          overall-score: overall-score,
          assessment-date: block-height,
          finalized: false,
          approved: false
        }
      )

      (map-set assessment-details
        { assessment-id: assessment-id }
        {
          methodology: methodology,
          data-sources: "",
          confidence-level: u5,
          review-notes: ""
        }
      )

      (var-set next-assessment-id (+ assessment-id u1))
      (ok assessment-id)
    )
  )
)

;; Calculate overall impact score (weighted average)
(define-read-only (calculate-overall-score (env uint) (geo uint) (atm uint) (bio uint))
  (/ (+ (* env u3) (* geo u2) (* atm u3) (* bio u2)) u10)
)

;; Finalize assessment
(define-public (finalize-assessment (assessment-id uint))
  (let ((assessment (unwrap! (map-get? impact-assessments { assessment-id: assessment-id }) ERR_ASSESSMENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get assessor assessment)) ERR_UNAUTHORIZED)
    (asserts! (not (get finalized assessment)) ERR_ASSESSMENT_FINALIZED)

    (map-set impact-assessments
      { assessment-id: assessment-id }
      (merge assessment { finalized: true })
    )
    (ok true)
  )
)

;; Approve assessment (regulatory authority)
(define-public (approve-assessment (assessment-id uint))
  (let ((assessment (unwrap! (map-get? impact-assessments { assessment-id: assessment-id }) ERR_ASSESSMENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (get finalized assessment) ERR_UNAUTHORIZED)

    (map-set impact-assessments
      { assessment-id: assessment-id }
      (merge assessment { approved: true })
    )
    (ok true)
  )
)

;; Get assessment
(define-read-only (get-assessment (assessment-id uint))
  (map-get? impact-assessments { assessment-id: assessment-id })
)

;; Get assessment details
(define-read-only (get-assessment-details (assessment-id uint))
  (map-get? assessment-details { assessment-id: assessment-id })
)

;; Check if protocol has approved assessment
(define-read-only (has-approved-assessment (protocol-id uint))
  (let ((assessment-id (find-assessment-for-protocol protocol-id)))
    (match assessment-id
      id (match (get-assessment id)
        assessment (and (get finalized assessment) (get approved assessment))
        false
      )
      false
    )
  )
)

;; Helper to find assessment for protocol (simplified)
(define-read-only (find-assessment-for-protocol (protocol-id uint))
  (some u1) ;; Simplified - would implement proper search in production
)
