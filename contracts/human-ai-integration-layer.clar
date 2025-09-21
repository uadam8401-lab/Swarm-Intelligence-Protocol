;; Human-AI Integration Layer Contract
;; Seamless integration of human cognitive input with AI processing systems
;; Manages contributor registration, AI system connectivity, and hybrid decision processes

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_REGISTERED (err u102))
(define-constant ERR_INVALID_AI_SYSTEM (err u103))
(define-constant ERR_SESSION_NOT_FOUND (err u104))
(define-constant ERR_SESSION_EXPIRED (err u105))
(define-constant ERR_INVALID_CONTRIBUTION (err u106))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u107))

;; Data Variables
(define-data-var next-contributor-id uint u1)
(define-data-var next-ai-system-id uint u1)
(define-data-var next-session-id uint u1)
(define-data-var min-reputation-threshold uint u10)

;; Data Maps
(define-map contributors
  { contributor-id: uint }
  {
    principal: principal,
    expertise-domains: (list 10 (string-ascii 50)),
    reputation-score: uint,
    total-contributions: uint,
    registration-block: uint,
    is-active: bool
  }
)

(define-map contributor-principals
  { principal: principal }
  { contributor-id: uint }
)

(define-map ai-systems
  { ai-system-id: uint }
  {
    name: (string-ascii 100),
    capabilities: (list 5 (string-ascii 50)),
    performance-score: uint,
    total-processed: uint,
    operator: principal,
    is-validated: bool,
    registration-block: uint
  }
)

(define-map integration-sessions
  { session-id: uint }
  {
    problem-id: uint,
    human-contributors: (list 20 uint),
    ai-systems: (list 5 uint),
    session-status: (string-ascii 20),
    created-block: uint,
    expiry-block: uint,
    coordinator: principal
  }
)

(define-map human-contributions
  { session-id: uint, contributor-id: uint }
  {
    contribution-data: (string-ascii 1000),
    contribution-type: (string-ascii 50),
    timestamp: uint,
    quality-score: uint,
    validation-status: (string-ascii 20)
  }
)

(define-map ai-processing-results
  { session-id: uint, ai-system-id: uint }
  {
    processing-result: (string-ascii 1000),
    confidence-score: uint,
    processing-time: uint,
    validation-status: (string-ascii 20)
  }
)

;; Private Functions
(define-private (is-valid-expertise-domain (domain (string-ascii 50)))
  (or (is-eq domain "technology")
      (is-eq domain "science")
      (is-eq domain "economics")
      (is-eq domain "social-sciences")
      (is-eq domain "environment")
      (is-eq domain "healthcare")
      (is-eq domain "education")
      (is-eq domain "governance")
      (is-eq domain "innovation")
      (is-eq domain "general"))
)

(define-private (validate-expertise-domains (domains (list 10 (string-ascii 50))))
  (fold check-domain domains true)
)

(define-private (check-domain (domain (string-ascii 50)) (valid-so-far bool))
  (and valid-so-far (is-valid-expertise-domain domain))
)

(define-private (calculate-reputation-bonus (contribution-quality uint) (current-reputation uint))
  (+ current-reputation (/ (* contribution-quality u5) u100))
)

(define-private (is-session-active (session-id uint))
  (match (map-get? integration-sessions { session-id: session-id })
    session (and (is-eq (get session-status session) "active")
                 (< stacks-block-height (get expiry-block session)))
    false
  )
)

;; Public Functions

;; Register a new human contributor
(define-public (register-contributor (expertise-domains (list 10 (string-ascii 50))))
  (let
    (
      (contributor-id (var-get next-contributor-id))
      (existing-contributor (map-get? contributor-principals { principal: tx-sender }))
    )
    (asserts! (is-none existing-contributor) ERR_ALREADY_REGISTERED)
    (asserts! (validate-expertise-domains expertise-domains) ERR_INVALID_CONTRIBUTION)
    
    (map-set contributors
      { contributor-id: contributor-id }
      {
        principal: tx-sender,
        expertise-domains: expertise-domains,
        reputation-score: u50,
        total-contributions: u0,
        registration-block: stacks-block-height,
        is-active: true
      }
    )
    
    (map-set contributor-principals
      { principal: tx-sender }
      { contributor-id: contributor-id }
    )
    
    (var-set next-contributor-id (+ contributor-id u1))
    (ok contributor-id)
  )
)

;; Register a new AI system
(define-public (register-ai-system (name (string-ascii 100)) (capabilities (list 5 (string-ascii 50))))
  (let
    (
      (ai-system-id (var-get next-ai-system-id))
    )
    (map-set ai-systems
      { ai-system-id: ai-system-id }
      {
        name: name,
        capabilities: capabilities,
        performance-score: u70,
        total-processed: u0,
        operator: tx-sender,
        is-validated: false,
        registration-block: stacks-block-height
      }
    )
    
    (var-set next-ai-system-id (+ ai-system-id u1))
    (ok ai-system-id)
  )
)

;; Validate an AI system (only contract owner)
(define-public (validate-ai-system (ai-system-id uint))
  (let
    (
      (ai-system (unwrap! (map-get? ai-systems { ai-system-id: ai-system-id }) ERR_INVALID_AI_SYSTEM))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (map-set ai-systems
      { ai-system-id: ai-system-id }
      (merge ai-system { is-validated: true })
    )
    (ok true)
  )
)

;; Create a new integration session
(define-public (create-integration-session 
                (problem-id uint)
                (duration-blocks uint)
                (required-contributors (list 20 uint))
                (required-ai-systems (list 5 uint)))
  (let
    (
      (session-id (var-get next-session-id))
      (expiry-block (+ stacks-block-height duration-blocks))
    )
    (map-set integration-sessions
      { session-id: session-id }
      {
        problem-id: problem-id,
        human-contributors: required-contributors,
        ai-systems: required-ai-systems,
        session-status: "active",
        created-block: stacks-block-height,
        expiry-block: expiry-block,
        coordinator: tx-sender
      }
    )
    
    (var-set next-session-id (+ session-id u1))
    (ok session-id)
  )
)

;; Submit human contribution to session
(define-public (submit-human-contribution 
                (session-id uint)
                (contribution-data (string-ascii 1000))
                (contribution-type (string-ascii 50)))
  (let
    (
      (contributor-info (unwrap! (map-get? contributor-principals { principal: tx-sender }) ERR_NOT_REGISTERED))
      (contributor-id (get contributor-id contributor-info))
      (contributor (unwrap! (map-get? contributors { contributor-id: contributor-id }) ERR_NOT_REGISTERED))
    )
    (asserts! (is-session-active session-id) ERR_SESSION_EXPIRED)
    
    ;; Record contribution
    (map-set human-contributions
      { session-id: session-id, contributor-id: contributor-id }
      {
        contribution-data: contribution-data,
        contribution-type: contribution-type,
        timestamp: stacks-block-height,
        quality-score: u0,
        validation-status: "pending"
      }
    )
    
    ;; Update contributor stats
    (map-set contributors
      { contributor-id: contributor-id }
      (merge contributor { total-contributions: (+ (get total-contributions contributor) u1) })
    )
    
    (ok true)
  )
)

;; Submit AI processing result
(define-public (submit-ai-processing-result
                (session-id uint)
                (ai-system-id uint)
                (processing-result (string-ascii 1000))
                (confidence-score uint))
  (let
    (
      (ai-system (unwrap! (map-get? ai-systems { ai-system-id: ai-system-id }) ERR_INVALID_AI_SYSTEM))
    )
    (asserts! (is-eq tx-sender (get operator ai-system)) ERR_UNAUTHORIZED)
    (asserts! (get is-validated ai-system) ERR_INVALID_AI_SYSTEM)
    (asserts! (is-session-active session-id) ERR_SESSION_EXPIRED)
    
    (map-set ai-processing-results
      { session-id: session-id, ai-system-id: ai-system-id }
      {
        processing-result: processing-result,
        confidence-score: confidence-score,
        processing-time: stacks-block-height,
        validation-status: "pending"
      }
    )
    
    ;; Update AI system stats
    (map-set ai-systems
      { ai-system-id: ai-system-id }
      (merge ai-system { total-processed: (+ (get total-processed ai-system) u1) })
    )
    
    (ok true)
  )
)

;; Validate contribution quality (session coordinator only)
(define-public (validate-contribution-quality
                (session-id uint)
                (contributor-id uint)
                (quality-score uint))
  (let
    (
      (session (unwrap! (map-get? integration-sessions { session-id: session-id }) ERR_SESSION_NOT_FOUND))
      (contribution (unwrap! (map-get? human-contributions { session-id: session-id, contributor-id: contributor-id }) ERR_INVALID_CONTRIBUTION))
      (contributor (unwrap! (map-get? contributors { contributor-id: contributor-id }) ERR_NOT_REGISTERED))
    )
    (asserts! (is-eq tx-sender (get coordinator session)) ERR_UNAUTHORIZED)
    
    ;; Update contribution validation
    (map-set human-contributions
      { session-id: session-id, contributor-id: contributor-id }
      (merge contribution { 
        quality-score: quality-score,
        validation-status: "validated"
      })
    )
    
    ;; Update contributor reputation
    (map-set contributors
      { contributor-id: contributor-id }
      (merge contributor {
        reputation-score: (calculate-reputation-bonus quality-score (get reputation-score contributor))
      })
    )
    
    (ok true)
  )
)

;; Close integration session
(define-public (close-session (session-id uint))
  (let
    (
      (session (unwrap! (map-get? integration-sessions { session-id: session-id }) ERR_SESSION_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get coordinator session)) ERR_UNAUTHORIZED)
    
    (map-set integration-sessions
      { session-id: session-id }
      (merge session { session-status: "closed" })
    )
    
    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-contributor-info (contributor-id uint))
  (map-get? contributors { contributor-id: contributor-id })
)

(define-read-only (get-ai-system-info (ai-system-id uint))
  (map-get? ai-systems { ai-system-id: ai-system-id })
)

(define-read-only (get-session-info (session-id uint))
  (map-get? integration-sessions { session-id: session-id })
)

(define-read-only (get-contributor-by-principal (principal principal))
  (map-get? contributor-principals { principal: principal })
)
