(clip 1.0
      (atan (lowpass :freq (+ 250.0
                              (* 75.0
                                 (sine :freq (* 0.1 (+ 0.3 (sine :freq 0.1)))
                                       :phase (* (+ 0.5 (* 0.5 (sine :freq 0.35))) (white-noise)))))
                     :quality (exp2 (* 4.0
                                       (+ 1.25 (sine :freq 0.3))))
                     :input (sawtooth :freq 44.0))))
