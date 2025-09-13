(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_ACCOUNT_NOT_FOUND (err u103))
(define-constant ERR_WITHDRAWAL_TOO_EARLY (err u104))
(define-constant ERR_INVALID_RATE (err u105))
(define-constant ERR_GOAL_NOT_FOUND (err u106))
(define-constant ERR_GOAL_LIMIT_REACHED (err u107))
(define-constant ERR_INVALID_ALLOCATION (err u108))

(define-data-var interest-rate uint u5)
(define-data-var minimum-deposit uint u1000000)
(define-data-var lock-period uint u144)
(define-data-var total-deposits uint u0)
(define-data-var contract-active bool true)

(define-map balance-tiers uint {
    minimum-balance: uint,
    interest-rate: uint
})

(define-map time-bonuses uint {
    minimum-lock-blocks: uint,
    bonus-multiplier: uint
})

(define-map user-goals {user: principal, goal-id: uint} {
    goal-name: (string-ascii 50),
    target-amount: uint,
    allocated-amount: uint,
    target-block: uint,
    created-block: uint,
    completed: bool,
    priority: uint
})

(define-map user-goal-count principal uint)

(define-map user-accounts principal {
    balance: uint,
    last-deposit-block: uint,
    total-deposited: uint,
    total-interest-earned: uint,
    account-created-block: uint
})

(define-map user-transactions principal (list 50 {
    transaction-type: (string-ascii 10),
    amount: uint,
    stacks-block-height: uint,
    interest-earned: uint
}))

(define-read-only (get-account-info (account principal))
    (map-get? user-accounts account)
)

(define-read-only (get-user-transactions (account principal))
    (default-to (list) (map-get? user-transactions account))
)

(define-read-only (get-interest-rate)
    (var-get interest-rate)
)

(define-read-only (get-minimum-deposit)
    (var-get minimum-deposit)
)

(define-read-only (get-lock-period)
    (var-get lock-period)
)

(define-read-only (get-total-deposits)
    (var-get total-deposits)
)

(define-read-only (get-contract-status)
    (var-get contract-active)
)

(define-read-only (get-balance-tier (tier-id uint))
    (map-get? balance-tiers tier-id)
)

(define-read-only (get-time-bonus (bonus-id uint))
    (map-get? time-bonuses bonus-id)
)

(define-read-only (get-user-tier (account principal))
    (let (
        (account-data (unwrap! (map-get? user-accounts account) (err ERR_ACCOUNT_NOT_FOUND)))
        (balance (get balance account-data))
    )
    (if (>= balance u100000000)
        (ok u4)
        (if (>= balance u50000000)
            (ok u3)
            (if (>= balance u10000000)
                (ok u2)
                (if (>= balance u5000000)
                    (ok u1)
                    (ok u0))))))
)

(define-read-only (get-time-bonus-tier (account principal))
    (let (
        (account-data (unwrap! (map-get? user-accounts account) (err ERR_ACCOUNT_NOT_FOUND)))
        (lock-duration (- stacks-block-height (get last-deposit-block account-data)))
    )
    (if (>= lock-duration u14400)
        (ok u3)
        (if (>= lock-duration u4320)
            (ok u2)
            (if (>= lock-duration u1440)
                (ok u1)
                (ok u0)))))
)

(define-read-only (calculate-tiered-rate (account principal))
    (let (
        (user-tier (unwrap-panic (get-user-tier account)))
        (time-tier (unwrap-panic (get-time-bonus-tier account)))
        (base-tier-data (default-to {minimum-balance: u0, interest-rate: u5} (map-get? balance-tiers user-tier)))
        (time-bonus-data (default-to {minimum-lock-blocks: u0, bonus-multiplier: u100} (map-get? time-bonuses time-tier)))
        (base-rate (get interest-rate base-tier-data))
        (bonus-multiplier (get bonus-multiplier time-bonus-data))
    )
    (ok (/ (* base-rate bonus-multiplier) u100)))
)

(define-read-only (get-user-goal (user principal) (goal-id uint))
    (map-get? user-goals {user: user, goal-id: goal-id})
)

(define-read-only (get-user-goal-count (user principal))
    (default-to u0 (map-get? user-goal-count user))
)

(define-read-only (get-goal-progress (user principal) (goal-id uint))
    (let (
        (goal-data (unwrap! (map-get? user-goals {user: user, goal-id: goal-id}) (err ERR_GOAL_NOT_FOUND)))
        (target (get target-amount goal-data))
        (allocated (get allocated-amount goal-data))
        (progress-percentage (if (> target u0) (/ (* allocated u100) target) u0))
    )
    (ok {
        target-amount: target,
        allocated-amount: allocated,
        remaining-amount: (- target allocated),
        progress-percentage: progress-percentage,
        is-completed: (>= allocated target)
    }))
)

(define-read-only (get-total-allocated (user principal))
    (let (
        (goal-count (get-user-goal-count user))
    )
    (ok (fold calculate-total-allocated-helper (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9) {user: user, total: u0})))
)

(define-private (calculate-total-allocated-helper (goal-id uint) (acc {user: principal, total: uint}))
    (let (
        (user (get user acc))
        (current-total (get total acc))
        (goal-data (map-get? user-goals {user: user, goal-id: goal-id}))
    )
    (match goal-data
        goal-info {user: user, total: (+ current-total (get allocated-amount goal-info))}
        {user: user, total: current-total}))
)

(define-private (calculate-compound-helper (principal-amount uint) (rate uint) (periods uint))
    (if (is-eq periods u0)
        u0
        (let (
            (base-interest (/ (* principal-amount rate) u10000))
            (compound-multiplier (+ periods u1))
        )
        (/ (* base-interest compound-multiplier periods) u2))
    )
)

(define-read-only (calculate-interest (account principal))
    (let (
        (account-data (unwrap! (map-get? user-accounts account) (err ERR_ACCOUNT_NOT_FOUND)))
        (current-balance (get balance account-data))
        (last-deposit (get last-deposit-block account-data))
        (blocks-elapsed (- stacks-block-height last-deposit))
        (tiered-rate (unwrap-panic (calculate-tiered-rate account)))
    )
    (if (> blocks-elapsed u0)
        (ok (/ (* current-balance tiered-rate blocks-elapsed) u10000))
        (ok u0)
    ))
)



(define-read-only (get-total-balance (account principal))
    (let (
        (account-data (unwrap! (map-get? user-accounts account) (err ERR_ACCOUNT_NOT_FOUND)))
        (current-balance (get balance account-data))
        (last-deposit (get last-deposit-block account-data))
        (blocks-elapsed (- stacks-block-height last-deposit))
        (tiered-rate (unwrap-panic (calculate-tiered-rate account)))
        (compound-periods (/ blocks-elapsed u144))
        (compound-interest (if (> compound-periods u0)
            (calculate-compound-helper current-balance tiered-rate compound-periods)
            u0))
    )
    (ok (+ current-balance compound-interest)))
)

(define-read-only (time-until-unlock (account principal))
    (let (
        (account-data (unwrap! (map-get? user-accounts account) (err ERR_ACCOUNT_NOT_FOUND)))
        (last-deposit (get last-deposit-block account-data))
        (unlock-block (+ last-deposit (var-get lock-period)))
    )
    (if (>= stacks-block-height unlock-block)
        (ok u0)
        (ok (- unlock-block stacks-block-height))
    ))
)

(define-public (deposit (amount uint))
    (let (
        (depositor tx-sender)
        (current-account (default-to 
            {balance: u0, last-deposit-block: u0, total-deposited: u0, total-interest-earned: u0, account-created-block: stacks-block-height}
            (map-get? user-accounts depositor)))
        (current-transactions (default-to (list) (map-get? user-transactions depositor)))
    )
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (>= amount (var-get minimum-deposit)) ERR_INVALID_AMOUNT)
    
    (try! (stx-transfer? amount depositor (as-contract tx-sender)))
    
    (let (
        (new-balance (+ (get balance current-account) amount))
        (new-total-deposited (+ (get total-deposited current-account) amount))
        (new-transaction {
            transaction-type: "deposit",
            amount: amount,
            stacks-block-height: stacks-block-height,
            interest-earned: u0
        })
        (updated-transactions (unwrap! (as-max-len? (append current-transactions new-transaction) u50) ERR_INVALID_AMOUNT))
    )
    
    (map-set user-accounts depositor {
        balance: new-balance,
        last-deposit-block: stacks-block-height,
        total-deposited: new-total-deposited,
        total-interest-earned: (get total-interest-earned current-account),
        account-created-block: (get account-created-block current-account)
    })
    
    (map-set user-transactions depositor updated-transactions)
    (var-set total-deposits (+ (var-get total-deposits) amount))
    
    (ok {deposited: amount, new-balance: new-balance}))))

(define-public (withdraw (amount uint))
    (let (
        (withdrawer tx-sender)
        (account-data (unwrap! (map-get? user-accounts withdrawer) ERR_ACCOUNT_NOT_FOUND))
        (current-balance (get balance account-data))
        (last-deposit (get last-deposit-block account-data))
        (blocks-since-deposit (- stacks-block-height last-deposit))
        (blocks-elapsed (- stacks-block-height last-deposit))
        (tiered-rate (unwrap-panic (calculate-tiered-rate withdrawer)))
        (compound-periods (/ blocks-elapsed u144))
        (compound-interest (if (> compound-periods u0)
            (calculate-compound-helper current-balance tiered-rate compound-periods)
            u0))
        (total-available (+ current-balance compound-interest))
        (current-transactions (default-to (list) (map-get? user-transactions withdrawer)))
    )
    
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= total-available amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (>= blocks-since-deposit (var-get lock-period)) ERR_WITHDRAWAL_TOO_EARLY)
    
    (try! (as-contract (stx-transfer? amount tx-sender withdrawer)))
    
    (let (
        (new-balance (- total-available amount))
        (new-total-interest (+ (get total-interest-earned account-data) compound-interest))
        (new-transaction {
            transaction-type: "withdraw",
            amount: amount,
            stacks-block-height: stacks-block-height,
            interest-earned: compound-interest
        })
        (updated-transactions (unwrap! (as-max-len? (append current-transactions new-transaction) u50) ERR_INVALID_AMOUNT))
    )
    
    (map-set user-accounts withdrawer {
        balance: new-balance,
        last-deposit-block: stacks-block-height,
        total-deposited: (get total-deposited account-data),
        total-interest-earned: new-total-interest,
        account-created-block: (get account-created-block account-data)
    })
    
    (map-set user-transactions withdrawer updated-transactions)
    (var-set total-deposits (- (var-get total-deposits) amount))
    
    (ok {withdrawn: amount, interest-earned: compound-interest, new-balance: new-balance}))))

(define-public (claim-interest)
    (let (
        (claimer tx-sender)
        (account-data (unwrap! (map-get? user-accounts claimer) ERR_ACCOUNT_NOT_FOUND))
        (last-deposit (get last-deposit-block account-data))
        (blocks-elapsed (- stacks-block-height last-deposit))
        (tiered-rate (unwrap-panic (calculate-tiered-rate claimer)))
        (compound-periods (/ blocks-elapsed u144))
        (compound-interest (if (> compound-periods u0)
            (calculate-compound-helper (get balance account-data) tiered-rate compound-periods)
            u0))
        (current-transactions (default-to (list) (map-get? user-transactions claimer)))
    )
    
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (> compound-interest u0) ERR_INVALID_AMOUNT)
    
    (try! (as-contract (stx-transfer? compound-interest tx-sender claimer)))
    
    (let (
        (current-balance (get balance account-data))
        (new-total-interest (+ (get total-interest-earned account-data) compound-interest))
        (new-transaction {
            transaction-type: "interest",
            amount: compound-interest,
            stacks-block-height: stacks-block-height,
            interest-earned: compound-interest
        })
        (updated-transactions (unwrap! (as-max-len? (append current-transactions new-transaction) u50) ERR_INVALID_AMOUNT))
    )
    
    (map-set user-accounts claimer {
        balance: current-balance,
        last-deposit-block: stacks-block-height,
        total-deposited: (get total-deposited account-data),
        total-interest-earned: new-total-interest,
        account-created-block: (get account-created-block account-data)
    })
    
    (map-set user-transactions claimer updated-transactions)
    
    (ok {interest-claimed: compound-interest, total-interest-earned: new-total-interest}))))

(define-public (emergency-withdraw)
    (let (
        (withdrawer tx-sender)
        (account-data (unwrap! (map-get? user-accounts withdrawer) ERR_ACCOUNT_NOT_FOUND))
        (current-balance (get balance account-data))
        (penalty-amount (/ current-balance u10))
        (withdrawal-amount (- current-balance penalty-amount))
        (current-transactions (default-to (list) (map-get? user-transactions withdrawer)))
    )
    
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (> current-balance u0) ERR_INSUFFICIENT_BALANCE)
    
    (try! (as-contract (stx-transfer? withdrawal-amount tx-sender withdrawer)))
    
    (let (
        (new-transaction {
            transaction-type: "emergency",
            amount: withdrawal-amount,
            stacks-block-height: stacks-block-height,
            interest-earned: u0
        })
        (updated-transactions (unwrap! (as-max-len? (append current-transactions new-transaction) u50) ERR_INVALID_AMOUNT))
    )
    
    (map-set user-accounts withdrawer {
        balance: u0,
        last-deposit-block: stacks-block-height,
        total-deposited: (get total-deposited account-data),
        total-interest-earned: (get total-interest-earned account-data),
        account-created-block: (get account-created-block account-data)
    })
    
    (map-set user-transactions withdrawer updated-transactions)
    (var-set total-deposits (- (var-get total-deposits) current-balance))
    
    (ok {withdrawn: withdrawal-amount, penalty: penalty-amount}))))

(define-public (set-interest-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-rate u100) ERR_INVALID_RATE)
        (var-set interest-rate new-rate)
        (ok new-rate)))

(define-public (set-minimum-deposit (new-minimum uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> new-minimum u0) ERR_INVALID_AMOUNT)
        (var-set minimum-deposit new-minimum)
        (ok new-minimum)))

(define-public (set-lock-period (new-period uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> new-period u0) ERR_INVALID_AMOUNT)
        (var-set lock-period new-period)
        (ok new-period)))

(define-public (toggle-contract (active bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set contract-active active)
        (ok active)))

(define-public (get-contract-balance)
    (ok (stx-get-balance (as-contract tx-sender))))

(define-public (set-balance-tier (tier-id uint) (minimum-balance uint) (tier-interest-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= tier-interest-rate u100) ERR_INVALID_RATE)
        (map-set balance-tiers tier-id {
            minimum-balance: minimum-balance,
            interest-rate: tier-interest-rate
        })
        (ok tier-id)))

(define-public (set-time-bonus (bonus-id uint) (minimum-lock-blocks uint) (bonus-multiplier uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> bonus-multiplier u0) ERR_INVALID_RATE)
        (map-set time-bonuses bonus-id {
            minimum-lock-blocks: minimum-lock-blocks,
            bonus-multiplier: bonus-multiplier
        })
        (ok bonus-id)))

(define-public (initialize-tiers)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (try! (set-balance-tier u0 u0 u5))
        (try! (set-balance-tier u1 u5000000 u7))
        (try! (set-balance-tier u2 u10000000 u10))
        (try! (set-balance-tier u3 u50000000 u15))
        (try! (set-balance-tier u4 u100000000 u20))
        (try! (set-time-bonus u0 u0 u100))
        (try! (set-time-bonus u1 u1440 u110))
        (try! (set-time-bonus u2 u4320 u125))
        (try! (set-time-bonus u3 u14400 u150))
        (ok true)))

(define-public (create-goal (goal-name (string-ascii 50)) (target-amount uint) (target-block uint) (priority uint))
    (let (
        (user tx-sender)
        (current-count (get-user-goal-count user))
        (goal-id current-count)
    )
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (< current-count u10) ERR_GOAL_LIMIT_REACHED)
    (asserts! (> target-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> target-block stacks-block-height) ERR_INVALID_AMOUNT)
    
    (map-set user-goals {user: user, goal-id: goal-id} {
        goal-name: goal-name,
        target-amount: target-amount,
        allocated-amount: u0,
        target-block: target-block,
        created-block: stacks-block-height,
        completed: false,
        priority: priority
    })
    
    (map-set user-goal-count user (+ current-count u1))
    (ok goal-id)))

(define-public (allocate-to-goal (goal-id uint) (amount uint))
    (let (
        (user tx-sender)
        (account-data (unwrap! (map-get? user-accounts user) ERR_ACCOUNT_NOT_FOUND))
        (goal-data (unwrap! (map-get? user-goals {user: user, goal-id: goal-id}) ERR_GOAL_NOT_FOUND))
        (current-balance (get balance account-data))
        (current-allocated (get allocated-amount goal-data))
        (total-allocated-result (unwrap-panic (get-total-allocated user)))
        (total-allocated (get total total-allocated-result))
        (available-balance (- current-balance total-allocated))
    )
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= available-balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (not (get completed goal-data)) ERR_INVALID_ALLOCATION)
    
    (let (
        (new-allocated (+ current-allocated amount))
        (target-amount (get target-amount goal-data))
        (is-completed (>= new-allocated target-amount))
    )
    
    (map-set user-goals {user: user, goal-id: goal-id} {
        goal-name: (get goal-name goal-data),
        target-amount: target-amount,
        allocated-amount: new-allocated,
        target-block: (get target-block goal-data),
        created-block: (get created-block goal-data),
        completed: is-completed,
        priority: (get priority goal-data)
    })
    
    (ok {allocated: amount, new-total: new-allocated, completed: is-completed}))))

(define-public (deallocate-from-goal (goal-id uint) (amount uint))
    (let (
        (user tx-sender)
        (goal-data (unwrap! (map-get? user-goals {user: user, goal-id: goal-id}) ERR_GOAL_NOT_FOUND))
        (current-allocated (get allocated-amount goal-data))
    )
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= current-allocated amount) ERR_INSUFFICIENT_BALANCE)
    
    (let (
        (new-allocated (- current-allocated amount))
        (target-amount (get target-amount goal-data))
    )
    
    (map-set user-goals {user: user, goal-id: goal-id} {
        goal-name: (get goal-name goal-data),
        target-amount: target-amount,
        allocated-amount: new-allocated,
        target-block: (get target-block goal-data),
        created-block: (get created-block goal-data),
        completed: false,
        priority: (get priority goal-data)
    })
    
    (ok {deallocated: amount, new-total: new-allocated}))))

(define-public (delete-goal (goal-id uint))
    (let (
        (user tx-sender)
        (goal-data (unwrap! (map-get? user-goals {user: user, goal-id: goal-id}) ERR_GOAL_NOT_FOUND))
    )
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get allocated-amount goal-data) u0) ERR_INVALID_ALLOCATION)
    
    (map-delete user-goals {user: user, goal-id: goal-id})
    (ok true)))

(define-public (update-goal (goal-id uint) (new-target-amount uint) (new-target-block uint) (new-priority uint))
    (let (
        (user tx-sender)
        (goal-data (unwrap! (map-get? user-goals {user: user, goal-id: goal-id}) ERR_GOAL_NOT_FOUND))
    )
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (> new-target-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> new-target-block stacks-block-height) ERR_INVALID_AMOUNT)
    (asserts! (not (get completed goal-data)) ERR_INVALID_ALLOCATION)
    
    (let (
        (current-allocated (get allocated-amount goal-data))
        (is-completed (>= current-allocated new-target-amount))
    )
    
    (map-set user-goals {user: user, goal-id: goal-id} {
        goal-name: (get goal-name goal-data),
        target-amount: new-target-amount,
        allocated-amount: current-allocated,
        target-block: new-target-block,
        created-block: (get created-block goal-data),
        completed: is-completed,
        priority: new-priority
    })
    
    (ok {updated: true, completed: is-completed}))))
