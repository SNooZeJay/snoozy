export type LyricLine = { time: number | null; text: string };

export type LrcResult = {
  lines: LyricLine[];
  synced: boolean;
};

export function parseLrc(content: string): LrcResult {
  const lines: LyricLine[] = [];
  let synced = false;
  const timeTag = /\[(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?\]/g;
  for (const raw of content.split(/\r?\n/)) {
    const trimmed = raw.trimEnd();
    if (trimmed === '') {
      lines.push({ time: null, text: '' });
      continue;
    }
    const tags: number[] = [];
    let text = trimmed;
    timeTag.lastIndex = 0;
    const matches = [...trimmed.matchAll(timeTag)];
    for (const mm of matches) {
      const min = parseInt(mm[1], 10);
      const sec = parseInt(mm[2], 10);
      const frac = mm[3] ? parseInt(mm[3].padEnd(3, '0'), 10) : 0;
      tags.push(min * 60000 + sec * 1000 + frac);
      text = text.replace(mm[0], '');
    }
    text = text.trim();
    if (tags.length === 0) {
      // Bracketed ID tags without timestamps ([ti:], [ar:], [al:], [by:], …) are
      // LRC metadata, not lyrics — drop them instead of rendering as text.
      if (/^(?:\[[^\]\d:]+:[^\]]*\])+$/.test(trimmed)) continue;
      lines.push({ time: null, text });
    } else {
      synced = true;
      for (const t of tags) lines.push({ time: t, text });
    }
  }
  return { lines, synced: synced && lines.some((l) => l.time !== null) };
}