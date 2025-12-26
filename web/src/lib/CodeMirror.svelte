<script lang="ts">
  import { untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { EditorView, minimalSetup, basicSetup } from 'codemirror';
  import { StateEffect, type Extension, type Transaction } from '@codemirror/state';

  export { minimalSetup, basicSetup };

  let {
    doc = $bindable(),
    extensions = minimalSetup,
    verbose = false,
    onchange,
    onupdate
  } = $props<{
    doc?: string;
    extensions?: Extension | Extension[];
    verbose?: boolean;
    onchange?: (detail: { view: EditorView; transactions: readonly Transaction[] }) => void;
    onupdate?: (detail: readonly Transaction[]) => void;
  }>();

  let dom: HTMLElement;
  let view: EditorView | null = null;

  const internalStore = writable((() => doc)());

  function handleEditorUpdate(update: any) {
    if (verbose && onupdate) onupdate(update.transactions);

    if (update.docChanged) {
      const newDoc = update.state.doc.toString();
      doc = newDoc

      if (onchange) onchange({ view: update.view, transactions: update.transactions });

      internalStore.update(s => (s !== newDoc ? newDoc : s));
    }
  }

  $effect(() => {
    const initialDoc = untrack(() => doc)

    view = new EditorView({
      doc: initialDoc,
      extensions,
      parent: dom,
      dispatchTransactions: (tr) => {
        if (!view) return;
        view.update(tr);
        handleEditorUpdate({ view, state: view.state, transactions: tr, docChanged: tr.some(t => t.docChanged) });
      },
    });

    return () => {
      view?.destroy();
      view = null;
    };
  });

  $effect(() => {
    const unsubscribe = internalStore.subscribe((val) => {
      if (view && val !== view.state.doc.toString()) {
        view.dispatch({
          changes: { from: 0, to: view.state.doc.length, insert: val }
        });
      }
    });

    return unsubscribe;
  });

  $effect(() => {
    if (view && extensions) {
      view.dispatch({
        effects: StateEffect.reconfigure.of(extensions)
      });
    }
  });
</script>

<div class="codemirror" bind:this={dom}></div>
