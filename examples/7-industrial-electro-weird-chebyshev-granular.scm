(* 0.08
   (grains! :density 150.0
            :size (+ 60.0 (* 55.0 (triangle! 0.04)))
            :position (+ 0.5
                         (* 0.0006
                            (* (sine! 0.01 PI)
                               (noise!))))
            :fade (+ 10.0 (* 5.0 (noise!)))
            :in (let
                  (order-center 6.0
                   order-freq (+ 0.1 (* 0.1 (sine! 0.4))))
                  (chebyshev (triangle! (+ 110.0 (* 12.0 (* (noise!) (sine! 0.1)))))
                             (+ order-center
                                (* (- order-center 1.0)
                                   (foldback (+ 0.5 (* 0.45 (triangle! 0.6)))
                                             (sine! order-freq))))))))

