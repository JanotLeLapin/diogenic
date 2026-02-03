; inspired by an ig reel
; credit to @nepticmusic
; very powerful bass!!

(use std/builtin)

(defun tube
  (in
   (drive :doc "input gain")
   (bias  :doc "dc offset"))
  "asymmetric tube saturation"
  (-> in
      (* drive)
      (+ bias)
      (tanh)
      (- (tanh bias))
      (* (+ 1.0 (* 2.0 (abs bias))))))

(defun bass! (freq fan-freq)
  "awesome bass"
  (-> (triangle! freq)
      (* 0.45)
      (* (abs (sine! fan-freq)))
      (b-lowpass!
        :freq 1200.0
        :q 1.2)
      (+ (-> (sine! (* (/ 1 16) freq))
             (* 0.55)))
      (* 3.0)
      (tanh)
      (b-highpass!
        :freq (* 0.5 freq))
      (* 0.55)
      (+ (-> (sine! (* (/ 1 8) freq))
             (* 0.45)))
      (tube 1.4 0.35)
      (clip 1.8)
      (* 0.4)))

(let
  (ramp (-> (sawtooth! 0.22)
            (builtin/slew! 0.05)))
  (bass!
    (map ramp -1 1 580 280)
    (map ramp -1 1 9.0 4.0)))
