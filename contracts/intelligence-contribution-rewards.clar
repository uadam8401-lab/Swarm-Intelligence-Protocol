;; Intelligence Contribution Rewards Contract
;; Token-based incentive system that rewards valuable contributions to collective intelligence projects
;; Manages contribution scoring, token distribution, reputation system, and performance-based rewards

;; Token Definitions
(define-fungible-token intelligence-token)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INSUFFICIENT_BALANCE (err u301))
(define-constant ERR_INVALID_AMOUNT (err u302))
(define-constant ERR_CONTRIBUTOR_NOT_FOUND (err u303))
(define-constant ERR_REWARD_NOT_FOUND (err u304))
(define-constant ERR_ALREADY_CLAIMED (err u305))
(define-constant ERR_INVALID_CONTRIBUTION_TYPE (err u306))
(define-constant ERR_REWARD_EXPIRED (err u307))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u308))

;; Token Constants
(define-constant TOTAL_SUPPLY u1000000000) ;; 1 billion tokens
(define-constant MINT_LIMIT u1000000) ;; 1 million tokens per mint
(define-constant BASE_REWARD_AMOUNT u100)
(define-constant QUALITY_MULTIPLIER u10)
(define-constant REPUTATION_BONUS_THRESHOLD u100)

;; Data Variables
(define-data-var next-reward-id uint u1)
(define-data-var next-milestone-id uint u1)
(define-data-var total-rewards-distributed uint u0)
(define-data-var reward-pool-balance uint u0)
(define-data-var quality-threshold uint u70)
(define-data-var reputation-multiplier uint u5)

;; Data Maps
(define-map contribution-rewards
  { reward-id: uint }
  {
    contributor: principal,
    contribution-type: (string-ascii 50),
    problem-id: uint,
    solution-id: (optional uint),
    quality-score: uint,
    impact-rating: uint,
    base-reward: uint,
    bonus-reward: uint,
    total-reward: uint,
    reward-status: (string-ascii 20),
    creation-block: uint,
    claim-deadline: uint
  }
)

(define-map contributor-stats
  { contributor: principal }
  {
    total-contributions: uint,
    total-rewards-earned: uint,
    average-quality-score: uint,
    reputation-level: uint,
    consecutive-quality-contributions: uint,
    last-contribution-block: uint,
    total-tokens-earned: uint
  }
)

(define-map reward-milestones
  { milestone-id: uint }
  {
    milestone-type: (string-ascii 50),
    target-value: uint,
    reward-amount: uint,
    description: (string-ascii 200),
    is-active: bool,
    total-claimed: uint
  }
)

(define-map milestone-achievements
  { contributor: principal, milestone-id: uint }
  {
    achievement-block: uint,
    reward-claimed: bool,
    achievement-value: uint
  }
)

(define-map quality-bonuses
  { quality-tier: uint }
  {
    min-score: uint,
    max-score: uint,
    bonus-multiplier: uint,
    tier-name: (string-ascii 30)
  }
)

(define-map contribution-history
  { contributor: principal, contribution-id: uint }
  {
    contribution-block: uint,
    contribution-type: (string-ascii 50),
    quality-score: uint,
    tokens-earned: uint,
    problem-category: (string-ascii 50)
  }
)

;; Initialize quality bonus tiers
(map-set quality-bonuses { quality-tier: u1 } { min-score: u90, max-score: u100, bonus-multiplier: u200, tier-name: "exceptional" })
(map-set quality-bonuses { quality-tier: u2 } { min-score: u80, max-score: u89, bonus-multiplier: u150, tier-name: "excellent" })
(map-set quality-bonuses { quality-tier: u3 } { min-score: u70, max-score: u79, bonus-multiplier: u120, tier-name: "good" })
(map-set quality-bonuses { quality-tier: u4 } { min-score: u60, max-score: u69, bonus-multiplier: u100, tier-name: "average" })
(map-set quality-bonuses { quality-tier: u5 } { min-score: u0, max-score: u59, bonus-multiplier: u80, tier-name: "basic" })

;; Private Functions
(define-private (calculate-quality-bonus (quality-score uint))
  (if (>= quality-score u90)
    u200
    (if (>= quality-score u80)
      u150
      (if (>= quality-score u70)
        u120
        (if (>= quality-score u60)
          u100
          u80))))
)

(define-private (calculate-reputation-bonus (contributor principal))
  (match (map-get? contributor-stats { contributor: contributor })
    stats
    (let
      (
        (reputation (get reputation-level stats))
        (consecutive-quality (get consecutive-quality-contributions stats))
      )
      (+ (/ (* reputation (var-get reputation-multiplier)) u100)
         (/ (* consecutive-quality u2) u10))
    )
    u0
  )
)

(define-private (calculate-total-reward 
                 (base-reward uint)
                 (quality-score uint)
                 (impact-rating uint)
                 (contributor principal))
  (let
    (
      (quality-bonus (calculate-quality-bonus quality-score))
      (reputation-bonus (calculate-reputation-bonus contributor))
      (impact-multiplier (+ u100 (* impact-rating u10)))
      (enhanced-base (/ (* base-reward impact-multiplier) u100))
      (quality-enhanced (/ (* enhanced-base quality-bonus) u100))
    )
    (+ quality-enhanced reputation-bonus)
  )
)

(define-private (update-contributor-stats 
                 (contributor principal)
                 (quality-score uint)
                 (tokens-earned uint))
  (let
    (
      (current-stats (default-to
        {
          total-contributions: u0,
          total-rewards-earned: u0,
          average-quality-score: u0,
          reputation-level: u1,
          consecutive-quality-contributions: u0,
          last-contribution-block: u0,
          total-tokens-earned: u0
        }
        (map-get? contributor-stats { contributor: contributor })
      ))
      (new-total-contributions (+ (get total-contributions current-stats) u1))
      (new-total-rewards (+ (get total-rewards-earned current-stats) tokens-earned))
      (new-avg-quality (/ (+ (* (get average-quality-score current-stats) (get total-contributions current-stats)) quality-score) new-total-contributions))
      (new-consecutive (if (>= quality-score (var-get quality-threshold))
                        (+ (get consecutive-quality-contributions current-stats) u1)
                        u0))
      (new-reputation (+ (get reputation-level current-stats) (/ quality-score u20)))
    )
    (map-set contributor-stats
      { contributor: contributor }
      {
        total-contributions: new-total-contributions,
        total-rewards-earned: new-total-rewards,
        average-quality-score: new-avg-quality,
        reputation-level: new-reputation,
        consecutive-quality-contributions: new-consecutive,
        last-contribution-block: stacks-block-height,
        total-tokens-earned: (+ (get total-tokens-earned current-stats) tokens-earned)
      }
    )
  )
)

(define-private (is-valid-contribution-type (contribution-type (string-ascii 50)))
  (or (is-eq contribution-type "problem-submission")
      (is-eq contribution-type "solution-proposal")
      (is-eq contribution-type "voting-participation")
      (is-eq contribution-type "quality-review")
      (is-eq contribution-type "implementation-support")
      (is-eq contribution-type "expertise-consultation")
      (is-eq contribution-type "data-analysis")
      (is-eq contribution-type "creative-input")
      (is-eq contribution-type "validation-work")
      (is-eq contribution-type "community-building"))
)

;; Public Functions

;; Initialize reward pool (contract owner only)
(define-public (initialize-reward-pool (initial-amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= initial-amount MINT_LIMIT) ERR_INVALID_AMOUNT)
    
    (try! (ft-mint? intelligence-token initial-amount tx-sender))
    (var-set reward-pool-balance (+ (var-get reward-pool-balance) initial-amount))
    (ok initial-amount)
  )
)

;; Create reward for contribution
(define-public (create-contribution-reward
                (contributor principal)
                (contribution-type (string-ascii 50))
                (problem-id uint)
                (solution-id (optional uint))
                (quality-score uint)
                (impact-rating uint)
                (claim-duration-blocks uint))
  (let
    (
      (reward-id (var-get next-reward-id))
      (base-reward BASE_REWARD_AMOUNT)
      (total-reward (calculate-total-reward base-reward quality-score impact-rating contributor))
      (claim-deadline (+ stacks-block-height claim-duration-blocks))
      (bonus-reward (- total-reward base-reward))
    )
    (asserts! (is-valid-contribution-type contribution-type) ERR_INVALID_CONTRIBUTION_TYPE)
    (asserts! (<= quality-score u100) ERR_INVALID_AMOUNT)
    (asserts! (<= impact-rating u10) ERR_INVALID_AMOUNT)
    
    (map-set contribution-rewards
      { reward-id: reward-id }
      {
        contributor: contributor,
        contribution-type: contribution-type,
        problem-id: problem-id,
        solution-id: solution-id,
        quality-score: quality-score,
        impact-rating: impact-rating,
        base-reward: base-reward,
        bonus-reward: bonus-reward,
        total-reward: total-reward,
        reward-status: "pending",
        creation-block: stacks-block-height,
        claim-deadline: claim-deadline
      }
    )
    
    (var-set next-reward-id (+ reward-id u1))
    (ok reward-id)
  )
)

;; Claim reward tokens
(define-public (claim-reward (reward-id uint))
  (let
    (
      (reward (unwrap! (map-get? contribution-rewards { reward-id: reward-id }) ERR_REWARD_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get contributor reward)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get reward-status reward) "pending") ERR_ALREADY_CLAIMED)
    (asserts! (< stacks-block-height (get claim-deadline reward)) ERR_REWARD_EXPIRED)
    
    (let
      (
        (reward-amount (get total-reward reward))
      )
      (asserts! (>= (var-get reward-pool-balance) reward-amount) ERR_INSUFFICIENT_BALANCE)
      
      ;; Transfer tokens to contributor
      (try! (ft-transfer? intelligence-token reward-amount tx-sender (get contributor reward)))
      
      ;; Update reward status
      (map-set contribution-rewards
        { reward-id: reward-id }
        (merge reward { reward-status: "claimed" })
      )
      
      ;; Update global stats
      (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) reward-amount))
      (var-set reward-pool-balance (- (var-get reward-pool-balance) reward-amount))
      
      ;; Update contributor stats
      (update-contributor-stats (get contributor reward) (get quality-score reward) reward-amount)
      
      (ok reward-amount)
    )
  )
)

;; Create milestone reward
(define-public (create-milestone
                (milestone-type (string-ascii 50))
                (target-value uint)
                (reward-amount uint)
                (description (string-ascii 200)))
  (let
    (
      (milestone-id (var-get next-milestone-id))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (map-set reward-milestones
      { milestone-id: milestone-id }
      {
        milestone-type: milestone-type,
        target-value: target-value,
        reward-amount: reward-amount,
        description: description,
        is-active: true,
        total-claimed: u0
      }
    )
    
    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

;; Claim milestone achievement
(define-public (claim-milestone-achievement 
                (milestone-id uint)
                (achievement-value uint))
  (let
    (
      (milestone (unwrap! (map-get? reward-milestones { milestone-id: milestone-id }) ERR_REWARD_NOT_FOUND))
      (existing-achievement (map-get? milestone-achievements { contributor: tx-sender, milestone-id: milestone-id }))
      (contributor-stats-data (map-get? contributor-stats { contributor: tx-sender }))
    )
    (asserts! (is-none existing-achievement) ERR_ALREADY_CLAIMED)
    (asserts! (get is-active milestone) ERR_REWARD_EXPIRED)
    (asserts! (>= achievement-value (get target-value milestone)) ERR_INVALID_AMOUNT)
    (asserts! (is-some contributor-stats-data) ERR_CONTRIBUTOR_NOT_FOUND)
    
    (let
      (
        (reward-amount (get reward-amount milestone))
      )
      (asserts! (>= (var-get reward-pool-balance) reward-amount) ERR_INSUFFICIENT_BALANCE)
      
      ;; Transfer milestone reward
      (try! (ft-transfer? intelligence-token reward-amount tx-sender tx-sender))
      
      ;; Record achievement
      (map-set milestone-achievements
        { contributor: tx-sender, milestone-id: milestone-id }
        {
          achievement-block: stacks-block-height,
          reward-claimed: true,
          achievement-value: achievement-value
        }
      )
      
      ;; Update milestone stats
      (map-set reward-milestones
        { milestone-id: milestone-id }
        (merge milestone { total-claimed: (+ (get total-claimed milestone) u1) })
      )
      
      ;; Update global balances
      (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) reward-amount))
      (var-set reward-pool-balance (- (var-get reward-pool-balance) reward-amount))
      
      (ok reward-amount)
    )
  )
)

;; Distribute bonus rewards for exceptional performance
(define-public (distribute-performance-bonus 
                (contributors (list 50 principal))
                (bonus-amounts (list 50 uint)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (len contributors) (len bonus-amounts)) ERR_INVALID_AMOUNT)
    
    (let
      (
        (total-bonus (fold + bonus-amounts u0))
      )
      (asserts! (>= (var-get reward-pool-balance) total-bonus) ERR_INSUFFICIENT_BALANCE)
      
      ;; Distribute bonuses
      (map distribute-single-bonus contributors bonus-amounts)
      
      ;; Update global balance
      (var-set reward-pool-balance (- (var-get reward-pool-balance) total-bonus))
      (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) total-bonus))
      
      (ok total-bonus)
    )
  )
)

;; Helper function for bonus distribution
(define-private (distribute-single-bonus (contributor principal) (amount uint))
  (ft-transfer? intelligence-token amount tx-sender contributor)
)

;; Update quality threshold (contract owner only)
(define-public (update-quality-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-threshold u100) ERR_INVALID_AMOUNT)
    
    (var-set quality-threshold new-threshold)
    (ok new-threshold)
  )
)

;; Read-only functions

(define-read-only (get-contribution-reward (reward-id uint))
  (map-get? contribution-rewards { reward-id: reward-id })
)

(define-read-only (get-contributor-stats (contributor principal))
  (map-get? contributor-stats { contributor: contributor })
)

(define-read-only (get-milestone-info (milestone-id uint))
  (map-get? reward-milestones { milestone-id: milestone-id })
)

(define-read-only (get-milestone-achievement (contributor principal) (milestone-id uint))
  (map-get? milestone-achievements { contributor: contributor, milestone-id: milestone-id })
)

(define-read-only (get-quality-bonus-tier (quality-tier uint))
  (map-get? quality-bonuses { quality-tier: quality-tier })
)

(define-read-only (get-token-balance (account principal))
  (ft-get-balance intelligence-token account)
)

(define-read-only (get-total-supply)
  (ft-get-supply intelligence-token)
)

(define-read-only (get-reward-pool-balance)
  (var-get reward-pool-balance)
)

(define-read-only (get-total-rewards-distributed)
  (var-get total-rewards-distributed)
)

(define-read-only (get-quality-threshold)
  (var-get quality-threshold)
)

(define-read-only (calculate-estimated-reward 
                  (quality-score uint)
                  (impact-rating uint)
                  (contributor principal))
  (calculate-total-reward BASE_REWARD_AMOUNT quality-score impact-rating contributor)
)
