(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_ACCOUNT_NOT_FOUND (err u103))
(define-constant ERR_WITHDRAWAL_TOO_EARLY (err u104))
(define-constant ERR_INVALID_RATE (err u105))

(define-data-var interest-rate uint u5)
(define-data-var minimum-deposit uint u1000000)
(define-data-var lock-period uint u144)
(define-data-var total-deposits uint u0)
(define-data-var contract-active bool true)

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
        (rate (var-get interest-rate))
    )
    (if (> blocks-elapsed u0)
        (ok (/ (* current-balance rate blocks-elapsed) u10000))
        (ok u0)
    ))
)



(define-read-only (get-total-balance (account principal))
    (let (
        (account-data (unwrap! (map-get? user-accounts account) (err ERR_ACCOUNT_NOT_FOUND)))
        (current-balance (get balance account-data))
        (last-deposit (get last-deposit-block account-data))
        (blocks-elapsed (- stacks-block-height last-deposit))
        (rate (var-get interest-rate))
        (compound-periods (/ blocks-elapsed u144))
        (compound-interest (if (> compound-periods u0)
            (calculate-compound-helper current-balance rate compound-periods)
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
        (rate (var-get interest-rate))
        (compound-periods (/ blocks-elapsed u144))
        (compound-interest (if (> compound-periods u0)
            (calculate-compound-helper current-balance rate compound-periods)
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
        (rate (var-get interest-rate))
        (compound-periods (/ blocks-elapsed u144))
        (compound-interest (if (> compound-periods u0)
            (calculate-compound-helper (get balance account-data) rate compound-periods)
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
