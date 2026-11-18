import SwiftUI
import PhotosUI
import UIKit

enum SnoozyArtworkImporter {
    static func save(_ data: Data, cacheDirectory: URL) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        let directory = cacheDirectory
            .appendingPathComponent("CustomArtwork", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("custom-\(UUID().uuidString).jpg")
            guard let jpeg = image.jpegData(compressionQuality: 0.9) else { return nil }
            try jpeg.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
    }
}

struct SnoozyArtworkPickerRow: View {
    @Binding var artworkPath: String?
    let cacheDirectory: URL
    let theme: SnoozyThemeColors
    let preferences: SnoozyPreferences

    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 14) {
            if let artworkPath {
                SnoozyArtworkView(artworkPath: artworkPath, size: 64, cornerRadius: 14, theme: theme)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.accent.opacity(0.16))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Artwork")
                    .font(SnoozyTypography.caption(12, bold: true))
                    .foregroundStyle(theme.inkMuted)
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Text(artworkPath == nil ? "Choose Artwork" : "Replace Artwork")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.accent)
                }
            }

            Spacer()
        }
        .padding(12)
        .liquidGlassSurface(
            cornerRadius: 18,
            glassMode: preferences.glassMode,
            refractionIntensity: preferences.refractionIntensity * 0.6,
            tintColor: theme.accent
        )
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                await MainActor.run {
                    if let path = SnoozyArtworkImporter.save(data, cacheDirectory: cacheDirectory) {
                        artworkPath = path
                    }
                }
            }
        }
    }
}

struct SnoozyEditField: View {
    let label: String
    @Binding var text: String
    let theme: SnoozyThemeColors
    let preferences: SnoozyPreferences
    var isMultiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(SnoozyTypography.caption(12, bold: true))
                .foregroundStyle(theme.inkMuted)
            if isMultiline {
                TextEditor(text: $text)
                    .font(SnoozyTypography.body(15))
                    .foregroundStyle(theme.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 90)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .liquidGlassSurface(
                        cornerRadius: 14,
                        glassMode: preferences.glassMode,
                        refractionIntensity: preferences.refractionIntensity * 0.6,
                        tintColor: theme.accent
                    )
            } else {
                TextField(label, text: $text)
                    .font(SnoozyTypography.body(15))
                    .foregroundStyle(theme.ink)
                    .textInputAutocapitalization(.words)
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
}

private struct SnoozyEditNotice: View {
    let theme: SnoozyThemeColors

    var body: some View {
        Text("Saved inside Snoozy. Audio file tags are not modified.")
            .font(SnoozyTypography.footnote(12))
            .foregroundStyle(theme.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}

public struct AlbumEditSheetView: View {
    public let album: Album
    @ObservedObject public var repository: LibraryRepository
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    public var onSaved: ((String) -> Void)? = nil

    @State private var title: String
    @State private var artist: String
    @State private var year: String
    @State private var genre: String
    @State private var artworkPath: String?
    @Environment(\.dismiss) private var dismiss

    public init(
        album: Album,
        repository: LibraryRepository,
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences,
        onSaved: ((String) -> Void)? = nil
    ) {
        self.album = album
        self.repository = repository
        self.theme = theme
        self.preferences = preferences
        self.onSaved = onSaved
        _title = State(initialValue: album.title)
        _artist = State(initialValue: album.artist)
        _year = State(initialValue: album.year ?? "")
        _genre = State(initialValue: repository.tracks(forAlbum: album.id).first?.genre ?? "")
        _artworkPath = State(initialValue: album.artworkPath)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    SnoozyArtworkPickerRow(
                        artworkPath: $artworkPath,
                        cacheDirectory: repository.store.artworkCacheURL,
                        theme: theme,
                        preferences: preferences
                    )
                    SnoozyEditField(label: "Album Title", text: $title, theme: theme, preferences: preferences)
                    SnoozyEditField(label: "Album Artist", text: $artist, theme: theme, preferences: preferences)
                    HStack(spacing: 12) {
                        SnoozyEditField(label: "Year", text: $year, theme: theme, preferences: preferences)
                        SnoozyEditField(label: "Genre", text: $genre, theme: theme, preferences: preferences)
                    }
                    SnoozyEditNotice(theme: theme)
                }
                .padding(16)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Edit Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(theme.inkMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newKey = repository.updateAlbum(
                            album: album,
                            title: title,
                            artist: artist,
                            year: year,
                            genre: genre,
                            artworkPath: artworkPath
                        )
                        dismiss()
                        if let newKey {
                            onSaved?(newKey)
                        }
                    }
                    .foregroundStyle(theme.accent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }
}

public struct ArtistEditSheetView: View {
    public let artistName: String
    @ObservedObject public var repository: LibraryRepository
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    public var onSaved: ((String) -> Void)? = nil

    @State private var name: String
    @State private var artworkPath: String?
    @Environment(\.dismiss) private var dismiss

    public init(
        artistName: String,
        repository: LibraryRepository,
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences,
        onSaved: ((String) -> Void)? = nil
    ) {
        self.artistName = artistName
        self.repository = repository
        self.theme = theme
        self.preferences = preferences
        self.onSaved = onSaved
        _name = State(initialValue: artistName)
        _artworkPath = State(initialValue: repository.artistOverrideArtwork(for: artistName))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    SnoozyArtworkPickerRow(
                        artworkPath: $artworkPath,
                        cacheDirectory: repository.store.artworkCacheURL,
                        theme: theme,
                        preferences: preferences
                    )
                    SnoozyEditField(label: "Artist Name", text: $name, theme: theme, preferences: preferences)
                    SnoozyEditNotice(theme: theme)
                }
                .padding(16)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Edit Artist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(theme.inkMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let savedName = repository.updateArtist(
                            name: artistName,
                            newName: name,
                            artworkPath: artworkPath
                        )
                        dismiss()
                        if let savedName {
                            onSaved?(savedName)
                        }
                    }
                    .foregroundStyle(theme.accent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }
}

public struct PlaylistEditSheetView: View {
    public let playlist: Playlist
    @ObservedObject public var repository: LibraryRepository
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences

    @State private var name: String
    @State private var descriptionText: String
    @State private var artworkPath: String?
    @Environment(\.dismiss) private var dismiss

    public init(
        playlist: Playlist,
        repository: LibraryRepository,
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences
    ) {
        self.playlist = playlist
        self.repository = repository
        self.theme = theme
        self.preferences = preferences
        _name = State(initialValue: playlist.name)
        _descriptionText = State(initialValue: playlist.descriptionText ?? "")
        _artworkPath = State(initialValue: playlist.artworkPath)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    SnoozyArtworkPickerRow(
                        artworkPath: $artworkPath,
                        cacheDirectory: repository.store.artworkCacheURL,
                        theme: theme,
                        preferences: preferences
                    )
                    SnoozyEditField(label: "Playlist Name", text: $name, theme: theme, preferences: preferences)
                    SnoozyEditField(
                        label: "Description",
                        text: $descriptionText,
                        theme: theme,
                        preferences: preferences,
                        isMultiline: true
                    )
                    SnoozyEditNotice(theme: theme)
                }
                .padding(16)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Edit Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(theme.inkMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        repository.updatePlaylist(
                            id: playlist.id,
                            name: name,
                            descriptionText: descriptionText,
                            artworkPath: artworkPath
                        )
                        dismiss()
                    }
                    .foregroundStyle(theme.accent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }
}
