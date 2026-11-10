import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, StyleSheet, View } from 'react-native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useFonts } from 'expo-font';
import * as SplashScreen from 'expo-splash-screen';
import * as SystemUI from 'expo-system-ui';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { BricolageGrotesque_500Medium } from '@expo-google-fonts/bricolage-grotesque/500Medium';
import { BricolageGrotesque_600SemiBold } from '@expo-google-fonts/bricolage-grotesque/600SemiBold';
import { AtkinsonHyperlegible_400Regular } from '@expo-google-fonts/atkinson-hyperlegible/400Regular';
import { AtkinsonHyperlegible_700Bold } from '@expo-google-fonts/atkinson-hyperlegible/700Bold';

import { SplashIntro } from '../components/SplashIntro';
import { FavoritesProvider } from '../storage/FavoritesContext';
import { MusicLibraryProvider } from '../storage/MusicLibraryContext';
import { PlayerProvider } from '../playback/PlayerContext';
import { PreferencesProvider } from '../storage/PreferencesContext';
import { ThemeProvider, colors, useTheme } from '../theme';

void SplashScreen.preventAutoHideAsync().catch(() => undefined);
SplashScreen.setOptions({ duration: 450, fade: true });

function AppStack() {
  const { reducedMotion, palette } = useTheme();

  return (
    <Stack
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: palette.background },
        animation: reducedMotion ? 'fade' : 'slide_from_right',
      }}
    >
      <Stack.Screen name="(tabs)" options={{ animation: 'none' }} />
      <Stack.Screen
        name="player"
        options={{
          presentation: 'modal',
          animation: reducedMotion ? 'fade' : 'slide_from_bottom',
          contentStyle: { backgroundColor: palette.backgroundDeep },
        }}
      />
    </Stack>
  );
}

function ThemedShell({
  introVisible,
  onIntroDone,
}: {
  introVisible: boolean;
  onIntroDone: () => void;
}) {
  const { palette, dark } = useTheme();

  useEffect(() => {
    void SystemUI.setBackgroundColorAsync(palette.background).catch(() => undefined);
  }, [palette.background]);

  return (
    <PreferencesProvider>
      <FavoritesProvider>
        <MusicLibraryProvider>
          <PlayerProvider>
            <AppStack />
            {introVisible ? <SplashIntro onDone={onIntroDone} /> : null}
            <StatusBar style={dark ? 'light' : 'dark'} />
          </PlayerProvider>
        </MusicLibraryProvider>
      </FavoritesProvider>
    </PreferencesProvider>
  );
}

export default function RootLayout() {
  const [fontsLoaded, fontError] = useFonts({
    BricolageGrotesque_500Medium,
    BricolageGrotesque_600SemiBold,
    AtkinsonHyperlegible_400Regular,
    AtkinsonHyperlegible_700Bold,
  });
  const [introVisible, setIntroVisible] = useState(true);
  const hideIntro = useCallback(() => setIntroVisible(false), []);

  useEffect(() => {
    if (!fontsLoaded && !fontError) return;
    void SplashScreen.hideAsync().catch(() => undefined);
  }, [fontError, fontsLoaded]);

  if (!fontsLoaded && !fontError) {
    return (
      <View style={styles.boot}>
        <View style={styles.bootMark}>
          <ActivityIndicator color={colors.accent} size="small" />
        </View>
      </View>
    );
  }

  return (
    <GestureHandlerRootView style={styles.root}>
      <SafeAreaProvider>
        <ThemeProvider>
          <ThemedShell introVisible={introVisible} onIntroDone={hideIntro} />
        </ThemeProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  boot: {
    flex: 1,
    backgroundColor: colors.background,
    alignItems: 'center',
    justifyContent: 'center',
  },
  bootMark: {
    width: 52,
    height: 52,
    borderRadius: 26,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surfaceRaised,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.border,
  },
});
