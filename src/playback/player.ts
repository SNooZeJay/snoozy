import TrackPlayer, {
  Event,
  PlayerCommand,
  RepeatMode,
  type MediaItem,
} from '@rntp/player';

let playerPromise: Promise<void> | null = null;

export function ensurePlayer(): Promise<void> {
  if (!playerPromise) {
    playerPromise = Promise.resolve()
      .then(() => {
        try {
          TrackPlayer.setupPlayer({
            contentType: 'music',
            handleAudioBecomingNoisy: true,
            audioMixing: 'exclusive',
            android: {
              wakeMode: 'local',
              taskRemovedBehavior: 'continue',
            },
          });
        } catch (error) {
          const message = error instanceof Error ? error.message : String(error);
          if (!/already|initialized/i.test(message)) throw error;
        }

        TrackPlayer.setCommands({
          capabilities: [
            PlayerCommand.PlayPause,
            PlayerCommand.Seek,
            PlayerCommand.Next,
            PlayerCommand.Previous,
          ],
          handling: 'native',
        });
      })
      .catch((error) => {
        playerPromise = null;
        throw error;
      });
  }

  return playerPromise;
}

export function watchPlaybackError(onError: (message: string) => void) {
  return TrackPlayer.addEventListener(Event.PlaybackError, (event) => {
    onError(event.message);
  });
}

export function seekTo(seconds: number): void {
  TrackPlayer.seekTo(Math.max(0, seconds));
}

export { TrackPlayer, RepeatMode };
export type { MediaItem };