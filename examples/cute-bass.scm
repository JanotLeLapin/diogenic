(+
  (atan
    (lowpass :freq 150.0
             :quality (+ 0.5 (* 0.5 (+ 0.5 (sine :freq 0.12))))
             :input (square :freq 56.0
                            :phase (* 0.16 (white-noise)))))
  (sine :freq (/ 56.0 2.0)))
