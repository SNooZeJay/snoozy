import { FadeIn, FadeInDown } from 'react-native-reanimated';

import { motion } from '../theme/tokens';

/**
 * Capped list entrance. Only the first `maxItems` rows animate at all, so a
 * library of thousands never mounts an animation per row. Reduced motion keeps
 * a short fade with no stagger and no slide.
 */
export function staggerEnter(index: number, reducedMotion: boolean) {
  if (index > motion.stagger.maxItems) {
    return undefined;
  }
  if (reducedMotion) {
    return FadeIn.duration(motion.durations.short);
  }
  const delay =
    Math.min(Math.max(index, 0), motion.stagger.maxItems) * motion.stagger.step;
  return FadeInDown.duration(motion.durations.long).delay(delay);
}
