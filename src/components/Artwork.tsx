import Feather from '@expo/vector-icons/Feather';
import { Image, StyleSheet, View } from 'react-native';

import { useTheme } from '../theme';
import { AppText } from './AppText';

type CoverArtProps = {
  uri?: string | null;
  size: number;
  radius?: number;
  label?: string;
  icon?: 'disc' | 'music';
};

export function CoverArt({
  uri,
  size,
  radius = Math.round(size * 0.14),
  label,
  icon = 'disc',
}: CoverArtProps) {
  const { palette } = useTheme();

  if (uri) {
    return (
      <Image
        source={{ uri }}
        style={[styles.image, { width: size, height: size, borderRadius: radius }]}
      />
    );
  }

  return (
    <View
      style={[
        styles.fallback,
        {
          width: size,
          height: size,
          borderRadius: radius,
          backgroundColor: palette.surfaceMuted,
          borderColor: palette.border,
        },
      ]}
    >
      {label ? (
        <AppText variant="heading" color={palette.accent}>
          {label.slice(0, 1).toUpperCase()}
        </AppText>
      ) : (
        <Feather name={icon} size={Math.round(size * 0.34)} color={palette.accent} />
      )}
    </View>
  );
}

type PlaylistCoverProps = {
  artworks: (string | null | undefined)[];
  size: number;
  radius?: number;
};

export function PlaylistCover({
  artworks,
  size,
  radius = Math.round(size * 0.12),
}: PlaylistCoverProps) {
  const { palette } = useTheme();
  const available = Array.from(new Set(artworks.filter((item): item is string => Boolean(item)))).slice(0, 4);

  if (available.length === 0) {
    return <CoverArt size={size} radius={radius} icon="music" />;
  }

  if (available.length === 1) {
    return <CoverArt uri={available[0]} size={size} radius={radius} icon="music" />;
  }

  const gap = Math.max(2, Math.round(size * 0.012));
  const cell = Math.floor((size - gap) / 2);

  return (
    <View
      style={[
        styles.mosaic,
        {
          width: size,
          height: size,
          borderRadius: radius,
          backgroundColor: palette.surfaceMuted,
          borderColor: palette.border,
        },
      ]}
    >
      {Array.from({ length: 4 }, (_, index) => {
        const uri = available[index];
        if (uri) {
          return (
            <Image
              key={`${uri}-${index}`}
              source={{ uri }}
              style={{ width: cell, height: cell }}
            />
          );
        }
        return (
          <View
            key={`empty-${index}`}
            style={[
              styles.mosaicEmpty,
              { width: cell, height: cell, backgroundColor: palette.surfaceMuted },
            ]}
          >
            <Feather name="music" size={Math.round(cell * 0.34)} color={palette.inkFaint} />
          </View>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  image: {
    backgroundColor: '#13261C',
  },
  fallback: {
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
  },
  mosaic: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    overflow: 'hidden',
    borderWidth: 1,
    gap: 2,
  },
  mosaicEmpty: {
    alignItems: 'center',
    justifyContent: 'center',
  },
});
