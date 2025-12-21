;; what a fun patch!
(* 0.5
   (let (freq 220.0)
     (+ (* 0.4 (sine! (+ freq (sine! 0.12 0.1))))
        (* 0.02 (square! (+ freq (sine! 0.16 0.9)))))))
