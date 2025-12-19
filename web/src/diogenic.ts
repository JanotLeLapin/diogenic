type Wasm = WebAssembly.WebAssemblyInstantiatedSource

type Exports = {
  memory: any,
  alloc: (len: number) => number,
  compile: (src_ptr: number, src_len: number) => number,
  deinit: () => void,
}

export class Diogenic {
  wasm: Wasm

  private constructor(wasm: Wasm) {
    this.wasm = wasm
  }

  private getExports(): Exports {
    return this.wasm.instance.exports as any as Exports
  }

  static async instantiate(url: string): Promise<Diogenic> {
    return await fetch(url)
      .then((res) => res.bytes())
      .then((bytes) => WebAssembly.instantiate(bytes.buffer))
      .then((wasm) => new Diogenic(wasm))
  }

  compile(src: string): number {
    const encoder = new TextEncoder()
    const bytes = encoder.encode(src)
    const len = bytes.length;

    const ptr = this.getExports().alloc(len)

    const mem = new Uint8Array(
      this.getExports().memory.buffer,
      ptr,
      len,
    )
    mem.set(bytes)

    return this.getExports().compile(ptr, len)
  }

  deinit() {
    this.getExports().deinit()
  }
}
