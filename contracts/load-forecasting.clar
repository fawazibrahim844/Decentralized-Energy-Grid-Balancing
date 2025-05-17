;; Generation Scheduling Contract
;; Optimizes energy production timing based on forecasts

(define-data-var admin principal tx-sender)

;; Store generation schedules by producer and time period
(define-map schedules { producer: principal, period-id: uint }
  {
    target-output: uint,
    start-block: uint,
    end-block: uint,
    priority: uint, ;; 1-10, higher is more important
    created-at: uint
  }
)

;; Track actual generation for reconciliation
(define-map actual-generation { producer: principal, period-id: uint }
  {
    actual-output: uint,
    recorded-at: uint
  }
)

(define-read-only (get-schedule (producer principal) (period-id uint))
  (map-get? schedules { producer: producer, period-id: period-id })
)

;; Fixed function signature to match expected parameters
(define-public (create-schedule (producer principal) (target-output uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can create schedules

    ;; Default values for period
    (let (
      (period-id u1)
      (start-block (+ block-height u10))
      (end-block (+ block-height u110))
    )
      (ok (map-set schedules { producer: producer, period-id: period-id }
        {
          target-output: target-output,
          start-block: start-block,
          end-block: end-block,
          priority: u5, ;; Default medium priority
          created-at: block-height
        }
      ))
    )
  )
)

(define-public (report-generation (period-id uint) (actual-output uint))
  (begin
    ;; Producer reports their actual generation
    (ok (map-set actual-generation { producer: tx-sender, period-id: period-id }
      {
        actual-output: actual-output,
        recorded-at: block-height
      }
    ))
  )
)

(define-read-only (get-generation-compliance (producer principal) (period-id uint))
  (let (
    (schedule (unwrap-panic (get-schedule producer period-id)))
    (actual (default-to { actual-output: u0, recorded-at: u0 }
              (map-get? actual-generation { producer: producer, period-id: period-id })))
  )
    (if (is-eq (get actual-output actual) u0)
      ;; No actual data yet
      none
      ;; Calculate compliance as percentage of target achieved
      (let (
        (target (get target-output schedule))
        (actual-val (get actual-output actual))
        (compliance-percent (/ (* actual-val u100) target))
      )
        (some compliance-percent)
      )
    )
  )
)

(define-public (adjust-schedule (producer principal) (period-id uint) (new-target-output uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can adjust schedules
    (let ((current-schedule (unwrap! (get-schedule producer period-id) (err u4))))
      (ok (map-set schedules { producer: producer, period-id: period-id }
        (merge current-schedule { target-output: new-target-output })
      ))
    )
  )
)
