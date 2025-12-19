type Wasm = WebAssembly.WebAssemblyInstantiatedSource

type Exports = {
  foo: () => number,
}

export class Diogenic {
  wasm: Wasm

  private constructor(wasm: Wasm) {
    this.wasm = wasm
  }

  private getExports(): Exports {
    return this.wasm.instance.exports as Exports
  }

  static async instantiate(url: string): Promise<Diogenic> {
    return await fetch(url)
      .then((res) => res.bytes())
      .then((bytes) => WebAssembly.instantiate(bytes.buffer))
      .then((wasm) => new Diogenic(wasm))
  }

  foo(): number {
    console.log(this.wasm.instance.exports)
    return this.getExports().foo()
  }
}
