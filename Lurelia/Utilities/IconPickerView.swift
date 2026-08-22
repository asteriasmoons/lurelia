//
//  IconPickerView.swift
//  Lurelia
//

import SwiftUI
import UIKit

// MARK: - Icon Picker Sheet

struct IconPickerView: View {
    @Binding var selectedIcon: String
    var dismissesOnSelection = false
    var allowedSources: [LureliaIconSource] = LureliaIconSource.allCases
    var onSelection: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedCategory = ""
    
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var availableIcons: [LureliaIconItem] {
        LureliaIconLibrary.allIcons.filter { allowedSources.contains($0.source) }
    }

    private var categories: [String] {
        Array(Set(availableIcons.map(\.category))).sorted()
    }

    private var activeCategory: String {
        if categories.contains(selectedCategory) {
            return selectedCategory
        }

        return categories.first ?? ""
    }

    private var visibleIcons: [LureliaIconItem] {
        let icons = isSearching
            ? searchAvailableIcons(searchText)
            : availableIcons.filter { $0.category == activeCategory }

        return Array(
            icons
                .sorted {
                    if $0.category != $1.category {
                        return $0.category < $1.category
                    }

                    return $0.name < $1.name
                }
                .prefix(180)
        )
    }

    private var resultCountText: String {
        if isSearching {
            return "\(visibleIcons.count) result\(visibleIcons.count == 1 ? "" : "s")"
        }

        return "\(visibleIcons.count) icon\(visibleIcons.count == 1 ? "" : "s")"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 18, pinnedViews: []) {
                        searchField

                        if !isSearching {
                            categoryTabs
                        }

                        HStack {
                            Text(isSearching ? "Search Results" : activeCategory)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary)

                            Spacer()

                            Text(resultCountText)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary.opacity(0.62))
                        }

                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 48, maximum: 56), spacing: 10)
                            ],
                            spacing: 10
                        ) {
                            ForEach(visibleIcons) { icon in
                                Button {
                                    selectedIcon = icon.name
                                    onSelection?(icon.name)

                                    if dismissesOnSelection {
                                        dismiss()
                                    }
                                } label: {
                                    iconCell(icon)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .id(isSearching ? "search-\(searchText)" : activeCategory)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(LColors.textPrimary)
                }
            }
            .onAppear {
                normalizeSelectedCategory()
            }
            .onChange(of: categories) { _, _ in
                normalizeSelectedCategory()
            }
        }
    }
    
    private var searchField: some View {
        GlassCard {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary.opacity(0.7))
                
                TextField("Search icons", text: $searchText)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var categoryTabs: some View {
        LureliaFlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(categories, id: \.self) { category in
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        selectedCategory = category
                    }
                } label: {
                    Text(category)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(category == activeCategory ? .white : LColors.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(
                            category == activeCategory
                            ? AnyShapeStyle(LGradients.header)
                            : AnyShapeStyle(LColors.glassSurface),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    category == activeCategory ? LColors.glassBorderStrong : LColors.glassBorder,
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func iconCell(_ icon: LureliaIconItem) -> some View {
        let isSelected = selectedIcon == icon.name

        return LureliaIconGlyph(icon: icon, size: 22)
            .foregroundStyle(
                isSelected
                ? AnyShapeStyle(LGradients.header)
                : AnyShapeStyle(LColors.textPrimary)
            )
            .frame(width: 48, height: 48)
            .background(
                isSelected ? LColors.glassSurface2 : LColors.glassSurface,
                in: RoundedRectangle(cornerRadius: LSpacing.inputRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                    .strokeBorder(
                        isSelected ? LColors.glassBorderStrong : LColors.glassBorder,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: LSpacing.inputRadius))
    }

    private func normalizeSelectedCategory() {
        if selectedCategory.isEmpty || !categories.contains(selectedCategory) {
            selectedCategory = categories.first ?? ""
        }
    }

    private func searchAvailableIcons(_ query: String) -> [LureliaIconItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return availableIcons
        }

        return availableIcons.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
            || $0.category.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
}

struct LureliaIconPickerView: View {
    @Binding var selectedIcon: String

    var body: some View {
        IconPickerView(selectedIcon: $selectedIcon, dismissesOnSelection: true)
    }
}

// MARK: - Inline Icon Renderer

struct LureliaIconView: View {
    let iconId: String
    var size: CGFloat = 22

    private var icon: LureliaIconItem? {
        LureliaIconLibrary.icon(named: iconId)
    }

    var body: some View {
        Group {
            if let icon {
                LureliaIconGlyph(icon: icon, size: size)
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
    }
}

private struct LureliaIconGlyph: View {
    let icon: LureliaIconItem
    var size: CGFloat

    @ViewBuilder
    var body: some View {
        switch icon.source {
        case .asset:
            if UIImage(named: icon.name) != nil {
                Image(icon.name)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                fallbackIcon
            }

        case .sfSymbol:
            if UIImage(systemName: icon.name) != nil {
                Image(systemName: icon.name)
                    .resizable()
                    .scaledToFit()
            } else {
                fallbackIcon
            }
        }
    }
}

private var fallbackIcon: some View {
    Group {
        if UIImage(named: "sparkle") != nil {
            Image("sparkle")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        } else {
        Image(systemName: "questionmark.circle.fill")
            .resizable()
            .scaledToFit()
        }
    }
}
