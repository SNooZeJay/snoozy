import * as FileSystem from 'expo-file-system/legacy';

type Id3Lyrics =
  | { kind: 'uslt'; text: string }
  | { kind: 'sylt'; lines: { time: number; text: string }[] };

function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function readSynchsafe(bytes: Uint8Array, offset: number): number {
  return (
    ((bytes[offset] & 0x7f) << 21) |
    ((bytes[offset + 1] & 0x7f) << 14) |
    ((bytes[offset + 2] & 0x7f) << 7) |
    (bytes[offset + 3] & 0x7f)
  );
}

function decodeText(encoding: number, bytes: Uint8Array, start: number, end: number): string {
  const slice = bytes.subarray(start, end);
  if (encoding === 0) {
    // ISO-8859-1
    let s = '';
    for (let i = 0; i < slice.length; i++) s += String.fromCharCode(slice[i]);
    return s;
  }
  if (encoding === 3) {
    try {
      return new TextDecoder('utf-8').decode(slice);
    } catch {
      let s = '';
      for (let i = 0; i < slice.length; i++) s += String.fromCharCode(slice[i]);
      return s;
    }
  }
  // UTF-16 (1 = BOM, 2 = BE)
  let i = 0;
  let little = encoding === 1 ? true : false;
  if (encoding === 1 && slice.length >= 2) {
    if (slice[0] === 0xff && slice[1] === 0xfe) { little = true; i = 2; }
    else if (slice[0] === 0xfe && slice[1] === 0xff) { little = false; i = 2; }
  }
  let out = '';
  while (i + 1 < slice.length) {
    const code = little ? slice[i] | (slice[i + 1] << 8) : (slice[i] << 8) | slice[i + 1];
    if (code === 0) break;
    out += String.fromCharCode(code);
    i += 2;
  }
  return out;
}

function findNull(encoding: number, bytes: Uint8Array, start: number, end: number): number {
  // returns index of terminator (position of first null unit)
  if (encoding === 0 || encoding === 3) {
    for (let i = start; i < end; i++) if (bytes[i] === 0) return i;
    return end;
  }
  for (let i = start; i + 1 < end; i += 2) {
    if (bytes[i] === 0 && bytes[i + 1] === 0) return i;
  }
  return end;
}

export async function readId3Lyrics(uri: string): Promise<Id3Lyrics | null> {
  try {
    const headerB64 = await FileSystem.readAsStringAsync(uri, { encoding: 'base64', position: 0, length: 10 });
    const header = base64ToBytes(headerB64);
    if (header.length < 10) return null;
    if (header[0] !== 0x49 || header[1] !== 0x44 || header[2] !== 0x33) return null; // "ID3"
    const version = header[3]; // 2,3,4 -> ID3v2.x
    const size = readSynchsafe(header, 6);
    const total = Math.min(size, 2 * 1024 * 1024); // cap 2MB
    if (total <= 0) return null;
    const tagB64 = await FileSystem.readAsStringAsync(uri, { encoding: 'base64', position: 0, length: 10 + total });
    const tag = base64ToBytes(tagB64);
    // Parse frames starting at offset 10
    let offset = 10;
    const end = 10 + total;
    // skip extended header if flag bit 6 set
    const flags = header[5];
    if (flags & 0x40) {
      // extended header size (synchsafe in v2.4, normal in v2.3) - read first 4 bytes
      if (version === 4) {
        const extSize = readSynchsafe(tag, offset);
        offset += extSize;
      } else {
        const extSize = (tag[offset] << 24) | (tag[offset + 1] << 16) | (tag[offset + 2] << 8) | tag[offset + 3];
        offset += extSize;
      }
    }

    let uslt: string | null = null;
    let sylt: { time: number; text: string }[] | null = null;

    while (offset + 8 <= end) {
      // frame header
      if (version === 2) {
        // 3-byte id, 3-byte size
        const id = String.fromCharCode(tag[offset], tag[offset + 1], tag[offset + 2]);
        const frameSize = (tag[offset + 3] << 16) | (tag[offset + 4] << 8) | tag[offset + 5];
        offset += 6;
        if (frameSize === 0) break;
        if (offset + frameSize > end) break;
        const contentStart = offset;
        const contentEnd = offset + frameSize;
        if (id === 'ULT' && uslt === null) {
          const enc = tag[contentStart];
          // language 3 bytes, then descriptor null-terminated
          let i = contentStart + 1 + 3;
          const descEnd = findNull(enc, tag, i, contentEnd);
          i = descEnd + (enc === 0 || enc === 3 ? 1 : 2);
          const text = decodeText(enc, tag, i, contentEnd).replace(/\0+$/, '');
          uslt = text;
        } else if (id === 'SLT' && sylt === null) {
          sylt = parseSylt(version, tag, contentStart, contentEnd);
        }
        offset = contentEnd;
      } else {
        const id = String.fromCharCode(tag[offset], tag[offset + 1], tag[offset + 2], tag[offset + 3]);
        let frameSize: number;
        if (version === 4) {
          frameSize = readSynchsafe(tag, offset + 4);
        } else {
          frameSize = (tag[offset + 4] << 24) | (tag[offset + 5] << 16) | (tag[offset + 6] << 8) | tag[offset + 7];
        }
        offset += 10;
        if (frameSize === 0) break;
        if (offset + frameSize > end) break;
        const contentStart = offset;
        const contentEnd = offset + frameSize;
        if (id === 'USLT' && uslt === null) {
          const enc = tag[contentStart];
          let i = contentStart + 1 + 3; // encoding + language
          const descEnd = findNull(enc, tag, i, contentEnd);
          i = descEnd + (enc === 0 || enc === 3 ? 1 : 2);
          const text = decodeText(enc, tag, i, contentEnd).replace(/\0+$/, '');
          uslt = text;
        } else if (id === 'SYLT' && sylt === null) {
          sylt = parseSylt(version, tag, contentStart, contentEnd);
        }
        offset = contentEnd;
      }
    }

    if (sylt && sylt.length > 0) return { kind: 'sylt', lines: sylt };
    if (uslt && uslt.trim().length > 0) return { kind: 'uslt', text: uslt };
    return null;
  } catch {
    return null;
  }
}

function parseSylt(version: number, tag: Uint8Array, contentStart: number, contentEnd: number): { time: number; text: string }[] {
  const enc = tag[contentStart];
  // language 3 bytes, timestamp format 1, content type 1
  let i = contentStart + 1 + 3 + 1 + 1;
  const descEnd = findNull(enc, tag, i, contentEnd);
  i = descEnd + (enc === 0 || enc === 3 ? 1 : 2);
  const result: { time: number; text: string }[] = [];
  while (i < contentEnd) {
    const textStart = i;
    const textEnd = findNull(enc, tag, i, contentEnd);
    const text = decodeText(enc, tag, textStart, textEnd).replace(/\0+$/, '');
    i = textEnd + (enc === 0 || enc === 3 ? 1 : 2);
    if (i + 4 > contentEnd) break;
    let ts = 0;
    for (let k = 0; k < 4; k++) ts = (ts << 8) | tag[i + k];
    i += 4;
    // timestamp format 1 = ms; convert if needed (assume ms)
    result.push({ time: ts, text });
  }
  return result;
}