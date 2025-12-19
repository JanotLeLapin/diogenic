const BLOCK_SIZE = 128
const REQUEST_THRESHOLD = BLOCK_SIZE * 32

class DiogenicProcessor extends AudioWorkletProcessor {
  constructor() {
    super()
    this.buffer = new Float32Array(BLOCK_SIZE * 64)
    this.readIdx = 0
    this.writeIdx = 0
    this.underflowCount = 0
    this.volume = 0.1

    this.port.onmessage = (e) => {
      if (e.data.samples) {
        this.enqueue(e.data.samples)
      } else if (e.data.volume) {
        this.volume = e.data.volume
      }
    }
  }

  enqueue(samples) {
    const available = this.buffer.length - this.usedSpace()
    if (available < samples.length) {
      console.warn('OVERFLOW')
      return
    }

    for (let i = 0; i < samples.length; i++) {
      this.buffer[this.writeIdx] = samples[i]
      this.writeIdx = (this.writeIdx + 1) % this.buffer.length
    }
  }

  usedSpace() {
    return (this.writeIdx >= this.readIdx) ? this.writeIdx - this.readIdx : this.buffer.length - this.readIdx + this.writeIdx
  }

  process(_, outputs) {
    const needed = outputs[0][0].length

    if (this.usedSpace() < REQUEST_THRESHOLD) {
      this.port.postMessage({ type: 'requestBlock' })
    }

    if (this.usedSpace() < needed) {
      this.underflowCount++
      console.warn('UNDERFLOW!')
      outputs[0].forEach((channel) => {
        channel.fill(0)
      })
      return true
    }

    for (let i = 0; i < needed; i++) {
      outputs[0].forEach((channel) => {
        channel[i] = this.buffer[this.readIdx] * this.volume
        this.readIdx = (this.readIdx + 1) % this.buffer.length
      })
    }

    return true
  }
}

registerProcessor('diogenic-processor', DiogenicProcessor)
