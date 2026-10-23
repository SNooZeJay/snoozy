import Feather from '@expo/vector-icons/Feather';
import { Component, type ComponentProps, type ReactNode } from 'react';
import {
  Animated,
  PanResponder,
  Pressable,
  StyleSheet,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

import { colors, glass, motion, radii, spacing } from '../theme';
import { AppText } from './AppText';

type FeatherName = ComponentProps<typeof Feather>['name'];

export type SwipeAction = {
  key: string;
  label: string;
  icon: FeatherName;
  iconColor?: string;
  backgroundColor?: string;
  onPress: () => void;
};

const ACTION_WIDTH = 76;

type SwipeableRowProps = {
  actions: SwipeAction[];
  children: ReactNode;
  enabled?: boolean;
  radius?: number;
  style?: StyleProp<ViewStyle>;
};

/**
 * Left-swipe action rail for existing list rows. The gesture is horizontal
 * only, so vertical scrolling keeps priority. A row's existing menu remains
 * the accessible fallback; this is an accelerator, not the only path.
 *
 * Kept as a class component so the imperative PanResponder/Animated pair sits
 * outside the React Compiler's hook immutability rules. The transform runs on
 * the native driver; only the drag itself is JS-driven.
 */
export class SwipeableRow extends Component<SwipeableRowProps> {
  private translateX = new Animated.Value(0);
  private startX = 0;
  private open = false;

  private panResponder = PanResponder.create({
    onMoveShouldSetPanResponder: (_, gesture) =>
      this.props.enabled !== false &&
      Math.abs(gesture.dx) > 10 &&
      Math.abs(gesture.dx) > Math.abs(gesture.dy) * 1.5,
    onPanResponderGrant: () => {
      this.startX = this.open ? -ACTION_WIDTH * this.props.actions.length : 0;
      this.translateX.setValue(this.startX);
    },
    onPanResponderMove: (_, gesture) => {
      const max = ACTION_WIDTH * this.props.actions.length;
      this.translateX.setValue(
        Math.max(-max, Math.min(0, this.startX + gesture.dx)),
      );
    },
    onPanResponderRelease: (_, gesture) => {
      const max = ACTION_WIDTH * this.props.actions.length;
      const position = this.startX + gesture.dx;
      this.settle(position < -max / 2 || gesture.vx < -0.45);
    },
    onPanResponderTerminate: () => this.settle(false),
    onPanResponderTerminationRequest: () => true,
  });

  componentDidUpdate(prevProps: SwipeableRowProps) {
    if (
      this.open &&
      prevProps.actions.length !== this.props.actions.length
    ) {
      this.settle(false);
    }
  }

  private settle = (shouldOpen: boolean) => {
    this.open = shouldOpen;
    Animated.timing(this.translateX, {
      toValue: shouldOpen ? -ACTION_WIDTH * this.props.actions.length : 0,
      duration: motion.durations.medium,
      useNativeDriver: true,
    }).start();
  };

  render() {
    const {
      actions,
      children,
      radius = radii.lg,
      style,
    } = this.props;

    return (
      <View style={[styles.wrap, { borderRadius: radius }, style]}>
        <View style={[styles.actions, { width: ACTION_WIDTH * actions.length }]}>
          {actions.map((action) => (
            <Pressable
              key={action.key}
              accessibilityRole="button"
              accessibilityLabel={action.label}
              onPress={() => {
                this.settle(false);
                action.onPress();
              }}
              style={({ pressed }) => [
                styles.action,
                {
                  backgroundColor: action.backgroundColor ?? glass.tintSoft,
                  opacity: pressed ? 0.7 : 1,
                },
              ]}
            >
              <Feather
                name={action.icon}
                size={20}
                color={action.iconColor ?? colors.ink}
              />
              <AppText
                variant="micro"
                color={action.iconColor ?? colors.ink}
                numberOfLines={1}
              >
                {action.label}
              </AppText>
            </Pressable>
          ))}
        </View>
        <Animated.View
          {...this.panResponder.panHandlers}
          style={{ transform: [{ translateX: this.translateX }] }}
        >
          {children}
        </Animated.View>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  wrap: {
    overflow: 'hidden',
  },
  actions: {
    position: 'absolute',
    top: 0,
    right: 0,
    bottom: 0,
    flexDirection: 'row',
    justifyContent: 'flex-end',
    backgroundColor: glass.tintDeep,
  },
  action: {
    width: ACTION_WIDTH,
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.xxs,
    paddingHorizontal: spacing.xs,
  },
});
