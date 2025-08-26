;; WasteToEnergy Tracker Contract
;; A blockchain-based system for tracking waste management and energy production
;; with environmental credits calculation

;; Define the environmental credits token
(define-fungible-token eco-credits)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-facility-not-found (err u103))

;; Data variables
(define-data-var total-waste-processed uint u0)
(define-data-var total-energy-produced uint u0)
(define-data-var total-credits-issued uint u0)

;; Energy conversion rate: 1 ton waste = 2000 kWh energy = 100 credits
(define-constant waste-to-energy-rate u2000)
(define-constant energy-to-credits-rate u100)

;; Facility tracking map
(define-map facilities 
  principal 
  {
    name: (string-ascii 50),
    waste-processed: uint,
    energy-produced: uint,
    credits-earned: uint,
    is-active: bool
  })

;; Waste processing records
(define-map waste-records
  {facility: principal, batch-id: uint}
  {
    waste-amount: uint,
    energy-generated: uint,
    credits-awarded: uint,
    timestamp: uint,
    waste-type: (string-ascii 20)
  })

;; Batch counter for waste records
(define-data-var batch-counter uint u0)

;; Process waste and calculate energy production with environmental credits
(define-public (process-waste (waste-amount uint) (facility-name (string-ascii 50)) (waste-type (string-ascii 20)))
  (let 
    (
      (current-batch (+ (var-get batch-counter) u1))
      (energy-generated (* waste-amount waste-to-energy-rate))
      (credits-awarded (/ (* energy-generated energy-to-credits-rate) u2000))
      (current-facility (default-to 
        {name: facility-name, waste-processed: u0, energy-produced: u0, credits-earned: u0, is-active: true}
        (map-get? facilities tx-sender)))
    )
    (begin
      (asserts! (> waste-amount u0) err-invalid-amount)
      
      ;; Update facility data
      (map-set facilities tx-sender
        {
          name: facility-name,
          waste-processed: (+ (get waste-processed current-facility) waste-amount),
          energy-produced: (+ (get energy-produced current-facility) energy-generated),
          credits-earned: (+ (get credits-earned current-facility) credits-awarded),
          is-active: true
        })
      
      ;; Record waste processing batch
      (map-set waste-records 
        {facility: tx-sender, batch-id: current-batch}
        {
          waste-amount: waste-amount,
          energy-generated: energy-generated,
          credits-awarded: credits-awarded,
          timestamp: stacks-block-height,
          waste-type: waste-type
        })
      
      ;; Update global counters
      (var-set total-waste-processed (+ (var-get total-waste-processed) waste-amount))
      (var-set total-energy-produced (+ (var-get total-energy-produced) energy-generated))
      (var-set total-credits-issued (+ (var-get total-credits-issued) credits-awarded))
      (var-set batch-counter current-batch)
      
      ;; Mint environmental credits to facility
      (try! (ft-mint? eco-credits credits-awarded tx-sender))
      
      (ok {
        batch-id: current-batch,
        waste-processed: waste-amount,
        energy-generated: energy-generated,
        credits-awarded: credits-awarded
      }))))

;; Claim environmental credits (transfer credits to another address)
(define-public (claim-credits (amount uint) (recipient principal))
  (let
    (
      (sender-facility (map-get? facilities tx-sender))
      (sender-balance (ft-get-balance eco-credits tx-sender))
    )
    (begin
      (asserts! (is-some sender-facility) err-facility-not-found)
      (asserts! (> amount u0) err-invalid-amount)
      (asserts! (>= sender-balance amount) err-invalid-amount)
      
      ;; Transfer credits
      (try! (ft-transfer? eco-credits amount tx-sender recipient))
      
      (ok {
        credits-transferred: amount,
        recipient: recipient,
        remaining-balance: (- sender-balance amount)
      }))))

;; Read-only functions

;; Get facility information
(define-read-only (get-facility-info (facility principal))
  (ok (map-get? facilities facility)))

;; Get waste processing record
(define-read-only (get-waste-record (facility principal) (batch-id uint))
  (ok (map-get? waste-records {facility: facility, batch-id: batch-id})))

;; Get global statistics
(define-read-only (get-global-stats)
  (ok {
    total-waste-processed: (var-get total-waste-processed),
    total-energy-produced: (var-get total-energy-produced),
    total-credits-issued: (var-get total-credits-issued),
    total-batches: (var-get batch-counter)
  }))

;; Get credit balance
(define-read-only (get-credit-balance (account principal))
  (ok (ft-get-balance eco-credits account)))

;; Get conversion rates
(define-read-only (get-conversion-rates)
  (ok {
    waste-to-energy-rate: waste-to-energy-rate,
    energy-to-credits-rate: energy-to-credits-rate
  }))
  
;; Only the contract owner can mint new credits (for special cases)