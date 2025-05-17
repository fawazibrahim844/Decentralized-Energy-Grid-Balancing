;; Load Forecasting Contract
;; Predicts consumption patterns based on historical data and external factors

(define-data-var admin principal tx-sender)

;; Store forecasts by time period (block height ranges)
(define-map forecasts uint
  {
    start-block: uint,
    end-block: uint,
    predicted-load: uint,
    confidence: uint, ;; 0-100 percentage
    created-at: uint
  }
)

;; Store actual consumption for verification
(define-map actual-consumption uint
  {
    period-id: uint,
    actual-load: uint,
    recorded-at: uint
  }
)

(define-data-var forecast-counter uint u0)

(define-read-only (get-forecast (forecast-id uint))
  (map-get? forecasts forecast-id)
)

(define-read-only (get-latest-forecast-id)
  (var-get forecast-counter)
)

;; Fixed function signature to match expected parameters
(define-public (submit-forecast (start-block uint) (predicted-load uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can submit forecasts
    (asserts! (< block-height start-block) (err u1)) ;; Start must be in future

    (let ((new-id (+ (var-get forecast-counter) u1)))
      (var-set forecast-counter new-id)
      (ok (map-set forecasts new-id
        {
          start-block: start-block,
          end-block: (+ start-block u100), ;; Default end block is start + 100
          predicted-load: predicted-load,
          confidence: u80, ;; Default confidence
          created-at: block-height
        }
      ))
    )
  )
)

(define-public (record-actual-consumption (period-id uint) (actual-load uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can record actual consumption
    (asserts! (is-some (get-forecast period-id)) (err u4)) ;; Forecast must exist

    (ok (map-set actual-consumption period-id
      {
        period-id: period-id,
        actual-load: actual-load,
        recorded-at: block-height
      }
    ))
  )
)

(define-read-only (get-forecast-accuracy (forecast-id uint))
  (let (
    (forecast (unwrap-panic (get-forecast forecast-id)))
    (actual (default-to { period-id: u0, actual-load: u0, recorded-at: u0 } (map-get? actual-consumption forecast-id)))
  )
    (if (is-eq (get actual-load actual) u0)
      ;; No actual data yet
      none
      ;; Calculate accuracy as percentage (100 - abs difference percentage)
      (let (
        (predicted (get predicted-load forecast))
        (actual-val (get actual-load actual))
        (diff (if (> predicted actual-val)
                (- predicted actual-val)
                (- actual-val predicted)))
        (diff-percent (/ (* diff u100) actual-val))
      )
        (some (- u100 diff-percent))
      )
    )
  )
)
