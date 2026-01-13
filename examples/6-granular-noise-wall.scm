(tanh ; soft saturation that also limits the signal between -1.0 and 1.0
            ; oscillates between 200 and 400 grains per second
   (grains! :density (+ 300.0 (* 100.0 (sawtooth! 0.097)))
            :size 15.0 ; small grains!
            ; oscillates between 0.1 and 0.9 playback speed for each grain
            :speed (+ 0.5 (* 0.4 (triangle! 0.04)))
            ; !!most important param here!!
            ; the spawn position is modulated by a deeply-nested
            ; noise device that makes the input signal sound all
            ; jitter-y
            :position (* (+ 0.5
                            (* 0.5
                               (sine! 0.045
                                      (* 1.49 PI))))
                         (* 0.1
                            (b-lowpass! :freq (+ 250.0
                                                 (* 245.0
                                                    (sine! (+ 6.0
                                                              (* 5.9
                                                                 (sine! 0.1))))))
                                        :in (noise!))))
            ; input signal, slowly and softly modulated sine wave
            ; ends up completely mangled by the granular synthesizer
            :in (-> (sawtooth! 0.54)
                    (* 0.02)
                    (+ 69.0)
                    (midi->freq)
                    (sine!))))
