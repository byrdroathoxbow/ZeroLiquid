
;; title: ZeroLiquid
;; version: 1.0.0
;; summary: Zero-liquidation DeFi lending protocol with innovative collateral management
;; description: A DeFi lending smart contract that implements zero-liquidation lending 
;;              through dynamic collateral rebalancing and automated risk management

;; traits
;; SIP-010 trait for fungible tokens (defined locally for development)
(define-trait sip-010-trait
    (
        ;; Transfer from the caller to a new principal
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))
        
        ;; the human readable name of the token
        (get-name () (response (string-ascii 32) uint))
        
        ;; the ticker symbol, or empty if none
        (get-symbol () (response (string-ascii 32) uint))
        
        ;; the number of decimals used, e.g. 6 would mean 1_000_000 represents 1 token
        (get-decimals () (response uint uint))
        
        ;; the balance of the passed principal
        (get-balance (principal) (response uint uint))
        
        ;; the current total supply (which does not need to be a constant)
        (get-total-supply () (response uint uint))
        
        ;; an optional URI that represents metadata of this token
        (get-token-uri () (response (optional (string-utf8 256)) uint))
    )
)

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-insufficient-collateral (err u102))
(define-constant err-loan-not-found (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-loan-not-active (err u106))
(define-constant err-unauthorized (err u107))
(define-constant err-invalid-collateral-ratio (err u108))

;; Minimum collateral ratio (150% = 1.5 * 10^6)
(define-constant min-collateral-ratio u1500000)
;; Target collateral ratio for rebalancing (200% = 2.0 * 10^6)
(define-constant target-collateral-ratio u2000000)
;; Liquidation threshold (never reached due to zero-liquidation mechanism)
(define-constant liquidation-threshold u1300000)
;; Precision factor for calculations (10^6)
(define-constant precision u1000000)

;; data vars
(define-data-var total-loans-issued uint u0)
(define-data-var total-collateral-deposited uint u0)
(define-data-var protocol-fee-rate uint u10000) ;; 1% = 10000 (out of 1,000,000)
(define-data-var emergency-shutdown bool false)

;; data maps
;; User loan information
(define-map loans
    { borrower: principal }
    {
        loan-amount: uint,
        collateral-amount: uint,
        interest-rate: uint,
        created-at: uint,
        last-update: uint,
        is-active: bool
    }
)

;; Collateral balances for each user
(define-map collateral-balances
    { user: principal }
    { balance: uint }
)

;; Interest accrual tracking
(define-map interest-accrued
    { borrower: principal }
    { accrued: uint }
)

;; Protocol reserves
(define-map protocol-reserves
    { token: principal }
    { amount: uint }
)

;; Authorized rebalancing bots (for automated collateral management)
(define-map authorized-bots
    { bot: principal }
    { authorized: bool }
)

;; public functions

;; Initialize the protocol (owner only)
(define-public (initialize)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)
    )
)

;; Deposit collateral
(define-public (deposit-collateral (amount uint) (token <sip-010-trait>))
    (let (
        (current-balance (default-to u0 (get balance (map-get? collateral-balances { user: tx-sender }))))
    )
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (not (var-get emergency-shutdown)) err-unauthorized)
        
        ;; Transfer tokens to contract
        (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
        
        ;; Update user's collateral balance
        (map-set collateral-balances
            { user: tx-sender }
            { balance: (+ current-balance amount) }
        )
        
        ;; Update total collateral
        (var-set total-collateral-deposited (+ (var-get total-collateral-deposited) amount))
        
        (ok amount)
    )
)

;; Borrow against collateral
(define-public (borrow (loan-amount uint) (collateral-token <sip-010-trait>))
    (let (
        (user-collateral (default-to u0 (get balance (map-get? collateral-balances { user: tx-sender }))))
        (existing-loan (map-get? loans { borrower: tx-sender }))
        (collateral-ratio (calculate-collateral-ratio user-collateral loan-amount))
    )
        (asserts! (> loan-amount u0) err-invalid-amount)
        (asserts! (is-none existing-loan) err-already-exists)
        (asserts! (>= collateral-ratio min-collateral-ratio) err-insufficient-collateral)
        (asserts! (not (var-get emergency-shutdown)) err-unauthorized)
        
        ;; Create new loan
        (map-set loans
            { borrower: tx-sender }
            {
                loan-amount: loan-amount,
                collateral-amount: user-collateral,
                interest-rate: u50000, ;; 5% annual rate
                created-at: block-height,
                last-update: block-height,
                is-active: true
            }
        )
        
        ;; Initialize interest tracking
        (map-set interest-accrued
            { borrower: tx-sender }
            { accrued: u0 }
        )
        
        ;; Update total loans
        (var-set total-loans-issued (+ (var-get total-loans-issued) loan-amount))
        
        ;; Transfer loan amount to borrower (in practice, this would be from a liquidity pool)
        ;; For now, we assume the contract has sufficient STX balance
        (try! (stx-transfer? loan-amount (as-contract tx-sender) tx-sender))
        
        (ok loan-amount)
    )
)

;; Repay loan
(define-public (repay (repay-amount uint))
    (let (
        (loan-info (unwrap! (map-get? loans { borrower: tx-sender }) err-loan-not-found))
        (current-interest (get accrued (default-to { accrued: u0 } (map-get? interest-accrued { borrower: tx-sender }))))
        (total-owed (+ (get loan-amount loan-info) current-interest))
    )
        (asserts! (> repay-amount u0) err-invalid-amount)
        (asserts! (get is-active loan-info) err-loan-not-active)
        
        ;; Transfer repayment to contract
        (try! (stx-transfer? repay-amount tx-sender (as-contract tx-sender)))
        
        (if (>= repay-amount total-owed)
            ;; Full repayment - close loan and return collateral
            (begin
                (map-delete loans { borrower: tx-sender })
                (map-delete interest-accrued { borrower: tx-sender })
                
                ;; Return collateral to borrower
                (let (
                    (collateral-balance (get balance (unwrap! (map-get? collateral-balances { user: tx-sender }) err-insufficient-balance)))
                )
                    (map-delete collateral-balances { user: tx-sender })
                    (var-set total-collateral-deposited (- (var-get total-collateral-deposited) collateral-balance))
                    
                    ;; Return excess payment if any
                    (if (> repay-amount total-owed)
                        (try! (stx-transfer? (- repay-amount total-owed) (as-contract tx-sender) tx-sender))
                        true
                    )
                    
                    (ok u0) ;; Loan fully repaid
                )
            )
            ;; Partial repayment - update loan amount
            (begin
                (let (
                    (remaining-debt (- total-owed repay-amount))
                    (updated-loan (merge loan-info { 
                        loan-amount: remaining-debt,
                        last-update: block-height 
                    }))
                )
                    (map-set loans { borrower: tx-sender } updated-loan)
                    (map-set interest-accrued { borrower: tx-sender } { accrued: u0 })
                    (ok remaining-debt)
                )
            )
        )
    )
)

;; Rebalance collateral (zero-liquidation mechanism)
(define-public (rebalance-collateral (borrower principal) (additional-collateral uint) (token <sip-010-trait>))
    (let (
        (loan-info (unwrap! (map-get? loans { borrower: borrower }) err-loan-not-found))
        (is-bot-authorized (default-to false (get authorized (map-get? authorized-bots { bot: tx-sender }))))
        (current-collateral (get balance (unwrap! (map-get? collateral-balances { user: borrower }) err-insufficient-balance)))
    )
        ;; Only authorized bots or the borrower can trigger rebalancing
        (asserts! (or is-bot-authorized (is-eq tx-sender borrower)) err-unauthorized)
        (asserts! (get is-active loan-info) err-loan-not-active)
        
        ;; If additional collateral provided, transfer it
        (if (> additional-collateral u0)
            (begin
                (try! (contract-call? token transfer additional-collateral tx-sender (as-contract tx-sender) none))
                (map-set collateral-balances
                    { user: borrower }
                    { balance: (+ current-collateral additional-collateral) }
                )
                (var-set total-collateral-deposited (+ (var-get total-collateral-deposited) additional-collateral))
            )
            true
        )
        
        ;; Update loan with new collateral amount
        (map-set loans
            { borrower: borrower }
            (merge loan-info { 
                collateral-amount: (+ current-collateral additional-collateral),
                last-update: block-height 
            })
        )
        
        (ok true)
    )
)

;; Authorize rebalancing bot (owner only)
(define-public (authorize-bot (bot principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-bots { bot: bot } { authorized: true })
        (ok true)
    )
)

;; Emergency shutdown (owner only)
(define-public (set-emergency-shutdown)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set emergency-shutdown true)
        (ok true)
    )
)

;; read only functions

;; Get loan information for a borrower
(define-read-only (get-loan-info (borrower principal))
    (map-get? loans { borrower: borrower })
)

;; Get collateral balance for a user
(define-read-only (get-collateral-balance (user principal))
    (default-to u0 (get balance (map-get? collateral-balances { user: user })))
)

;; Calculate collateral ratio for a given collateral and loan amount
(define-read-only (calculate-collateral-ratio (collateral-amount uint) (loan-amount uint))
    (if (is-eq loan-amount u0)
        u0
        (/ (* collateral-amount precision) loan-amount)
    )
)

;; Check if a loan is healthy (above minimum collateral ratio)
(define-read-only (is-loan-healthy (borrower principal))
    (match (map-get? loans { borrower: borrower })
        loan-info (let (
            (current-collateral (get balance (default-to { balance: u0 } (map-get? collateral-balances { user: borrower }))))
            (ratio (calculate-collateral-ratio current-collateral (get loan-amount loan-info)))
        )
            (>= ratio min-collateral-ratio)
        )
        false
    )
)

;; Get total protocol statistics
(define-read-only (get-protocol-stats)
    {
        total-loans: (var-get total-loans-issued),
        total-collateral: (var-get total-collateral-deposited),
        fee-rate: (var-get protocol-fee-rate),
        emergency-shutdown: (var-get emergency-shutdown)
    }
)

;; Calculate accrued interest for a borrower
(define-read-only (calculate-interest (borrower principal))
    (match (map-get? loans { borrower: borrower })
        loan-info (let (
            (blocks-elapsed (- block-height (get last-update loan-info)))
            (annual-rate (get interest-rate loan-info))
            (loan-amount (get loan-amount loan-info))
            ;; Simple interest calculation (blocks per year ~ 52560 for 10-minute blocks)
            (interest (/ (* (* loan-amount annual-rate) blocks-elapsed) (* precision u52560)))
        )
            interest
        )
        u0
    )
)

;; Check if rebalancing is needed
(define-read-only (needs-rebalancing (borrower principal))
    (match (map-get? loans { borrower: borrower })
        loan-info (let (
            (current-collateral (get balance (default-to { balance: u0 } (map-get? collateral-balances { user: borrower }))))
            (ratio (calculate-collateral-ratio current-collateral (get loan-amount loan-info)))
        )
            (< ratio target-collateral-ratio)
        )
        false
    )
)

;; private functions

;; Update interest accrual for a borrower
(define-private (update-interest-accrual (borrower principal))
    (let (
        (current-interest (calculate-interest borrower))
        (existing-accrued (get accrued (default-to { accrued: u0 } (map-get? interest-accrued { borrower: borrower }))))
    )
        (map-set interest-accrued
            { borrower: borrower }
            { accrued: (+ existing-accrued current-interest) }
        )
    )
)

;; Validate collateral ratio
(define-private (is-valid-collateral-ratio (ratio uint))
    (>= ratio min-collateral-ratio)
)

