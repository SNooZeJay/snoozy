import { collapseProgress, shouldDismissSheet } from '../src/motion/chrome';

describe('collapseProgress', () => {
  it('stays expanded above the start offset', () => {
    expect(collapseProgress(0)).toBe(0);
    expect(collapseProgress(8)).toBe(0);
    expect(collapseProgress(-40)).toBe(0);
  });

  it('reaches compact at the end offset', () => {
    expect(collapseProgress(52)).toBe(1);
    expect(collapseProgress(400)).toBe(1);
  });

  it('is linear between the thresholds', () => {
    expect(collapseProgress(30)).toBeCloseTo(0.5, 5);
  });

  it('treats a non-finite offset as expanded', () => {
    expect(collapseProgress(Number.NaN)).toBe(0);
  });
});

describe('shouldDismissSheet', () => {
  it('dismisses after a long drag', () => {
    expect(shouldDismissSheet(120, 0)).toBe(true);
  });

  it('dismisses on a fast flick even when short', () => {
    expect(shouldDismissSheet(40, 950)).toBe(true);
  });

  it('keeps the sheet for a small slow drag', () => {
    expect(shouldDismissSheet(40, 200)).toBe(false);
  });
});
