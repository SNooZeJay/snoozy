import Feather from '@expo/vector-icons/Feather';
import { BlurTargetView } from 'expo-blur';
import { LinearGradient } from 'expo-linear-gradient';
import { Tabs, router, usePathname } from 'expo-router';
import { useEffect, useRef, useState, type ComponentProps, type ComponentRef } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { AppText } from '../../components/AppText';
import { GlassSurface, type GlassBlurTarget } from '../../components/glass/GlassSurface';
import { MiniPlayer } from '../../components/MiniPlayer';
import { collapseProgress } from '../../motion/chrome';
import { resetTabScroll, tabScrollY } from '../../motion/scrollState';
import { layout, motion, useTheme, withAlpha } from '../../theme';

type IconName = ComponentProps<typeof Feather>['name'];

const TABS: {
  name: string;
  path: string;
  icon: IconName;
  label: string;
}[] = [
  { name: 'index', path: '/', icon: 'home', label: 'Home' },
  { name: 'search', path: '/search', icon: 'search', label: 'Search' },
  { name: 'library', path: '/library', icon: 'book-open', label: 'Library' },
  { name: 'playlists', path: '/playlists', icon: 'list', label: 'Playlists' },
  { name: 'settings', path: '/settings', icon: 'settings', label: 'Settings' },
];

const TAB_COUNT = TABS.length;
const PILL_WIDTH = 56;
const PILL_HEIGHT = 50;

/**
 * Cupertino Liquid Glass floating tab bar:
 * - Translucent frosted glass surface with 0.5pt specular border
 * - Spring-animated glass selection capsule
 * - SF-style icon + micro caption hierarchy with quick opacity compression
 */
function FloatingPillBar({ blurTarget }: { blurTarget: GlassBlurTarget }) {
  const pathname = usePathname();
  const insets = useSafeAreaInsets();
  const { palette, glass, reducedMotion } = useTheme();
  const activeIndex = Math.max(
    TABS.findIndex((tab) => tab.path === pathname),
    0,
  );
  const [barWidth, setBarWidth] = useState(0);
  const unit = useSharedValue(0);
  const position = useSharedValue(activeIndex);

  useEffect(() => {
    unit.value = barWidth > 0 ? barWidth / TAB_COUNT : 0;
  }, [barWidth, unit]);

  useEffect(() => {
    position.value = reducedMotion
      ? withTiming(activeIndex, { duration: 0 })
      : withSpring(activeIndex, motion.springs.standard);
  }, [activeIndex, position, reducedMotion]);

  useEffect(() => {
    resetTabScroll();
  }, [pathname]);

  const barStyle = useAnimatedStyle(() => ({
    height: layout.tabBarHeight - 10 * collapseProgress(tabScrollY.value),
  }));

  const labelStyle = useAnimatedStyle(() => {
    const progress = collapseProgress(tabScrollY.value);
    return {
      opacity: 1 - progress,
      height: 12 * (1 - progress),
      transform: [{ translateY: -1.5 * progress }],
    };
  });

  const pillStyle = useAnimatedStyle(() => {
    const progress = collapseProgress(tabScrollY.value);
    return {
      top: (layout.tabBarHeight - 10 * progress - PILL_HEIGHT) / 2,
      transform: [
        {
          translateX:
            position.value * unit.value + Math.max((unit.value - PILL_WIDTH) / 2, 0),
        },
      ],
    };
  });

  return (
    <View
      style={[styles.shell, { bottom: insets.bottom + layout.tabBarInset }]}
      pointerEvents="box-none"
      onLayout={(event) => setBarWidth(event.nativeEvent.layout.width)}
    >
      <Animated.View style={[styles.barShell, barStyle]}>
        <GlassSurface
          variant="pill"
          blurTarget={blurTarget}
          blurIntensity={58}
          style={[styles.bar, { borderColor: glass.edgeStrong }]}
        >
        <Animated.View
          style={[
            styles.pill,
            {
              backgroundColor: withAlpha(palette.accent, 0.16),
              borderColor: withAlpha(palette.accent, 0.28),
            },
            pillStyle,
          ]}
        >
          <LinearGradient
            pointerEvents="none"
            colors={['rgba(255,255,255,0.20)', 'rgba(255,255,255,0.02)']}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={[StyleSheet.absoluteFill, { borderRadius: PILL_HEIGHT / 2 }]}
          />
        </Animated.View>
        {TABS.map((tab, index) => {
          const focused = index === activeIndex;
          return (
            <Pressable
              key={tab.name}
              accessibilityRole="tab"
              accessibilityLabel={tab.label}
              accessibilityState={{ selected: focused }}
              onPress={() => {
                if (focused) return;
                router.navigate(tab.path as Parameters<typeof router.navigate>[0]);
              }}
              style={({ pressed }) => [
                styles.tab,
                pressed && { opacity: 0.56 },
              ]}
            >
              <Feather
                name={tab.icon}
                size={24}
                color={focused ? palette.accent : palette.inkMuted}
              />
              <Animated.View style={[styles.tabLabelWrap, labelStyle]}>
                <AppText
                  variant="micro"
                  color={focused ? palette.accent : palette.inkMuted}
                  style={styles.tabLabel}
                >
                  {tab.label}
                </AppText>
              </Animated.View>
            </Pressable>
          );
        })}
        </GlassSurface>
      </Animated.View>
    </View>
  );
}

export default function TabsLayout() {
  const { palette, reducedMotion } = useTheme();
  const blurTarget = useRef<ComponentRef<typeof View> | null>(null);

  return (
    <View style={[styles.root, { backgroundColor: palette.background }]}>
      <BlurTargetView ref={blurTarget} style={styles.scene}>
        <Tabs
          screenOptions={{
            headerShown: false,
            tabBarStyle: { display: 'none' },
            // Scenes cross-fade; the pill bar and mini player stay put above them.
            animation: reducedMotion ? 'none' : 'fade',
            lazy: false,
            sceneStyle: { backgroundColor: palette.background },
          }}
        >
          <Tabs.Screen name="index" options={{ title: 'Home' }} />
          <Tabs.Screen name="search" options={{ title: 'Search' }} />
          <Tabs.Screen name="library" options={{ title: 'Library' }} />
          <Tabs.Screen name="playlists" options={{ title: 'Playlists' }} />
          <Tabs.Screen name="settings" options={{ title: 'Settings' }} />
        </Tabs>
      </BlurTargetView>
      <MiniPlayer blurTarget={blurTarget} />
      <FloatingPillBar blurTarget={blurTarget} />
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  scene: { flex: 1 },
  shell: {
    position: 'absolute',
    left: layout.screenPadding,
    right: layout.screenPadding,
    zIndex: 20,
    elevation: 32,
  },
  barShell: {
    height: layout.tabBarHeight,
    borderRadius: layout.tabBarHeight / 2,
  },
  bar: {
    flex: 1,
    borderRadius: 999,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    alignItems: 'center',
  },
  pill: {
    position: 'absolute',
    width: PILL_WIDTH,
    height: PILL_HEIGHT,
    borderRadius: PILL_HEIGHT / 2,
    borderWidth: StyleSheet.hairlineWidth,
    overflow: 'hidden',
  },
  tab: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 48,
    gap: 2,
  },
  tabLabelWrap: {
    overflow: 'hidden',
    justifyContent: 'flex-start',
  },
  tabLabel: {
    fontSize: 10,
    lineHeight: 12,
  },
});
