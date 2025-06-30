;; Constants
(define-constant URBAN_FORESTRY_CAPACITY u2600000)
(define-constant BASE_TREE_REWARD u26)
(define-constant CANOPY_BONUS u11)
(define-constant MAX_ARBORIST_LEVEL u13)
(define-constant ERR_INVALID_TREE_ACTIVITY u1)
(define-constant ERR_NO_FORESTRY_TOKENS u2)
(define-constant ERR_FORESTRY_CAPACITY_EXCEEDED u3)
(define-constant BLOCKS_PER_GROWING_SEASON u2000)
(define-constant ECOSYSTEM_STEWARDSHIP_MULTIPLIER u6)
(define-constant MIN_STEWARDSHIP_PERIOD u1000)
(define-constant EARLY_STEWARDSHIP_PENALTY u14)

;; Data Variables
(define-data-var total-forestry-tokens-distributed uint u0)
(define-data-var total-tree-activities uint u0)
(define-data-var urban-forester principal tx-sender)

;; Data Maps
(define-map arborist-activities principal uint)
(define-map arborist-forestry-tokens principal uint)
(define-map tree-activity-start-time principal uint)
(define-map arborist-canopy-level principal uint)
(define-map arborist-last-activity principal uint)
(define-map arborist-stewardship-commitment principal uint)
(define-map arborist-stewardship-start-block principal uint)

;; Public Functions
(define-public (start-tree-planting-activity (tree-count uint))
  (let
    (
      (arborist tx-sender)
    )
    (asserts! (> tree-count u0) (err ERR_INVALID_TREE_ACTIVITY))
    (map-set tree-activity-start-time arborist burn-block-height)
    (ok true)
  )
)

(define-public (complete-tree-planting (tree-count uint))
  (let
    (
      (arborist tx-sender)
      (start-block (default-to u0 (map-get? tree-activity-start-time arborist)))
      (blocks-planting (- burn-block-height start-block))
      (last-activity-block (default-to u0 (map-get? arborist-last-activity arborist)))
      (canopy-level (default-to u0 (map-get? arborist-canopy-level arborist)))
      (capped-canopy (if (<= canopy-level MAX_ARBORIST_LEVEL) canopy-level MAX_ARBORIST_LEVEL))
      (tree-reward (+ BASE_TREE_REWARD (* capped-canopy CANOPY_BONUS)))
    )
    (asserts! (and (> start-block u0) (>= blocks-planting tree-count)) (err ERR_INVALID_TREE_ACTIVITY))
    
    (map-set arborist-activities arborist (+ (default-to u0 (map-get? arborist-activities arborist)) u1))
    (map-set arborist-forestry-tokens arborist (+ (default-to u0 (map-get? arborist-forestry-tokens arborist)) tree-reward))
    
    (if (< (- burn-block-height last-activity-block) BLOCKS_PER_GROWING_SEASON)
      (map-set arborist-canopy-level arborist (+ canopy-level u1))
      (map-set arborist-canopy-level arborist u1)
    )
    
    (map-set arborist-last-activity arborist burn-block-height)
    (var-set total-tree-activities (+ (var-get total-tree-activities) u1))
    (var-set total-forestry-tokens-distributed (+ (var-get total-forestry-tokens-distributed) tree-reward))
    
    (asserts! (<= (var-get total-forestry-tokens-distributed) URBAN_FORESTRY_CAPACITY) (err ERR_FORESTRY_CAPACITY_EXCEEDED))
    (ok tree-reward)
  )
)

(define-public (claim-forestry-rewards)
  (let
    (
      (arborist tx-sender)
      (token-balance (default-to u0 (map-get? arborist-forestry-tokens arborist)))
    )
    (asserts! (> token-balance u0) (err ERR_NO_FORESTRY_TOKENS))
    (map-set arborist-forestry-tokens arborist u0)
    (ok token-balance)
  )
)

;; Ecosystem Stewardship Features
(define-public (commit-ecosystem-stewardship (amount uint))
  (let
    (
      (arborist tx-sender)
    )
    (asserts! (> amount u0) (err ERR_INVALID_TREE_ACTIVITY))
    (asserts! (>= (var-get total-forestry-tokens-distributed) amount) (err ERR_FORESTRY_CAPACITY_EXCEEDED))
    
    (map-set arborist-stewardship-commitment arborist amount)
    (map-set arborist-stewardship-start-block arborist burn-block-height)
    (var-set total-forestry-tokens-distributed (- (var-get total-forestry-tokens-distributed) amount))
    (ok amount)
  )
)

(define-public (complete-ecosystem-stewardship)
  (let
    (
      (arborist tx-sender)
      (stewardship-amount (default-to u0 (map-get? arborist-stewardship-commitment arborist)))
      (stewardship-start-block (default-to u0 (map-get? arborist-stewardship-start-block arborist)))
      (blocks-stewarding (- burn-block-height stewardship-start-block))
      (penalty (if (< blocks-stewarding MIN_STEWARDSHIP_PERIOD) (/ (* stewardship-amount EARLY_STEWARDSHIP_PENALTY) u100) u0))
      (final-amount (- stewardship-amount penalty))
    )
    (asserts! (> stewardship-amount u0) (err ERR_NO_FORESTRY_TOKENS))
    
    (map-set arborist-stewardship-commitment arborist u0)
    (map-set arborist-stewardship-start-block arborist u0)
    (var-set total-forestry-tokens-distributed (+ (var-get total-forestry-tokens-distributed) final-amount))
    (ok final-amount)
  )
)

;; Read-Only Functions
(define-read-only (get-tree-activity-count (user principal))
  (default-to u0 (map-get? arborist-activities user))
)

(define-read-only (get-forestry-token-balance (user principal))
  (default-to u0 (map-get? arborist-forestry-tokens user))
)

(define-read-only (get-canopy-level (user principal))
  (default-to u0 (map-get? arborist-canopy-level user))
)

(define-read-only (get-urban-forestry-stats)
  {
    total-tree-activities: (var-get total-tree-activities),
    total-forestry-tokens-distributed: (var-get total-forestry-tokens-distributed)
  }
)

;; Private Functions
(define-private (is-urban-forester)
  (is-eq tx-sender (var-get urban-forester))
)