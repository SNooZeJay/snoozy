import * as FileSystem from 'expo-file-system/legacy';

import { parseLrc, type LyricLine } from './lrc';
import { readId3Lyrics } from './id3';

export type LyricsSource = 'lrc' | 'uslt' | 'sylt' | 'none';

export type LyricsResult = {
  source: LyricsSource;
  sourceLabel: string;
  synced: boolean;
  lines: LyricLine[];
};

export function sidecarLrcUri(audioUri: string): string | null {
  if (!audioUri.startsWith('file://')) return null;
  const idx = audioUri.lastIndexOf('.');
  const base = idx > 0 ? audioUri.slice(0, idx) : audioUri;
  return `${base}.lrc`;
}

export async function resolveLyrics(audioUri: string): Promise<LyricsResult> {
  // Step 1: sidecar .lrc
  const lrcUri = sidecarLrcUri(audioUri);
  if (lrcUri) {
    try {
      const info = await FileSystem.getInfoAsync(lrcUri);
      if (info.exists) {
        const content = await FileSystem.readAsStringAsync(lrcUri, { encoding: 'utf8' });
        const parsed = parseLrc(content);
        return {
          source: 'lrc',
          sourceLabel: 'Source: .lrc file',
          synced: parsed.synced,
          lines: parsed.lines,
        };
      }
    } catch {
      // fall through
    }
  }

  // Step 2: ID3 tags (MP3 only, best effort)
  if (audioUri.toLowerCase().includes('.mp3')) {
    try {
      const id3 = await readId3Lyrics(audioUri);
      if (id3) {
        if (id3.kind === 'uslt') {
          const lines: LyricLine[] = id3.text.split(/\r?\n/).map((t) => ({ time: null, text: t }));
          return { source: 'uslt', sourceLabel: 'Source: embedded tags', synced: false, lines };
        }
        if (id3.kind === 'sylt') {
          const lines: LyricLine[] = id3.lines.map((l) => ({ time: l.time, text: l.text }));
          return { source: 'sylt', sourceLabel: 'Source: embedded tags', synced: true, lines };
        }
      }
    } catch {
      // fall through
    }
  }

  return { source: 'none', sourceLabel: 'Source: none', synced: false, lines: [] };
}