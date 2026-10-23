import { LinearGradient } from 'expo-linear-gradient';
import { Component } from 'react';
import { Animated, StyleSheet, View } from 'react-native';

import { motion } from '../theme';

type PaletteGlowProps = {
  color: string;
  intensity: number;
  background: string;
  reducedMotion?: boolean;
};

type PaletteGlowState = {
  current: string;
  previous: string | null;
};

/**
 * Crossfades the artwork-derived glow instead of snapping the whole player
 * background to a new hue. Only opacity is animated, so the native driver can
 * run it without touching layout.
 */
export class PaletteGlow extends Component<PaletteGlowProps, PaletteGlowState> {
  private fade = new Animated.Value(1);
  private mounted = true;

  state: PaletteGlowState = {
    current: this.props.color,
    previous: null,
  };

  componentDidUpdate(prevProps: PaletteGlowProps) {
    if (prevProps.color === this.props.color) return;
    this.setState(
      {
        current: this.props.color,
        previous: this.state.current,
      },
      () => {
        this.fade.stopAnimation();
        this.fade.setValue(0);
        Animated.timing(this.fade, {
          toValue: 1,
          duration: this.props.reducedMotion ? 0 : motion.durations.long,
          useNativeDriver: true,
        }).start(({ finished }) => {
          if (finished && this.mounted) {
            this.setState({ previous: null });
          }
        });
      },
    );
  }

  componentWillUnmount() {
    this.mounted = false;
  }

  render() {
    const { background, intensity } = this.props;
    const { current, previous } = this.state;
    const layerStyle = [StyleSheet.absoluteFill, { opacity: intensity }];

    return (
      <View pointerEvents="none" style={StyleSheet.absoluteFill}>
        {previous ? (
          <LinearGradient
            colors={[previous, background, background]}
            locations={[0, 0.45, 1]}
            style={layerStyle}
          />
        ) : null}
        <Animated.View
          pointerEvents="none"
          style={[StyleSheet.absoluteFill, { opacity: this.fade }]}
        >
          <LinearGradient
            colors={[current, background, background]}
            locations={[0, 0.45, 1]}
            style={layerStyle}
          />
        </Animated.View>
      </View>
    );
  }
}
