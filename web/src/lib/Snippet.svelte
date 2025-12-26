<script module lang="ts">
  let DIOGENIC: Diogenic | null = null
  let DIOGENIC_PROMISE: Promise<Diogenic> | null = null
  let AUDIO: Audio | null = null

  const baseUrl = (import.meta.env.DEV ? 'http://localhost:4321/diogenic/' : import.meta.env.BASE_URL)

  async function initDiogenic(): Promise<Diogenic> {
    const wasmUrl = baseUrl + 'diogenic-wasm.wasm'

    return await Diogenic.instantiate(wasmUrl)
  }

  async function getDiogenic(): Promise<Diogenic> {
    if (DIOGENIC != null) {
      return DIOGENIC
    } else if (DIOGENIC_PROMISE != null) {
      try {
        DIOGENIC = await DIOGENIC_PROMISE
        DIOGENIC_PROMISE = null
        return DIOGENIC
      } catch (err) {
        DIOGENIC_PROMISE = null
        throw err
      }
    } else {
      DIOGENIC_PROMISE = initDiogenic()
      try {
        DIOGENIC = await DIOGENIC_PROMISE
        DIOGENIC_PROMISE = null
        return DIOGENIC
      } catch (err) {
        DIOGENIC_PROMISE = null
        throw err
      }
    }
  }
</script>

<script lang="ts">
  import CodeMirror from './CodeMirror.svelte'
  import { onMount } from 'svelte'
  import { Diogenic } from './diogenic'
  import { Audio } from './audio'
  import { basicSetup, EditorView } from 'codemirror';

  const editorTheme = EditorView.theme({
    "&": {
      color: "white",
      backgroundColor: "var(--sl-color-gray-6)"
    },
    ".cm-content": {
      caretColor: "var(--sl-color-white)"
    },
    "&.cm-focused .cm-cursor": {
      borderLeftColor: "var(--sl-color-white)"
    },
    "&.cm-focused .cm-selectionBackground, ::selection": {
      backgroundColor: "var(--sl-color-gray-5)"
    },
    ".cm-gutters": {
      backgroundColor: "var(--sl-color-gray-6)",
      color: "var(--sl-color-gray-2)",
      border: "none"
    },
  }, { dark: true })

  let {
    doc = '',
  } = $props<{
    doc?: string,
  }>();

  let src: string | undefined = $state((() => doc)())

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

    if (AUDIO != null) {
      return
    }

    const workletUrl = baseUrl + 'diogenic-processor.js'
    const audio = await Audio.init(new window.AudioContext(), DIOGENIC, workletUrl)
    AUDIO = audio
  }

  function deinitAudio() {
    if (AUDIO == null) {
      return
    }

    AUDIO.deinit()
    AUDIO = null
  }

  onMount(() => {
    getDiogenic()
      .then(() => console.log('initialized!'))
      .catch((err) => console.error(err))

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
    background: var(--sl-color-gray-6);
  }

  .editor-wrap {
    border: 1px solid rgba(255,255,255,0.1);
  }
</style>
