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
 * Pressable with a short native-driver scale. Kept as a class so the
 * imperative Animated value stays outside the React Compiler's hook rules.
 */
export class ScalePressable extends Component<ScalePressableProps> {
  private scale = new Animated.Value(1);

  private handlePressIn = (event: GestureResponderEvent) => {
    const { disabled, reducedMotion, scaleTo = 0.96 } = this.props;
    if (!disabled && !reducedMotion) {
      Animated.timing(this.scale, {
        toValue: scaleTo,
        duration: motion.durations.short,
        easing: Easing.out(Easing.quad),
        useNativeDriver: true,
      }).start();
    }
    this.props.onPressIn?.(event);
  };

  private handlePressOut = (event: GestureResponderEvent) => {
    const { reducedMotion } = this.props;
    if (!reducedMotion) {
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
        style={[style, { transform: [{ scale: this.scale }] }]}
      >
        {children}
      </AnimatedPressable>
    );
  }
}
