import type { ReactNode } from 'react';
import {
  StyleSheet,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

import { radii, spacing } from '../theme';
import { GlassSurface } from './glass/GlassSurface';

type ListGroupProps = {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
};

/**
 * A single clipped glass container for a related run of rows. Keeping the
 * radius and padding here prevents each screen from inventing its own card.
 */
export function ListGroup({ children, style }: ListGroupProps) {
  return (
    <GlassSurface variant="card" radius={radii.lg} style={[styles.group, style]}>
      {children}
    </GlassSurface>
  );
}

const styles = StyleSheet.create({
  group: {
    marginHorizontal: spacing.screen,
    padding: spacing.xs,
    overflow: 'hidden',
  },
});
