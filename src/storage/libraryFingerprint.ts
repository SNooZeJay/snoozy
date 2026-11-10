export function libraryFingerprint(
  totalCount: number,
  latestModificationTime: number,
): string {
  return `${totalCount}:${latestModificationTime}`;
}
