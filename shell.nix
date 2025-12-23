{ zig
, portaudio
, raylib
, libGL
, xorg
, pkg-config
, zls
, mkShell
}: mkShell {
  nativeBuildInputs = [
    zig zls pkg-config
  ];
  buildInputs = [
    portaudio raylib
    libGL

    xorg.libX11
    xorg.libX11.dev
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
    xorg.libXinerama
    xorg.libXext
    xorg.libXrender
    xorg.libXfixes

    zls
  ];
}
