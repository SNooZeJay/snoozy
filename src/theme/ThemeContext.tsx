import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { AccessibilityInfo, useColorScheme } from 'react-native';
import { createMMKV } from 'react-native-mmkv';

import { generateColorTokens, type ColorTokens, type PaletteStyle, type ThemeMode } from './color';
import { DEFAULT_SEED } from './color';

type MotionMode = 'system' | 'reduced' | 'full';

type ThemeContextValue = {
  mode: ThemeMode;
  setMode: (mode: ThemeMode) => void;
  paletteStyle: PaletteStyle;
  setPaletteStyle: (style: PaletteStyle) => void;
  seed: string;
  setSeed: (seed: string) => void;
  dark: boolean;
  tokens: ColorTokens;
  backdropEnabled: boolean;
  setBackdropEnabled: (value: boolean) => void;
  backdropIntensity: number;
  setBackdropIntensity: (value: number) => void;
  motionMode: MotionMode;
  setMotionMode: (mode: MotionMode) => void;
  reducedMotion: boolean;
  systemReduceMotion: boolean;
};

const ThemeContext = createContext<ThemeContextValue | null>(null);

const store = createMMKV({ id: 'snoozy.theme.v1' });
const KEYS = {
  mode: 'mode',
  paletteStyle: 'paletteStyle',
  seed: 'seed',
  backdropEnabled: 'backdropEnabled',
  backdropIntensity: 'backdropIntensity',
  motionMode: 'motionMode',
} as const;

export const PRESET_SWATCHES = ['#B8F0B0', '#F2B8E6', '#B8D4F2', '#F2D4B8', '#D4B8F2'] as const;


function readMode(): ThemeMode {
  const v = store.getString(KEYS.mode);
  return v === 'light' || v === 'dark' || v === 'auto' ? v : 'dark';
}
function readStyle(): PaletteStyle {
  const v = store.getString(KEYS.paletteStyle);
  const allowed: PaletteStyle[] = ['classic', 'tonal-spot', 'expressive', 'vibrant', 'neutral'];
  return allowed.includes(v as PaletteStyle) ? (v as PaletteStyle) : 'tonal-spot';
}
function readSeed(): string {
  return store.getString(KEYS.seed) ?? DEFAULT_SEED;
}
function readBackdropEnabled(): boolean {
  const v = store.getBoolean(KEYS.backdropEnabled);
  return v === undefined ? true : v;
}
function readBackdropIntensity(): number {
  const v = store.getNumber(KEYS.backdropIntensity);
  return typeof v === 'number' ? v : 60;
}
function readMotionMode(): MotionMode {
  const v = store.getString(KEYS.motionMode);
  return v === 'system' || v === 'reduced' || v === 'full' ? v : 'system';
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const systemScheme = useColorScheme();
  const [mode, setModeState] = useState<ThemeMode>(readMode);
  const [paletteStyle, setPaletteStyleState] = useState<PaletteStyle>(readStyle);
  const [seed, setSeedState] = useState<string>(readSeed);
  const [backdropEnabled, setBackdropEnabledState] = useState<boolean>(readBackdropEnabled);
  const [backdropIntensity, setBackdropIntensityState] = useState<number>(readBackdropIntensity);
  const [motionMode, setMotionModeState] = useState<MotionMode>(readMotionMode);
  const [systemReduceMotion, setSystemReduceMotion] = useState(false);

  useEffect(() => {
    AccessibilityInfo.isReduceMotionEnabled().then(setSystemReduceMotion).catch(() => undefined);
    const sub = AccessibilityInfo.addEventListener('reduceMotionChanged', setSystemReduceMotion);
    return () => sub.remove();
  }, []);

  const dark =
    mode === 'dark' || (mode === 'auto' && systemScheme === 'dark');

  const tokens = useMemo(() => generateColorTokens(seed, paletteStyle, dark), [seed, paletteStyle, dark]);

  const reducedMotion =
    motionMode === 'reduced' || (motionMode === 'system' && systemReduceMotion);

  const setMode = useCallback((m: ThemeMode) => {
    setModeState(m);
    store.set(KEYS.mode, m);
  }, []);
  const setPaletteStyle = useCallback((s: PaletteStyle) => {
    setPaletteStyleState(s);
    store.set(KEYS.paletteStyle, s);
  }, []);
  const setSeed = useCallback((s: string) => {
    setSeedState(s);
    store.set(KEYS.seed, s);
  }, []);
  const setBackdropEnabled = useCallback((v: boolean) => {
    setBackdropEnabledState(v);
    store.set(KEYS.backdropEnabled, v);
  }, []);
  const setBackdropIntensity = useCallback((v: number) => {
    setBackdropIntensityState(v);
    store.set(KEYS.backdropIntensity, v);
  }, []);
  const setMotionMode = useCallback((m: MotionMode) => {
    setMotionModeState(m);
    store.set(KEYS.motionMode, m);
  }, []);

  const value = useMemo<ThemeContextValue>(
    () => ({
      mode,
      setMode,
      paletteStyle,
      setPaletteStyle,
      seed,
      setSeed,
      dark,
      tokens,
      backdropEnabled,
      setBackdropEnabled,
      backdropIntensity,
      setBackdropIntensity,
      motionMode,
      setMotionMode,
      reducedMotion,
      systemReduceMotion,
    }),
    [
      mode, setMode, paletteStyle, setPaletteStyle, seed, setSeed, dark, tokens,
      backdropEnabled, setBackdropEnabled, backdropIntensity, setBackdropIntensity,
      motionMode, setMotionMode, reducedMotion, systemReduceMotion,
    ],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used within ThemeProvider');
  return ctx;
}

