{ zig
, zls
, mkShell
}: mkShell {
  buildInputs = [ zig zls ];
}
