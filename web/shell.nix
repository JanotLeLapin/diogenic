{ pnpm
, nodejs
, typescript-language-server
, svelte-language-server
, mkShell
}: mkShell {
  buildInputs = [
    pnpm nodejs
    typescript-language-server svelte-language-server
  ];
}
