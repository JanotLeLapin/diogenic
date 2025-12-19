<script lang="ts">
  import svelteLogo from './assets/svelte.svg'
  import viteLogo from '/vite.svg'
  import Counter from './lib/Counter.svelte'
  import { onMount } from 'svelte'
  import { Diogenic } from './diogenic'
  import { Audio } from './audio'

  let DIOGENIC: Diogenic | null = null
  let AUDIO: Audio | null = null

  let src: string = ''
  const baseUrl = (import.meta.env.DEV ? 'http://localhost:5173' : import.meta.env.BASE_URL)

  async function initDiogenic(): Promise<void> {
    const wasmUrl = baseUrl + '/public/diogenic-wasm.wasm'

    const diogenic = await Diogenic.instantiate(wasmUrl)
    DIOGENIC = diogenic;
  }

  async function initAudio(): Promise<void> {
    if (DIOGENIC == null) {
      return
    }

    if (AUDIO != null) {
      return
    }

    const instr_count = DIOGENIC.compile(src, 48000.0)
    if (instr_count < 0) {
      console.log('compile error!')
      return
    }
    console.log('compiled ' + instr_count + ' instructions')

    const workletUrl = baseUrl + '/public/diogenic-processor.js'
    const audio = await Audio.init(new window.AudioContext(), DIOGENIC, workletUrl)
    AUDIO = audio
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
  <div>
    <a href="https://vite.dev" target="_blank" rel="noreferrer">
      <img src={viteLogo} class="logo" alt="Vite Logo" />
    </a>
    <a href="https://svelte.dev" target="_blank" rel="noreferrer">
      <img src={svelteLogo} class="logo svelte" alt="Svelte Logo" />
    </a>
  </div>
  <h1>Vite + Svelte</h1>

  <textarea bind:value={src}></textarea>

  <button on:click={() => initAudio()}>Click me</button>

  <div class="card">
    <Counter />
  </div>

  <p>
    Check out <a href="https://github.com/sveltejs/kit#readme" target="_blank" rel="noreferrer">SvelteKit</a>, the official Svelte app framework powered by Vite!
  </p>

  <p class="read-the-docs">
    Click on the Vite and Svelte logos to learn more
  </p>
</main>

<style>
  .logo {
    height: 6em;
    padding: 1.5em;
    will-change: filter;
    transition: filter 300ms;
  }
  .logo:hover {
    filter: drop-shadow(0 0 2em #646cffaa);
  }
  .logo.svelte:hover {
    filter: drop-shadow(0 0 2em #ff3e00aa);
  }
  .read-the-docs {
    color: #888;
  }
</style>
