import Ionicons from '@expo/vector-icons/Ionicons';
import { LinearGradient } from 'expo-linear-gradient';
import { Tabs, router, usePathname } from 'expo-router';
import { useEffect, useState, type ComponentProps } from 'react';
import { Easing, Pressable, StyleSheet, View } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { GlassSurface } from '../../components/glass/GlassSurface';
import { colors, layout, motion, useTheme } from '../../theme';

type IconName = ComponentProps<typeof Ionicons>['name'];

const TABS: { name: string; path: string; icon: IconName; label: string }[] = [
  { name: 'index', path: '/', icon: 'home', label: 'Home' },
  { name: 'search', path: '/search', icon: 'search', label: 'Search' },
  { name: 'library', path: '/library', icon: 'library', label: 'Library' },
  { name: 'settings', path: '/settings', icon: 'settings', label: 'Settings' },
];

const TAB_COUNT = TABS.length;
const PILL_WIDTH = 52;
const PILL_HEIGHT = 46;

/**
 * Floating pill bar: four icon-only tabs. The active tab sits in a mint
 * rounded-square that slides between slots on the v1.2 spring. Reduced motion
 * snaps instead of springing.
 */
function FloatingPillBar() {
  const pathname = usePathname();
  const insets = useSafeAreaInsets();
  const { reducedMotion } = useTheme();
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

  const pillStyle = useAnimatedStyle(() => ({
    transform: [
      {
        translateX:
          position.value * unit.value + Math.max((unit.value - PILL_WIDTH) / 2, 0),
      },
    ],
  }));

  return (
    <View
      style={[styles.shell, { bottom: insets.bottom + layout.tabBarInset }]}
      pointerEvents="box-none"
      onLayout={(event) => setBarWidth(event.nativeEvent.layout.width)}
    >
      <GlassSurface variant="pill" style={styles.bar}>
        <Animated.View style={[styles.pill, pillStyle]}>
          <LinearGradient
            pointerEvents="none"
            colors={['rgba(255,255,255,0.22)', 'rgba(255,255,255,0.02)']}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={[StyleSheet.absoluteFill, { borderRadius: 17 }]}
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
              style={styles.tab}
            >
              <Ionicons
                name={tab.icon}
                size={24}
                color={focused ? colors.accentInk : colors.inkMuted}
              />
            </Pressable>
          );
        })}
      </GlassSurface>
    </View>
  );
}

export default function TabsLayout() {
  const { reducedMotion } = useTheme();

  return (
    <View style={styles.root}>
      <Tabs
        screenOptions={{
          headerShown: false,
          tabBarStyle: { display: 'none' },
          animation: reducedMotion ? 'none' : 'fade',
          transitionSpec: reducedMotion
            ? { animation: 'timing', config: { duration: 0 } }
            : {
                animation: 'timing',
                config: {
                  duration: motion.durations.screen,
                  easing: Easing.out(Easing.cubic),
                },
              },
        }}
      >
        <Tabs.Screen name="index" options={{ title: 'Home' }} />
        <Tabs.Screen name="search" options={{ title: 'Search' }} />
        <Tabs.Screen name="library" options={{ title: 'Library' }} />
        <Tabs.Screen name="settings" options={{ title: 'Settings' }} />
      </Tabs>
      <FloatingPillBar />
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.background },
  shell: {
    position: 'absolute',
    left: layout.screenPadding,
    right: layout.screenPadding,
    zIndex: 20,
    elevation: 32,
  },
  bar: {
    height: layout.tabBarHeight,
    borderRadius: layout.tabBarHeight / 2,
    flexDirection: 'row',
    alignItems: 'center',
    borderColor: 'rgba(232, 242, 224, 0.20)',
  },
  pill: {
    position: 'absolute',
    width: PILL_WIDTH,
    height: PILL_HEIGHT,
    top: (layout.tabBarHeight - PILL_HEIGHT) / 2,
    borderRadius: 17,
    backgroundColor: colors.accent,
    overflow: 'hidden',
  },
  tab: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 48,
  },
});
