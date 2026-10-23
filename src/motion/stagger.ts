import { FadeIn, FadeInDown } from 'react-native-reanimated';

import { motion } from '../theme/tokens';

/**
 * Capped list entrance. Only the first `maxItems` rows get a delay, so a long
 * library never turns into a multi-second wave. Reduced motion keeps a short
 * fade with no stagger and no slide.
 */
export function staggerEnter(index: number, reducedMotion: boolean) {
  if (reducedMotion) {
    return FadeIn.duration(motion.durations.short);
  }
  const delay =
    Math.min(Math.max(index, 0), motion.stagger.maxItems) * motion.stagger.step;
  return FadeInDown.duration(motion.durations.long).delay(delay);
}
