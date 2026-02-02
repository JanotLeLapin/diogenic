(use std/builtin)

(defun my-osc (max-factor)
  (let (factor (map (sine! 0.6) -1 1 2 max-factor)
        note (bi->uni (triangle! 0.1)))
    (sine! (-> note
               (* factor)
               (floor)
               (/ factor)
               (* 12.0)
               (+ 48.0)
               (midi->freq)))))

(defun my-limiter (in gain)
  (clip (* in gain) 1.0))

(defun my-chorus (in)
  (builtin/comb! in
                 (map (sine! 0.08) -1 1 0.09 0.017)
                 0.6
                 -1))

(-> (my-osc 20)
    (my-limiter (map (triangle! 0.08) -1 1 1.2 1.6))
    (my-chorus))
