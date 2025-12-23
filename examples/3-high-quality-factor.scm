; this may be a dangerous patch for your
; ears or your audio devices
(- (* 2.0 (sigmoid
            (b-lowpass! :freq (+ 250.0
                                 (* 75.0
                                    (sine! (* 0.1 (+ 0.3 (sine! 0.1)))
                                           (+ (* (+ 0.5 (* 0.5 (sine! 0.35))) (noise!)) 0.0))))
                        :q (exp2 (* 4.0
                                    (+ 1.26 (sine! (+ 0.53 (* 0.4 (sawtooth! 0.02)))))))
                        :in (sawtooth! (+ 44.0 (* 4.0 (+ (sine! 0.076) (sawtooth! 0.05))))))))
   1.0)
