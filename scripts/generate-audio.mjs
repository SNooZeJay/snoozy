/**
 * Generates the five bundled, seamless Snoozy ambient loops.
 * Mono, 44.1 kHz, 16-bit PCM. Deterministic so builds are repeatable.
 *
 * Run: node scripts/generate-audio.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const outDir = path.resolve(__dirname, '..', 'assets', 'sounds');
fs.mkdirSync(outDir, { recursive: true });

const RATE = 44_100;
const SECONDS = 30;
const LENGTH = RATE * SECONDS;
const FADE = Math.floor(RATE * 1.25);

function mulberry32(seed) {
  let a = seed >>> 0;
  return function random() {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4_294_967_296;
  };
}

function onePole(target, alpha, state = 0) {
  let z = state;
  return (x) => {
    z += alpha * (x - z);
    return z;
  };
}

function makeNoise(random) {
  return () => random() * 2 - 1;
}

function crossfadeLoop(samples, fadeLength) {
  const out = samples.slice(0, LENGTH);
  for (let i = 0; i < fadeLength; i += 1) {
    const t = i / (fadeLength - 1);
    // The loop ends at samples[LENGTH - 1], then wraps to samples[LENGTH].
    // Blending the extra tail into the head keeps that seam sample-adjacent.
    const head = Math.sin(t * Math.PI * 0.5);
    const tail = Math.cos(t * Math.PI * 0.5);
    out[i] = samples[i] * head + samples[LENGTH + i] * tail;
  }
  return out;
}

function normalizeLoudness(samples, targetDb = -20, ceiling = 0.95) {
  let sumSquares = 0;
  for (let i = 0; i < samples.length; i += 1) {
    sumSquares += samples[i] * samples[i];
  }
  const rms = Math.sqrt(sumSquares / samples.length);
  if (rms === 0) return samples;

  let scale = Math.pow(10, targetDb / 20) / rms;
  let peak = 0;
  for (let i = 0; i < samples.length; i += 1) {
    const value = Math.abs(samples[i] * scale);
    if (value > peak) peak = value;
  }
  if (peak > ceiling) scale *= ceiling / peak;

  for (let i = 0; i < samples.length; i += 1) samples[i] *= scale;
  return samples;
}

function writeWav(filePath, samples) {
  const dataBytes = samples.length * 2;
  const buffer = Buffer.alloc(44 + dataBytes);
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + dataBytes, 4);
  buffer.write('WAVE', 8);
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(1, 22);
  buffer.writeUInt32LE(RATE, 24);
  buffer.writeUInt32LE(RATE * 2, 28);
  buffer.writeUInt16LE(2, 32);
  buffer.writeUInt16LE(16, 34);
  buffer.write('data', 36);
  buffer.writeUInt32LE(dataBytes, 40);
  for (let i = 0; i < samples.length; i += 1) {
    const clamped = Math.max(-1, Math.min(1, samples[i]));
    const value = clamped < 0 ? clamped * 32768 : clamped * 32767;
    buffer.writeInt16LE(Math.round(value), 44 + i * 2);
  }
  fs.writeFileSync(filePath, buffer);
}

function makeRain() {
  const random = mulberry32(0x5eed0001);
  const noise = makeNoise(random);
  const low = onePole(0.05, 0.0);
  const body = onePole(0.16, 0.0);
  const air = new Array(LENGTH + FADE).fill(0);
  let droplet = 0;
  let dropletPhase = 0;
  let dropletFreq = 0;
  let dropletDecay = 0;
  const dropRandom = mulberry32(0x51a1);
  for (let i = 0; i < air.length; i += 1) {
    const white = noise();
    const lowValue = low(white);
    const bodyValue = body(white);
    let value = lowValue * 0.18 + bodyValue * 0.4 + white * 0.05;

    // Irregular soft rain-on-leaves ticks.
    if (dropRandom() < 5.5 / RATE) {
      droplet = 0.06 + dropRandom() * 0.12;
      dropletFreq = 650 + dropRandom() * 1600;
      dropletDecay = 22 + dropRandom() * 38;
      dropletPhase = 0;
    }
    if (droplet > 0.0001) {
      dropletPhase += (Math.PI * 2 * dropletFreq) / RATE;
      value += Math.sin(dropletPhase) * droplet;
      droplet *= Math.exp(-dropletDecay / RATE);
    }

    // A barely-there warm pad keeps the rain from feeling sterile.
    const t = i / RATE;
    value += Math.sin(Math.PI * 2 * 55 * t) * 0.018;
    value += Math.sin(Math.PI * 2 * 82.5 * t + 0.4) * 0.009;
    air[i] = value;
  }
  return normalizeLoudness(crossfadeLoop(air, FADE));
}

function makeTide() {
  const random = mulberry32(0x5eed0002);
  const noise = makeNoise(random);
  const low = onePole(0.012, 0.0);
  const wash = onePole(0.07, 0.0);
  const samples = new Array(LENGTH + FADE).fill(0);
  for (let i = 0; i < samples.length; i += 1) {
    const t = i / RATE;
    // Exactly two swells in 30 seconds, so the loop repeats cleanly.
    const swell = Math.pow(0.5 + 0.5 * Math.sin(Math.PI * 2 * (2 / SECONDS) * t - Math.PI / 2), 1.6);
    const undertow = Math.pow(0.5 + 0.5 * Math.sin(Math.PI * 2 * (2 / SECONDS) * t + Math.PI / 2), 2.0);
    const white = noise();
    const lowValue = low(white);
    const washValue = wash(white);
    let value = lowValue * 0.22 + washValue * 0.2 * (0.35 + swell * 0.8);
    value += Math.sin(Math.PI * 2 * 48 * t) * 0.035 * (0.5 + undertow);
    value += Math.sin(Math.PI * 2 * 65 * t + 0.9) * 0.018 * undertow;
    // Soft foam: filtered highs that ride the swell.
    value += white * 0.018 * swell;
    samples[i] = value;
  }
  return normalizeLoudness(crossfadeLoop(samples, FADE));
}

function makeNightAir() {
  const random = mulberry32(0x5eed0003);
  const noise = makeNoise(random);
  const low = onePole(0.009, 0.0);
  const mid = onePole(0.045, 0.0);
  const samples = new Array(LENGTH + FADE).fill(0);
  for (let i = 0; i < samples.length; i += 1) {
    const t = i / RATE;
    const white = noise();
    const lowValue = low(white);
    const midValue = mid(white);
    const gust = 0.22 + 0.78 * Math.pow(0.5 + 0.5 * Math.sin(Math.PI * 2 * (3 / SECONDS) * t + 0.8), 1.7);
    let value = lowValue * 0.28 * gust + midValue * 0.055 * (0.4 + gust);
    // A distant, soft airy whistle.
    value += Math.sin(Math.PI * 2 * 392 * t + 0.2) * 0.0035 * gust * (0.5 + 0.5 * Math.sin(Math.PI * 2 * (1 / SECONDS) * t));
    value += Math.sin(Math.PI * 2 * 587 * t + 1.6) * 0.0015 * gust;
    // Low night hum.
    value += Math.sin(Math.PI * 2 * 43.65 * t) * 0.012;
    samples[i] = value;
  }
  return normalizeLoudness(crossfadeLoop(samples, FADE));
}

function makeHearth() {
  const random = mulberry32(0x5eed0004);
  const noise = makeNoise(random);
  const low = onePole(0.014, 0.0);
  const mid = onePole(0.08, 0.0);
  const samples = new Array(LENGTH + FADE).fill(0);
  const crackRandom = mulberry32(0x91f1);
  let pop = 0;
  let popPhase = 0;
  let popFreq = 0;
  let popDecay = 0;
  let popTail = 0;
  for (let i = 0; i < samples.length; i += 1) {
    const t = i / RATE;
    const white = noise();
    const lowValue = low(white);
    const midValue = mid(white);
    let value = lowValue * 0.24 + midValue * 0.13;

    if (crackRandom() < 2.4 / RATE) {
      pop = 0.1 + crackRandom() * 0.22;
      popFreq = 420 + crackRandom() * 2200;
      popDecay = 45 + crackRandom() * 90;
      popPhase = 0;
      popTail = 0.01 + crackRandom() * 0.03;
    }
    if (pop > 0.0001) {
      popPhase += (Math.PI * 2 * popFreq) / RATE;
      value += Math.sin(popPhase) * pop;
      value += (crackRandom() * 2 - 1) * popTail;
      pop *= Math.exp(-popDecay / RATE);
    }

    // Slow, warm room tone.
    value += Math.sin(Math.PI * 2 * 61.7 * t) * 0.015;
    value += Math.sin(Math.PI * 2 * 92 * t + 1.2) * 0.007;
    samples[i] = value;
  }
  return normalizeLoudness(crossfadeLoop(samples, FADE));
}

function makeDrift() {
  const random = mulberry32(0x5eed0005);
  const noise = makeNoise(random);
  const low = onePole(0.005, 0.0);
  const samples = new Array(LENGTH + FADE).fill(0);
  for (let i = 0; i < samples.length; i += 1) {
    const t = i / RATE;
    const white = noise();
    const lowValue = low(white);
    const breath = 0.5 + 0.5 * Math.sin(Math.PI * 2 * (2 / SECONDS) * t - Math.PI / 2);
    const bloom = 0.5 + 0.5 * Math.sin(Math.PI * 2 * (1 / SECONDS) * t + 1.1);
    let value = lowValue * 0.045;
    value += Math.sin(Math.PI * 2 * 55 * t) * 0.055 * (0.55 + 0.45 * breath);
    value += Math.sin(Math.PI * 2 * 82.5 * t + 0.9) * 0.032 * (0.6 + 0.4 * bloom);
    value += Math.sin(Math.PI * 2 * 110 * t + 2.0) * 0.014;
    value += Math.sin(Math.PI * 2 * 164.81 * t + 0.3) * 0.007 * bloom;
    value += Math.sin(Math.PI * 2 * 220 * t + 1.4) * 0.003 * bloom;
    samples[i] = value;
  }
  return normalizeLoudness(crossfadeLoop(samples, FADE));
}

const tracks = [
  ['rain-on-fir.wav', makeRain],
  ['low-tide.wav', makeTide],
  ['night-air.wav', makeNightAir],
  ['hearth.wav', makeHearth],
  ['deep-drift.wav', makeDrift],
];

for (const [fileName, make] of tracks) {
  const samples = make();
  const filePath = path.join(outDir, fileName);
  writeWav(filePath, samples);
  const stat = fs.statSync(filePath);
  console.log(`${fileName.padEnd(18)} ${(stat.size / 1024 / 1024).toFixed(2)} MiB  ${SECONDS}s`);
}
console.log('Done. Seamless loops generated in assets/sounds.');
