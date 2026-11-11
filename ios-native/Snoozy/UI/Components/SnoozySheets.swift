import SwiftUI
import UIKit
import UniformTypeIdentifiers

public struct AudioDocumentPicker: UIViewControllerRepresentable {
    public let allowFolders: Bool
    public let onPick: ([URL]) -> Void

    public init(allowFolders: Bool = false, onPick: @escaping ([URL]) -> Void) {
        self.allowFolders = allowFolders
        self.onPick = onPick
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = allowFolders
            ? [.folder, .audio, .mp3, .wav, .aiff, .mpeg4Audio]
            : [.audio, .mp3, .wav, .aiff, .mpeg4Audio, .item]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    public final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }
        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}

public struct TrackActionsSheetView: View {
    public let track: Track
    public let isFavorite: Bool
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    public let onPlayNext: () -> Void
    public let onAddToQueue: () -> Void
    public let onAddToPlaylist: () -> Void
    public let onToggleFavorite: () -> Void
    public let onEditMetadata: () -> Void
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        SnoozyArtworkView(artworkPath: track.artworkPath, size: 56, cornerRadius: 14, theme: theme)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.title)
                                .font(SnoozyTypography.headline(17))
                                .foregroundStyle(theme.ink)
                                .lineLimit(1)
                            Text("\(track.artist) · \(track.album)")
                                .font(SnoozyTypography.footnote(13))
                                .foregroundStyle(theme.inkMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .liquidGlassSurface(
                        cornerRadius: 20,
                        glassMode: preferences.glassMode,
                        refractionIntensity: preferences.refractionIntensity,
                        tintColor: theme.accent
                    )

                    VStack(spacing: 8) {
                        sheetActionRow(icon: "text.insert", title: "Play next") {
                            onPlayNext()
                            dismiss()
                        }
                        sheetActionRow(icon: "text.append", title: "Add to queue") {
                            onAddToQueue()
                            dismiss()
                        }
                        sheetActionRow(icon: "music.note.list", title: "Add to playlist") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onAddToPlaylist()
                            }
                        }
                        sheetActionRow(
                            icon: isFavorite ? "heart.slash.fill" : "heart.fill",
                            title: isFavorite ? "Remove from Favorites" : "Add to Favorites"
                        ) {
                            onToggleFavorite()
                            dismiss()
                        }
                        sheetActionRow(icon: "slider.horizontal.3", title: "Edit song metadata") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onEditMetadata()
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Song Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func sheetActionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 28)
                Text(title)
                    .font(SnoozyTypography.body(15, bold: true))
                    .foregroundStyle(theme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.inkFaint)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .liquidGlassSurface(
                cornerRadius: 16,
                glassMode: preferences.glassMode,
                refractionIntensity: preferences.refractionIntensity * 0.7,
                tintColor: theme.accent
            )
        }
        .buttonStyle(.plain)
    }
}

public struct AddToPlaylistSheetView: View {
    public let track: Track
    @ObservedObject public var repository: LibraryRepository
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    @State private var newPlaylistName: String = ""
    @State private var newlyAddedIds: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    TextField("New playlist name", text: $newPlaylistName)
                        .font(SnoozyTypography.body(15))
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .liquidGlassSurface(
                            cornerRadius: 16,
                            glassMode: preferences.glassMode,
                            refractionIntensity: preferences.refractionIntensity * 0.6,
                            tintColor: theme.accent
                        )

                    LiquidGlassButton(
                        title: "Create",
                        systemImage: "plus",
                        isProminent: true,
                        isDisabled: newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        theme: theme,
                        preferences: preferences
                    ) {
                        if let createdId = repository.createPlaylist(name: newPlaylistName) {
                            repository.addToPlaylist(playlistId: createdId, trackId: track.id)
                            newlyAddedIds.insert(createdId)
                            newPlaylistName = ""
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if repository.playlists.isEmpty {
                    Spacer()
                    Text("No playlists yet. Create one above to add \"\(track.title)\".")
                        .font(SnoozyTypography.body(15))
                        .foregroundStyle(theme.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(repository.playlists) { playlist in
                                let isAdded = newlyAddedIds.contains(playlist.id) || playlist.trackIds.contains(track.id)
                                Button {
                                    if !isAdded {
                                        repository.addToPlaylist(playlistId: playlist.id, trackId: track.id)
                                        newlyAddedIds.insert(playlist.id)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(isAdded ? theme.accent : theme.inkMuted)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(playlist.name)
                                                .font(SnoozyTypography.body(15, bold: true))
                                                .foregroundStyle(theme.ink)
                                            Text(isAdded ? "Added" : SnoozyFormat.countLabel(playlist.trackIds.count, "track", "tracks"))
                                                .font(SnoozyTypography.footnote(12))
                                                .foregroundStyle(isAdded ? theme.accent : theme.inkMuted)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 52)
                                    .liquidGlassSurface(
                                        cornerRadius: 16,
                                        glassMode: preferences.glassMode,
                                        refractionIntensity: preferences.refractionIntensity * 0.7,
                                        tintColor: theme.accent
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isAdded)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

public struct AddSongsToPlaylistSheetView: View {
    public let playlistId: String
    @ObservedObject public var repository: LibraryRepository
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    @State private var filterText: String = ""
    @Environment(\.dismiss) private var dismiss

    private var currentPlaylist: Playlist? {
        repository.playlists.first(where: { $0.id == playlistId })
    }

    private var filteredTracks: [Track] {
        let q = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return repository.sortedSongs }
        return repository.sortedSongs.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            $0.album.lowercased().contains(q)
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(theme.inkMuted)
                    TextField("Filter songs", text: $filterText)
                        .font(SnoozyTypography.body(15))
                        .foregroundStyle(theme.ink)
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .liquidGlassSurface(
                    cornerRadius: 16,
                    glassMode: preferences.glassMode,
                    refractionIntensity: preferences.refractionIntensity * 0.6,
                    tintColor: theme.accent
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        let memberIds = Set(currentPlaylist?.trackIds ?? [])
                        ForEach(filteredTracks) { track in
                            let isMember = memberIds.contains(track.id)
                            Button {
                                if isMember {
                                    repository.removeFromPlaylist(playlistId: playlistId, trackId: track.id)
                                } else {
                                    repository.addToPlaylist(playlistId: playlistId, trackId: track.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    SnoozyArtworkView(artworkPath: track.artworkPath, size: 42, cornerRadius: 10, theme: theme)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.title)
                                            .font(SnoozyTypography.body(15, bold: true))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        Text(track.artist)
                                            .font(SnoozyTypography.footnote(12))
                                            .foregroundStyle(theme.inkMuted)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: isMember ? "checkmark.circle.fill" : "plus.circle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(isMember ? theme.accent : theme.inkMuted)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .liquidGlassSurface(
                                    cornerRadius: 16,
                                    glassMode: preferences.glassMode,
                                    refractionIntensity: preferences.refractionIntensity * 0.6,
                                    tintColor: theme.accent
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Add Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.accent)
                }
            }
        }
    }
}

public struct QueueSheetView: View {
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if playback.queueTracks.isEmpty {
                    Spacer()
                    Text("Queue is empty.")
                        .font(SnoozyTypography.body(15))
                        .foregroundStyle(theme.inkMuted)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(playback.queueTracks.enumerated()), id: \.element.id) { index, track in
                                let isCurrent = (index == playback.queueIndex)
                                HStack(spacing: 10) {
                                    Button {
                                        playback.playQueueItem(at: index)
                                    } label: {
                                        HStack(spacing: 10) {
                                            SnoozyArtworkView(artworkPath: track.artworkPath, size: 42, cornerRadius: 10, theme: theme)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(track.title)
                                                    .font(SnoozyTypography.body(14, bold: true))
                                                    .foregroundStyle(isCurrent ? theme.accent : theme.ink)
                                                    .lineLimit(1)
                                                Text(track.artist)
                                                    .font(SnoozyTypography.footnote(12))
                                                    .foregroundStyle(theme.inkMuted)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    if index > 0 {
                                        Button {
                                            playback.moveQueueItem(from: index, to: index - 1)
                                        } label: {
                                            Image(systemName: "arrow.up")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(theme.inkMuted)
                                                .frame(width: 34, height: 34)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if index + 1 < playback.queueTracks.count {
                                        Button {
                                            playback.moveQueueItem(from: index, to: index + 1)
                                        } label: {
                                            Image(systemName: "arrow.down")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(theme.inkMuted)
                                                .frame(width: 34, height: 34)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Button {
                                        playback.removeQueueItem(at: index)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(theme.danger)
                                            .frame(width: 34, height: 34)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .liquidGlassSurface(
                                    cornerRadius: 16,
                                    glassMode: preferences.glassMode,
                                    refractionIntensity: preferences.refractionIntensity * 0.7,
                                    tintColor: isCurrent ? theme.accent : .white
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Up Next (\(playback.queueTracks.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !playback.queueTracks.isEmpty {
                        Button("Clear") {
                            playback.clearQueue()
                            dismiss()
                        }
                        .foregroundStyle(theme.danger)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.accent)
                }
            }
        }
    }
}

public struct LyricsSheetView: View {
    public let track: Track
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        let offset = repository.lyricsOffset(for: track.id)
        let activeIdx = playback.activeLyrics.flatMap {
            LyricsEngine.activeLineIndex(
                lyrics: $0,
                positionSeconds: playback.positionSeconds,
                offsetSeconds: offset
            )
        }

        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Text(String(format: "Offset: %+.1fs", offset))
                        .font(SnoozyTypography.caption(12, bold: true))
                        .foregroundStyle(theme.inkMuted)
                    Spacer()
                    Button("-0.5s") {
                        repository.setLyricsOffset(for: track.id, seconds: offset - 0.5)
                    }
                    .font(SnoozyTypography.caption(12, bold: true))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .liquidGlassSurface(cornerRadius: 12, glassMode: preferences.glassMode, tintColor: theme.accent)

                    Button("+0.5s") {
                        repository.setLyricsOffset(for: track.id, seconds: offset + 0.5)
                    }
                    .font(SnoozyTypography.caption(12, bold: true))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .liquidGlassSurface(cornerRadius: 12, glassMode: preferences.glassMode, tintColor: theme.accent)

                    if abs(offset) >= 0.05 {
                        Button("Reset") {
                            repository.setLyricsOffset(for: track.id, seconds: 0.0)
                        }
                        .font(SnoozyTypography.caption(12, bold: true))
                        .foregroundStyle(theme.inkMuted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if let lyrics = playback.activeLyrics, !lyrics.lines.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                ForEach(lyrics.lines) { line in
                                    let isCurrent = (activeIdx == line.id)
                                    Button {
                                        if let t = line.timeSeconds {
                                            playback.seek(to: max(0.0, t + offset))
                                        }
                                    } label: {
                                        Text(line.text)
                                            .font(SnoozyTypography.title(isCurrent ? 22 : 17))
                                            .foregroundStyle(isCurrent ? theme.accent : theme.inkMuted)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                    .id(line.id)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .onChange(of: activeIdx) { _, newIdx in
                            if let newIdx {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    proxy.scrollTo(newIdx, anchor: .center)
                                }
                            }
                        }
                    }
                } else {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 36))
                            .foregroundStyle(theme.inkFaint)
                        Text("No lyrics found for \"\(track.title)\"")
                            .font(SnoozyTypography.headline(16))
                            .foregroundStyle(theme.ink)
                        Text("Place a matching .lrc file alongside the audio file in On My iPhone > Snoozy, or embed ID3 USLT/SYLT lyrics.")
                            .font(SnoozyTypography.footnote(13))
                            .foregroundStyle(theme.inkMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                    Spacer()
                }
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.accent)
                }
            }
        }
    }
}

public struct TrackMetadataEditSheetView: View {
    public let track: Track
    @ObservedObject public var repository: LibraryRepository
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    @State private var title: String
    @State private var artist: String
    @State private var album: String
    @State private var genre: String
    @State private var year: String
    @State private var descriptionText: String
    @Environment(\.dismiss) private var dismiss

    public init(
        track: Track,
        repository: LibraryRepository,
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences
    ) {
        self.track = track
        self.repository = repository
        self.theme = theme
        self.preferences = preferences
        _title = State(initialValue: track.title)
        _artist = State(initialValue: track.artist)
        _album = State(initialValue: track.album)
        _genre = State(initialValue: track.genre ?? "")
        _year = State(initialValue: track.year ?? "")
        _descriptionText = State(initialValue: track.descriptionText ?? "")
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    fieldRow(label: "Title", text: $title)
                    fieldRow(label: "Artist", text: $artist)
                    fieldRow(label: "Album", text: $album)
                    fieldRow(label: "Genre", text: $genre)
                    fieldRow(label: "Year", text: $year)
                    fieldRow(label: "Notes", text: $descriptionText)

                    Button {
                        repository.resetTrackOverride(trackId: track.id)
                        dismiss()
                    } label: {
                        Text("Reset to Embedded File Tags")
                            .font(SnoozyTypography.body(14, bold: true))
                            .foregroundStyle(theme.danger)
                            .padding(.top, 8)
                    }
                }
                .padding(16)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Edit Metadata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(theme.inkMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let ov = TrackOverride(
                            trackId: track.id,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            artist: artist.trimmingCharacters(in: .whitespacesAndNewlines),
                            album: album.trimmingCharacters(in: .whitespacesAndNewlines),
                            genre: genre.trimmingCharacters(in: .whitespacesAndNewlines),
                            year: year.trimmingCharacters(in: .whitespacesAndNewlines),
                            descriptionText: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        repository.saveTrackOverride(ov)
                        dismiss()
                    }
                    .foregroundStyle(theme.accent)
                }
            }
        }
    }

    private func fieldRow(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(SnoozyTypography.caption(12, bold: true))
                .foregroundStyle(theme.inkMuted)
            TextField(label, text: text)
                .font(SnoozyTypography.body(15))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .liquidGlassSurface(
                    cornerRadius: 14,
                    glassMode: preferences.glassMode,
                    refractionIntensity: preferences.refractionIntensity * 0.6,
                    tintColor: theme.accent
                )
        }
    }
}
