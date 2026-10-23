import { Component } from 'react';
import {
  Animated as RNAnimated,
  Image,
  StyleSheet,
  View,
  type ImageStyle,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import Animated from 'react-native-reanimated';

import { motion } from '../theme';
import { AppText } from './AppText';

type CrossfadeArtworkProps = {
  uri?: string | null;
  fallbackText: string;
  fallbackColor: string;
  fallbackInk: string;
  fallbackSize?: number;
  style?: StyleProp<ViewStyle>;
  imageStyle?: StyleProp<ImageStyle>;
  sharedTransitionTag?: string;
  reducedMotion?: boolean;
};

type CrossfadeArtworkState = {
  current: string | null;
  previous: string | null;
};

/**
 * Keeps the outgoing cover underneath while the incoming cover fades in.
 * The wrapper carries Reanimated's shared-transition tag so the mini-player
 * and full player continue to share one artwork element.
 */
export class CrossfadeArtwork extends Component<
  CrossfadeArtworkProps,
  CrossfadeArtworkState
> {
  private fade = new RNAnimated.Value(1);
  private mounted = true;

  state: CrossfadeArtworkState = {
    current: this.props.uri || null,
    previous: null,
  };

  componentDidUpdate(prevProps: CrossfadeArtworkProps) {
    const next = this.props.uri || null;
    if (prevProps.uri === this.props.uri || next === this.state.current) return;

    this.setState(
      {
        current: next,
        previous: this.state.current,
      },
      () => {
        this.fade.stopAnimation();
        this.fade.setValue(0);
        RNAnimated.timing(this.fade, {
          toValue: 1,
          duration: this.props.reducedMotion ? 0 : motion.durations.medium,
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

  private renderArt(uri: string | null) {
    if (uri) {
      return (
        <Image
          source={{ uri }}
          style={[StyleSheet.absoluteFill, this.props.imageStyle]}
          resizeMode="cover"
          accessibilityIgnoresInvertColors
        />
      );
    }

    return (
      <View
        style={[
          StyleSheet.absoluteFill,
          styles.fallback,
          { backgroundColor: this.props.fallbackColor },
        ]}
      >
        <AppText
          variant="title"
          color={this.props.fallbackInk}
          style={{
            fontSize: this.props.fallbackSize ?? 22,
            lineHeight: (this.props.fallbackSize ?? 22) * 1.1,
          }}
        >
          {this.props.fallbackText}
        </AppText>
      </View>
    );
  }

  render() {
    return (
      <Animated.View
        sharedTransitionTag={this.props.sharedTransitionTag}
        style={[styles.root, this.props.style]}
        accessible={false}
      >
        {this.state.previous ? this.renderArt(this.state.previous) : null}
        <RNAnimated.View
          style={[StyleSheet.absoluteFill, { opacity: this.fade }]}
        >
          {this.renderArt(this.state.current)}
        </RNAnimated.View>
      </Animated.View>
    );
  }
}

const styles = StyleSheet.create({
  root: {
    overflow: 'hidden',
  },
  fallback: {
    alignItems: 'center',
    justifyContent: 'center',
  },
});
