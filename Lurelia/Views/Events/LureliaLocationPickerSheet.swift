//
//  LureliaLocationPickerSheet.swift
//  Lurelia
//
//  Search-driven location picker for the event editor. Uses
//  `LocationSearchService` (MKLocalSearchCompleter under the hood) to
//  provide as-you-type suggestions for any place a user could type into
//  Apple Maps — businesses, addresses, landmarks. When the user taps a
//  suggestion, the sheet resolves it to a full
//  `LureliaLocationResult` (name + address + coordinates) and hands it
//  back via `onSelect`.
//

import MapKit
import SwiftUI

struct LureliaLocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var search = LocationSearchService()
    @State private var isResolving = false
    @FocusState private var isSearchFocused: Bool

    let onSelect: (LureliaLocationResult) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    searchField
                    resultsList
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear { isSearchFocused = true }
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        GlassCard {
            HStack(spacing: 10) {
                Image("starpinlocation")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.white.opacity(0.7))

                TextField(
                    "",
                    text: $search.query,
                    prompt: Text("Search any place…")
                        .foregroundStyle(.white.opacity(0.4))
                )
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .focused($isSearchFocused)

                if !search.query.isEmpty {
                    Button {
                        search.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsList: some View {
        if search.completions.isEmpty {
            emptyState
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(search.completions, id: \.self) { completion in
                        resultRow(completion)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text(search.query.isEmpty ? "Start typing to search" : "No matches")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func resultRow(_ completion: MKLocalSearchCompletion) -> some View {
        Button {
            Task { await pick(completion) }
        } label: {
            GlassCard {
                HStack(alignment: .top, spacing: 12) {
                    Image("starpinlocation")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(completion.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if !completion.subtitle.isEmpty {
                            Text(completion.subtitle)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isResolving)
    }

    private func pick(_ completion: MKLocalSearchCompletion) async {
        isResolving = true
        defer { isResolving = false }
        guard let resolved = await search.resolve(completion) else { return }
        onSelect(resolved)
        dismiss()
    }
}
