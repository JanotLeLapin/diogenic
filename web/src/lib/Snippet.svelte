<script lang="ts">
  import CodeMirror from './CodeMirror.svelte'
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

  let {
    doc = '',
  } = $props<{
    doc?: string,
  }>();

  let src: string | undefined = $state((() => doc)())

  const baseUrl = (import.meta.env.DEV ? 'http://localhost:4321/diogenic/' : import.meta.env.BASE_URL)

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

  function deinitAudio() {
    if (AUDIO == null) {
      return
    }

    AUDIO.node.disconnect()
    AUDIO = null
  }

  onMount(() => {
    initDiogenic().then(() => console.log('initialized!'))
    return () => {
      deinitAudio()

      if (DIOGENIC == null) {
        return
      }
      DIOGENIC.deinit()
    }
  })
</script>

<div class="snippet-container not-content">
  <div class="editor-wrap">
    <CodeMirror
      extensions={[basicSetup, editorTheme]}
      bind:doc={src} />
  </div>
  <button onclick={() => initAudio()}>Play</button>
  <button onclick={() => deinitAudio()}>Stop</button>
</div>

<style>
  .snippet-container {
    border: 1px solid var(--sl-color-gray-5);
    border-radius: 0.5rem;
    padding: 1rem;
    background: #034;
  }

  .editor-wrap {
    border: 1px solid rgba(255,255,255,0.1);
  }
</style>
