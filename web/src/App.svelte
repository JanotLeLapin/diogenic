<script lang="ts">
  import CodeMirror from './lib/CodeMirror.svelte'
  import { onMount } from 'svelte'
  import { Diogenic } from './diogenic'
  import { Audio } from './audio'
  import { basicSetup, EditorView } from 'codemirror';

  const editorTheme = EditorView.theme({
    "&": {
      color: "white",
      backgroundColor: "#034"
    },
    ".cm-content": {
      caretColor: "white"
    },
    "&.cm-focused .cm-cursor": {
      borderLeftColor: "white"
    },
    "&.cm-focused .cm-selectionBackground, ::selection": {
      backgroundColor: "#074"
    },
    ".cm-gutters": {
      backgroundColor: "#045",
      color: "#ddd",
      border: "none"
    },
  }, { dark: true })

  let DIOGENIC: Diogenic | null = null
  let AUDIO: Audio | null = null

  let src: string | undefined = $state('hi')

  const baseUrl = (import.meta.env.DEV ? 'http://localhost:5173/diogenic/' : import.meta.env.BASE_URL)

  async function initDiogenic(): Promise<void> {
    const wasmUrl = baseUrl + 'diogenic-wasm.wasm'

    const diogenic = await Diogenic.instantiate(wasmUrl)
    DIOGENIC = diogenic;
  }

  async function initAudio(): Promise<void> {
    if (DIOGENIC == null) {
      return
    }

    const instr_count = DIOGENIC.compile(src || '', 48000.0)
    if (instr_count < 0) {
      console.log('compile error!')
      return
    }
    console.log('compiled ' + instr_count + ' instructions')

    if (AUDIO == null) {
      const workletUrl = baseUrl + 'diogenic-processor.js'
      const audio = await Audio.init(new window.AudioContext(), DIOGENIC, workletUrl)
      AUDIO = audio
    }
  }

  onMount(() => {
    initDiogenic().then(() => console.log('initialized!'))
    return () => {
      if (DIOGENIC == null) {
        return;
      }

      DIOGENIC.deinit()
    }
  })
</script>

<main>
  <CodeMirror
    extensions={[basicSetup, editorTheme]}
    bind:doc={src} />

  <button onclick={() => initAudio()}>Click me</button>
</main>
