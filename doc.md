# Diogenic docs

Diogenic DSL documentation

## Arithmetic

Arithmetic function on two signals

| Operator | Description |
|----------|-------------|
| `+`      | Add         |
| `-`      | Subtract    |
| `*`      | Multiply    |
| `/`      | Divide      |

Notes:

- division has no protection against divide-by-zero

## Comparison

Comparison function on two signals,
outputs a float mask (`0.0` for false, `1.0` for true)

| Operator | Description      |
|----------|------------------|
| `<`      | Less than        |
| `<=`     | Less or equal    |
| `>`      | Greater than     |
| `>=`     | Greater or equal |

## Math

Math function on a signal

| Name                       | Description          |
|----------------------------|----------------------|
| `log2`, `log10`, `logn`    | Logarithmic          |
| `exp2`, `exp10`            | Exponential          |
| `atan`                     | Trigonometric        |
| `floor`, `ceil`            | Rounding             |
| `midi->freq`, `freq->midi` | Pitch conversion     |
| `db->amp`, `amp->midi`     | Amplitude conversion |

## Mix

Mix functions on two signals with a coefficient

| Name    | Description                |
|---------|----------------------------|
| `blend` | Amplitude interpolation    |
| `mix`   | Weighted amplitude average |

## Oscillators

Periodic signal

Types:

- `sine`
- `square`
- `sawtooth`

Arguments:

| Name     | Default | Description  |
|----------|---------|--------------|
| `:freq`  | -       | Hz           |
| `:phase` | `0.0`   | Phase offset |

## Biquad Filter

Biquad IIR Filter

Types:

- `lowpass`
- `highpass`

Arguments:

| Name       | Default | Description    |
|------------|---------|----------------|
| `:freq`    | -       | Hz             |
| `:quality` | `0.707` | Quality factor |
| `:gain`    | `1.0`   | Gain           |
| `:input`   | -       | Input signal   |

## Shaper

Non-linear waveshaping function.
Takes a threshold and a signal.

| Name       | Description                                   |
|------------|-----------------------------------------------|
| `clamp`    | Clamps the signal between `t - 1` and `t + 1` |
| `clip`     | Clamps the signal between `t` and `-t`        |
| `diode`    | [See implementation](./src/dsp/shaper.zig)    |
| `quantize` | Quantizes the signal to bit depth = `t`       |

## Other

| Name          | Description        |
|---------------|--------------------|
| `white-noise` | Normal white noise |
