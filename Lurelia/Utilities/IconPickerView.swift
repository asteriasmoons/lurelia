//
//  IconPickerView.swift
//  Lurelia
//

import SwiftUI

// MARK: - Icon Picker Sheet

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    
    private var filteredIcons: [LureliaIconItem] {
        LureliaIconLibrary.search(searchText)
    }
    
    private var groupedIcons: [(category: String, icons: [LureliaIconItem])] {
        let grouped = Dictionary(grouping: filteredIcons) { $0.category }
        
        return grouped
            .map { category, icons in
                (
                    category: category,
                    icons: icons.sorted { $0.name < $1.name }
                )
            }
            .sorted { $0.category < $1.category }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 18, pinnedViews: []) {
                        searchField
                        
                        ForEach(groupedIcons, id: \.category) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group.category)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary)
                                
                                LazyVGrid(
                                    columns: Array(
                                        repeating: GridItem(.flexible(), spacing: 10),
                                        count: 5
                                    ),
                                    spacing: 10
                                ) {
                                    ForEach(group.icons) { icon in
                                        Button {
                                            selectedIcon = icon.name
                                        } label: {
                                            iconCell(icon)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
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
    
    private func iconCell(_ icon: LureliaIconItem) -> some View {
        let isSelected = selectedIcon == icon.name

        return LureliaIconView(iconId: icon.name, size: 24)
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
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Inline Icon Renderer

struct LureliaIconView: View {
    let iconId: String
    var size: CGFloat = 22

    private var icon: LureliaIconItem? {
        LureliaIconLibrary.allIcons.first {
            $0.name == iconId.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var body: some View {
        Group {
            if let icon {
                switch icon.source {
                case .asset:
                    Image(icon.name)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()

                case .sfSymbol:
                    Image(systemName: icon.name)
                        .resizable()
                        .scaledToFit()
                }
            } else {
                Image("sparkle")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func imageView(
        name: String,
        source: LureliaIconSource
    ) -> some View {
        switch source {
        case .asset:
            assetIcon(name)

        case .sfSymbol:
            if UIImage(systemName: name) != nil {
                Image(systemName: name)
                    .resizable()
                    .scaledToFit()
            } else {
                fallbackIcon
            }
        }
    }

    private func assetIcon(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
    }

    private var fallbackIcon: some View {
        Image(systemName: "questionmark.circle.fill")
            .resizable()
            .scaledToFit()
    }
}
