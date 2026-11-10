import { Component, type ReactNode } from 'react';
import {
  Animated,
  Easing,
  Pressable,
  type GestureResponderEvent,
  type PressableProps,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

import { motion } from '../theme';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

type ScalePressableProps = Omit<PressableProps, 'children' | 'style'> & {
  children?: ReactNode;
  style?: StyleProp<ViewStyle>;
  scaleTo?: number;
  reducedMotion?: boolean;
};

/**
 * Cupertino pressable with quick opacity + scale compression and no Android
 * ripple. Kept as a class so the imperative Animated values stay outside the
 * React Compiler's hook rules.
 */
export class ScalePressable extends Component<ScalePressableProps> {
  private scale = new Animated.Value(1);
  private opacity = new Animated.Value(1);

  private handlePressIn = (event: GestureResponderEvent) => {
    const { disabled, reducedMotion, scaleTo = 0.96 } = this.props;
    if (!disabled) {
      Animated.timing(this.opacity, {
        toValue: 0.68,
        duration: 85,
        easing: Easing.out(Easing.quad),
        useNativeDriver: true,
      }).start();
      if (!reducedMotion) {
        Animated.timing(this.scale, {
          toValue: scaleTo,
          duration: motion.durations.short,
          easing: Easing.out(Easing.quad),
          useNativeDriver: true,
        }).start();
      }
    }
    this.props.onPressIn?.(event);
  };

  private handlePressOut = (event: GestureResponderEvent) => {
    Animated.timing(this.opacity, {
      toValue: 1,
      duration: 140,
      easing: Easing.out(Easing.quad),
      useNativeDriver: true,
    }).start();
    if (!this.props.reducedMotion) {
      Animated.spring(this.scale, {
        toValue: 1,
        useNativeDriver: true,
        ...motion.springs.snappy,
      }).start();
    }
    this.props.onPressOut?.(event);
  };

  componentWillUnmount() {
    this.scale.stopAnimation();
    this.opacity.stopAnimation();
  }

  render() {
    const {
      children,
      reducedMotion: _reducedMotion,
      scaleTo: _scaleTo,
      style,
      ...rest
    } = this.props;

    return (
      <AnimatedPressable
        {...rest}
        onPressIn={this.handlePressIn}
        onPressOut={this.handlePressOut}
        style={[
          style,
          {
            opacity: this.opacity,
            transform: [{ scale: this.scale }],
          },
        ]}
      >
        {children}
      </AnimatedPressable>
    );
  }
}
