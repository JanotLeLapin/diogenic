import type { Diogenic } from "./diogenic"

const BLOCK_SIZE = 128
const CHUNK_SIZE = BLOCK_SIZE * 8

export class Audio {
  ctx: AudioContext
  node: AudioWorkletNode
  diogenic: Diogenic
  buffer: Float32Array

  constructor(ctx: AudioContext, node: AudioWorkletNode, diogenic: Diogenic) {
    this.ctx = ctx
    this.node = node
    this.diogenic = diogenic
    this.buffer = new Float32Array(CHUNK_SIZE)
  }

  static async init(ctx: AudioContext, diogenic: Diogenic, workletUrl: string): Promise<Audio> {
    await ctx.audioWorklet.addModule(workletUrl)
    const node = new AudioWorkletNode(ctx, 'diogenic-processor', {
      outputChannelCount: [2],
      numberOfInputs: 0,
      numberOfOutputs: 1,
      channelCount: 2,
      channelCountMode: 'explicit',
    })
    const audio = new Audio(ctx, node, diogenic)
    audio.node.port.onmessage = (e) => {
      if (e.data.type === 'requestBlock') {
        for (let i = 0; i < 4; i++) {
          diogenic.eval()
          const buf = diogenic.getBuffer()
          audio.buffer.set(buf, i * BLOCK_SIZE * 2)
        }
        audio.sendAudioBlock(audio.buffer)
      }
    }
    node.connect(ctx.destination)

    return audio
  }

  startAudio() {
    if (this.ctx.state === 'suspended') {
      this.ctx.resume()
    }
  }

  sendAudioBlock(samples: Float32Array) {
    if (this.node) {
      this.node.port.postMessage({ samples })
    }
  }

  sendVolume(volume: number) {
    if (this.node) {
      this.node.port.postMessage({ volume })
    }
  }

  deinit() {
    this.node.port.postMessage({ type: 'shutdown' })
    this.node.port.onmessage = null
    this.node.port.close()

    this.node.disconnect()
  }
}
