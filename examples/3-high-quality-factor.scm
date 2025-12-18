; this may be a dangerous patch for your
; ears or your audio devices
(clip 1.0
      (atan (b-lowpass (+ 250.0
                          (* 75.0
                             (sine (* 0.1 (+ 0.3 (sine 0.1 0.0)))
                                   (+ (* (+ 0.5 (* 0.5 (sine 0.35 0.0))) (noise)) 0.0))))
                       (exp2 (* 4.0
                                (+ 1.25 (sine 0.3 0.0))))
                       1.0
                       (sawtooth 44.0 0.0))))
