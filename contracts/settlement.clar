;; Settlement Contract
;; Handles financial reconciliation between producers and consumers

(define-data-var admin principal tx-sender)

;; Energy price in microSTX per kWh unit
(define-data-var energy-price uint u100)

;; Track energy transactions
(define-map energy-transactions uint
  {
    producer: principal,
    consumer: principal,
    energy-amount: uint,
    price-per-unit: uint,
    total-amount: uint,
    settled: bool,
    created-at: uint
  }
)

;; Track balances owed to producers
(define-map producer-balances principal uint)

;; Track payments made by consumers
(define-map consumer-payments principal uint)

(define-data-var transaction-counter uint u0)

(define-read-only (get-transaction (tx-id uint))
  (map-get? energy-transactions tx-id)
)

(define-read-only (get-energy-price)
  (var-get energy-price)
)

(define-public (set-energy-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can set price
    (ok (var-set energy-price new-price))
  )
)

;; Fixed function signature to match expected parameters
(define-public (record-energy-transfer (producer principal) (energy-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can record transfers

    ;; Calculate payment
    (let (
      (price (var-get energy-price))
      (total-payment (* energy-amount price))
      (new-tx-id (+ (var-get transaction-counter) u1))
      (consumer tx-sender) ;; Default consumer to tx-sender for simplicity
    )
      ;; Update transaction counter
      (var-set transaction-counter new-tx-id)

      ;; Record the transaction
      (map-set energy-transactions new-tx-id
        {
          producer: producer,
          consumer: consumer,
          energy-amount: energy-amount,
          price-per-unit: price,
          total-amount: total-payment,
          settled: false,
          created-at: block-height
        }
      )

      ;; Update producer balance
      (let ((current-balance (default-to u0 (map-get? producer-balances producer))))
        (map-set producer-balances producer (+ current-balance total-payment))
      )

      ;; Return the transaction ID
      (ok new-tx-id)
    )
  )
)

(define-public (make-payment (amount uint))
  (begin
    ;; Consumer makes a payment
    (let ((current-payment (default-to u0 (map-get? consumer-payments tx-sender))))
      (map-set consumer-payments tx-sender (+ current-payment amount))
      (ok true)
    )
  )
)

(define-public (withdraw-funds (amount uint))
  (begin
    ;; Producer withdraws their balance
    (let ((current-balance (default-to u0 (map-get? producer-balances tx-sender))))
      (asserts! (>= current-balance amount) (err u5)) ;; Insufficient balance
      (map-set producer-balances tx-sender (- current-balance amount))

      ;; In a real contract, this would transfer STX to the producer
      ;; (stx-transfer? amount tx-sender tx-sender)

      (ok true)
    )
  )
)

(define-read-only (get-producer-balance (producer principal))
  (default-to u0 (map-get? producer-balances producer))
)

(define-read-only (get-consumer-payment-total (consumer principal))
  (default-to u0 (map-get? consumer-payments consumer))
)

(define-public (mark-transaction-settled (tx-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can mark as settled
    (let ((tx (unwrap! (get-transaction tx-id) (err u6))))
      (ok (map-set energy-transactions tx-id
        (merge tx { settled: true })
      ))
    )
  )
)
