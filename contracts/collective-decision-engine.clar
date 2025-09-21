;; Collective Decision Engine Contract
;; Core decision-making mechanism that orchestrates swarm intelligence processes
;; Handles problem submission, contributor assignment, consensus mechanisms, and solution validation

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_PROBLEM_NOT_FOUND (err u201))
(define-constant ERR_INVALID_PROBLEM (err u202))
(define-constant ERR_VOTING_CLOSED (err u203))
(define-constant ERR_ALREADY_VOTED (err u204))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u205))
(define-constant ERR_SOLUTION_NOT_FOUND (err u206))
(define-constant ERR_INVALID_VOTE_WEIGHT (err u207))
(define-constant ERR_CONSENSUS_NOT_REACHED (err u208))

;; Data Variables
(define-data-var next-problem-id uint u1)
(define-data-var next-solution-id uint u1)
(define-data-var min-consensus-threshold uint u60) ;; 60% consensus required
(define-data-var max-voting-duration uint u1440) ;; ~10 days in blocks
(define-data-var reputation-weight-multiplier uint u100)

;; Data Maps
(define-map problems
  { problem-id: uint }
  {
    title: (string-ascii 200),
    description: (string-ascii 2000),
    category: (string-ascii 50),
    complexity-level: uint,
    submitter: principal,
    submission-block: uint,
    status: (string-ascii 30),
    required-expertise: (list 5 (string-ascii 50)),
    priority-score: uint,
    total-solutions: uint
  }
)

(define-map solutions
  { solution-id: uint }
  {
    problem-id: uint,
    proposer: principal,
    solution-title: (string-ascii 200),
    solution-description: (string-ascii 2000),
    implementation-steps: (list 10 (string-ascii 500)),
    estimated-resources: uint,
    confidence-score: uint,
    submission-block: uint,
    vote-count: uint,
    total-vote-weight: uint,
    status: (string-ascii 20)
  }
)

(define-map voting-sessions
  { problem-id: uint }
  {
    start-block: uint,
    end-block: uint,
    participating-solutions: (list 20 uint),
    total-participants: uint,
    consensus-reached: bool,
    winning-solution: (optional uint),
    voting-status: (string-ascii 20)
  }
)

(define-map votes
  { solution-id: uint, voter: principal }
  {
    vote-weight: uint,
    vote-type: (string-ascii 20), ;; "support", "oppose", "abstain"
    reasoning: (string-ascii 500),
    vote-block: uint,
    expertise-relevance: uint
  }
)

(define-map contributor-assignments
  { problem-id: uint, contributor: principal }
  {
    assignment-block: uint,
    expertise-match-score: uint,
    contribution-status: (string-ascii 20),
    assigned-role: (string-ascii 50)
  }
)

(define-map problem-metrics
  { problem-id: uint }
  {
    total-contributors: uint,
    avg-expertise-score: uint,
    solution-quality-avg: uint,
    consensus-strength: uint,
    implementation-progress: uint
  }
)

;; Private Functions
(define-private (is-valid-category (category (string-ascii 50)))
  (or (is-eq category "technology")
      (is-eq category "environment")
      (is-eq category "healthcare")
      (is-eq category "economics")
      (is-eq category "governance")
      (is-eq category "education")
      (is-eq category "social")
      (is-eq category "infrastructure")
      (is-eq category "research")
      (is-eq category "emergency"))
)

(define-private (calculate-vote-weight (voter-reputation uint) (expertise-relevance uint))
  (let
    (
      (base-weight (/ voter-reputation u10))
      (expertise-bonus (/ (* expertise-relevance u20) u100))
    )
    (+ base-weight expertise-bonus)
  )
)

(define-private (is-voting-active (problem-id uint))
  (match (map-get? voting-sessions { problem-id: problem-id })
    session (and (is-eq (get voting-status session) "active")
                 (< stacks-block-height (get end-block session)))
    false
  )
)

(define-private (calculate-consensus-percentage (total-support uint) (total-votes uint))
  (if (> total-votes u0)
    (/ (* total-support u100) total-votes)
    u0
  )
)

(define-private (update-problem-metrics (problem-id uint) (new-contributor-count uint))
  (let
    (
      (current-metrics (default-to 
        {
          total-contributors: u0,
          avg-expertise-score: u0,
          solution-quality-avg: u0,
          consensus-strength: u0,
          implementation-progress: u0
        }
        (map-get? problem-metrics { problem-id: problem-id })
      ))
    )
    (map-set problem-metrics
      { problem-id: problem-id }
      (merge current-metrics { total-contributors: new-contributor-count })
    )
  )
)

(define-private (validate-implementation-steps (steps (list 10 (string-ascii 500))))
  (> (len steps) u0)
)

;; Public Functions

;; Submit a new problem for collective decision making
(define-public (submit-problem 
                (title (string-ascii 200))
                (description (string-ascii 2000))
                (category (string-ascii 50))
                (complexity-level uint)
                (required-expertise (list 5 (string-ascii 50)))
                (priority-score uint))
  (let
    (
      (problem-id (var-get next-problem-id))
    )
    (asserts! (is-valid-category category) ERR_INVALID_PROBLEM)
    (asserts! (<= complexity-level u10) ERR_INVALID_PROBLEM)
    (asserts! (<= priority-score u100) ERR_INVALID_PROBLEM)
    
    (map-set problems
      { problem-id: problem-id }
      {
        title: title,
        description: description,
        category: category,
        complexity-level: complexity-level,
        submitter: tx-sender,
        submission-block: stacks-block-height,
        status: "open",
        required-expertise: required-expertise,
        priority-score: priority-score,
        total-solutions: u0
      }
    )
    
    (update-problem-metrics problem-id u0)
    (var-set next-problem-id (+ problem-id u1))
    (ok problem-id)
  )
)

;; Assign contributors to a problem based on expertise
(define-public (assign-contributor 
                (problem-id uint)
                (contributor principal)
                (expertise-match-score uint)
                (assigned-role (string-ascii 50)))
  (let
    (
      (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get submitter problem)) ERR_UNAUTHORIZED)
    (asserts! (<= expertise-match-score u100) ERR_INVALID_PROBLEM)
    
    (map-set contributor-assignments
      { problem-id: problem-id, contributor: contributor }
      {
        assignment-block: stacks-block-height,
        expertise-match-score: expertise-match-score,
        contribution-status: "assigned",
        assigned-role: assigned-role
      }
    )
    
    ;; Update problem metrics
    (let
      (
        (current-metrics (unwrap-panic (map-get? problem-metrics { problem-id: problem-id })))
        (new-count (+ (get total-contributors current-metrics) u1))
      )
      (update-problem-metrics problem-id new-count)
    )
    
    (ok true)
  )
)

;; Propose a solution to a problem
(define-public (propose-solution
                (problem-id uint)
                (solution-title (string-ascii 200))
                (solution-description (string-ascii 2000))
                (implementation-steps (list 10 (string-ascii 500)))
                (estimated-resources uint)
                (confidence-score uint))
  (let
    (
      (solution-id (var-get next-solution-id))
      (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
    )
    (asserts! (is-eq (get status problem) "open") ERR_VOTING_CLOSED)
    (asserts! (validate-implementation-steps implementation-steps) ERR_INVALID_PROBLEM)
    (asserts! (<= confidence-score u100) ERR_INVALID_PROBLEM)
    
    (map-set solutions
      { solution-id: solution-id }
      {
        problem-id: problem-id,
        proposer: tx-sender,
        solution-title: solution-title,
        solution-description: solution-description,
        implementation-steps: implementation-steps,
        estimated-resources: estimated-resources,
        confidence-score: confidence-score,
        submission-block: stacks-block-height,
        vote-count: u0,
        total-vote-weight: u0,
        status: "proposed"
      }
    )
    
    ;; Update problem solution count
    (map-set problems
      { problem-id: problem-id }
      (merge problem { total-solutions: (+ (get total-solutions problem) u1) })
    )
    
    (var-set next-solution-id (+ solution-id u1))
    (ok solution-id)
  )
)

;; Start voting session for a problem
(define-public (start-voting-session 
                (problem-id uint)
                (duration-blocks uint)
                (solution-ids (list 20 uint)))
  (let
    (
      (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
      (max-duration (var-get max-voting-duration))
      (actual-duration (if (< duration-blocks max-duration) duration-blocks max-duration))
      (end-block (+ stacks-block-height actual-duration))
    )
    (asserts! (is-eq tx-sender (get submitter problem)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status problem) "open") ERR_VOTING_CLOSED)
    
    (map-set voting-sessions
      { problem-id: problem-id }
      {
        start-block: stacks-block-height,
        end-block: end-block,
        participating-solutions: solution-ids,
        total-participants: u0,
        consensus-reached: false,
        winning-solution: none,
        voting-status: "active"
      }
    )
    
    ;; Update problem status
    (map-set problems
      { problem-id: problem-id }
      (merge problem { status: "voting" })
    )
    
    (ok true)
  )
)

;; Cast vote on a solution
(define-public (cast-vote
                (solution-id uint)
                (vote-type (string-ascii 20))
                (reasoning (string-ascii 500))
                (voter-reputation uint)
                (expertise-relevance uint))
  (let
    (
      (solution (unwrap! (map-get? solutions { solution-id: solution-id }) ERR_SOLUTION_NOT_FOUND))
      (problem-id (get problem-id solution))
      (existing-vote (map-get? votes { solution-id: solution-id, voter: tx-sender }))
      (vote-weight (calculate-vote-weight voter-reputation expertise-relevance))
    )
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    (asserts! (is-voting-active problem-id) ERR_VOTING_CLOSED)
    (asserts! (> vote-weight u0) ERR_INVALID_VOTE_WEIGHT)
    (asserts! (or (is-eq vote-type "support") 
                  (is-eq vote-type "oppose")
                  (is-eq vote-type "abstain")) ERR_INVALID_PROBLEM)
    
    ;; Record vote
    (map-set votes
      { solution-id: solution-id, voter: tx-sender }
      {
        vote-weight: vote-weight,
        vote-type: vote-type,
        reasoning: reasoning,
        vote-block: stacks-block-height,
        expertise-relevance: expertise-relevance
      }
    )
    
    ;; Update solution statistics
    (map-set solutions
      { solution-id: solution-id }
      (merge solution {
        vote-count: (+ (get vote-count solution) u1),
        total-vote-weight: (+ (get total-vote-weight solution) vote-weight)
      })
    )
    
    ;; Update session participant count and return
    (let
      (
        (session (unwrap! (map-get? voting-sessions { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
      )
      (map-set voting-sessions
        { problem-id: problem-id }
        (merge session { total-participants: (+ (get total-participants session) u1) })
      )
      (ok true)
    )
  )
)

;; Finalize voting and determine consensus
(define-public (finalize-voting (problem-id uint))
  (let
    (
      (session (unwrap! (map-get? voting-sessions { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
      (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender (get submitter problem))
                  (>= stacks-block-height (get end-block session))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get voting-status session) "active") ERR_VOTING_CLOSED)
    
    ;; Determine winning solution (simplified - highest vote weight)
    (let
      (
        (winning-solution-id (fold find-winning-solution (get participating-solutions session) none))
      )
      (map-set voting-sessions
        { problem-id: problem-id }
        (merge session {
          consensus-reached: (is-some winning-solution-id),
          winning-solution: winning-solution-id,
          voting-status: "finalized"
        })
      )
      
      ;; Update problem status
      (map-set problems
        { problem-id: problem-id }
        (merge problem { status: (if (is-some winning-solution-id) "resolved" "unresolved") })
      )
      
      (ok winning-solution-id)
    )
  )
)

;; Close problem (submitter only)
(define-public (close-problem (problem-id uint))
  (let
    (
      (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get submitter problem)) ERR_UNAUTHORIZED)
    
    (map-set problems
      { problem-id: problem-id }
      (merge problem { status: "closed" })
    )
    
    (ok true)
  )
)

;; Private helper function for finding winning solution
(define-private (find-winning-solution (solution-id uint) (current-best (optional uint)))
  (let
    (
      (current-solution (unwrap-panic (map-get? solutions { solution-id: solution-id })))
    )
    (match current-best
      best-id
      (let
        (
          (best-solution (unwrap-panic (map-get? solutions { solution-id: best-id })))
        )
        (if (> (get total-vote-weight current-solution) (get total-vote-weight best-solution))
          (some solution-id)
          current-best
        )
      )
      (some solution-id)
    )
  )
)

;; Read-only functions

(define-read-only (get-problem-info (problem-id uint))
  (map-get? problems { problem-id: problem-id })
)

(define-read-only (get-solution-info (solution-id uint))
  (map-get? solutions { solution-id: solution-id })
)

(define-read-only (get-voting-session-info (problem-id uint))
  (map-get? voting-sessions { problem-id: problem-id })
)

(define-read-only (get-vote-info (solution-id uint) (voter principal))
  (map-get? votes { solution-id: solution-id, voter: voter })
)

(define-read-only (get-contributor-assignment (problem-id uint) (contributor principal))
  (map-get? contributor-assignments { problem-id: problem-id, contributor: contributor })
)

(define-read-only (get-problem-metrics (problem-id uint))
  (map-get? problem-metrics { problem-id: problem-id })
)

(define-read-only (get-consensus-threshold)
  (var-get min-consensus-threshold)
)
