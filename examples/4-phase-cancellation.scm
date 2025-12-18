; quick phase cancellation example
(let (freq 220.0 foo (square! 0.1 0.0)) ; base oscillator frequency
  (+ (sine! freq 0.0) ; first sine wave
     (* (sine! freq PI) ; second sine wave with
                        ; phase offset set to pi!
        ; we multiply the second sine wave with
        ; an oscillating "phase cancellation rate"
        (+ 0.5 (* 0.5 foo)))))
