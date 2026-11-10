import { makeMutable } from 'react-native-reanimated';

/**
 * Scroll offset of the focused tab. Screens report into it and the floating
 * tab bar reads it, so no React state or JS thread work sits in the scroll path.
 */
export const tabScrollY = makeMutable(0);

export function resetTabScroll() {
  tabScrollY.value = 0;
}
