import Feather from '@expo/vector-icons/Feather';
import { Image, View } from 'react-native';

import {
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../theme';
import { AppText } from './AppText';

export type ThumbTrack = {
  title: string;
  artwork?: string | null;
};

type ThumbProps = {
  track?: ThumbTrack | null;
  size?: number;
  opacity?: number;
};

/**
 * Artwork-led thumbnail: renders the track image when the track carries
 * artwork, otherwise the letter tile. Rows without a track use NoteTile or
 * DottedNote below.
 */
export function Thumb({ track, size = 48, opacity = 1 }: ThumbProps) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);

  if (track?.artwork) {
    return (
      <Image
        source={{ uri: track.artwork }}
        style={[styles.image, { width: size, height: size, borderRadius: Math.round(size * 0.28), opacity }]}
      />
    );
  }

  return (
    <View
      style={[
        styles.fallback,
        { width: size, height: size, borderRadius: Math.round(size * 0.28), opacity },
      ]}
    >
      {track ? (
        <AppText variant="heading" color={palette.accent}>
          {track.title.slice(0, 1).toUpperCase()}
        </AppText>
      ) : (
        <Feather name="music" size={Math.round(size * 0.36)} color={palette.inkFaint} />
      )}
    </View>
  );
}

type NoteTileProps = {
  size?: number;
};

/**
 * Rounded-square tile with a music note, matching the reference playlist
 * rows. Used where the row is a playlist rather than a track.
 */
export function NoteTile({ size = 48 }: NoteTileProps) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  return (
    <View
      style={[
        styles.noteTile,
        { width: size, height: size, borderRadius: Math.round(size * 0.3) },
      ]}
    >
      <Feather name="music" size={Math.round(size * 0.42)} color={palette.accent} />
    </View>
  );
}

type DottedNoteProps = {
  size?: number;
};

/**
 * The dotted circular music-note placeholder from the reference: a dashed
 * ring with a single mint note inside. Used for empty Recently cards and
 * search/library empty states.
 */
export function DottedNote({ size = 96 }: DottedNoteProps) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  return (
    <View
      style={[
        styles.note,
        { width: size, height: size, borderRadius: size / 2 },
      ]}
    >
      <Feather name="music" size={Math.round(size * 0.38)} color={palette.accent} />
    </View>
  );
}

const createStyles = ({ palette }: AppTheme) => ({
  image: { backgroundColor: palette.surfaceMuted },
  fallback: {
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    backgroundColor: palette.surfaceMuted,
    borderWidth: 1,
    borderColor: palette.border,
  },
  noteTile: {
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    backgroundColor: palette.surfaceMuted,
    borderWidth: 1,
    borderColor: palette.border,
  },
  note: {
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    borderWidth: 1,
    borderStyle: 'dashed' as const,
    borderColor: palette.borderStrong,
  },
});
