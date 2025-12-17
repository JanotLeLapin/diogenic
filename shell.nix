{ zig
, portaudio
, zls
, mkShell
}: mkShell {
  buildInputs = [ zig portaudio zls ];
}
