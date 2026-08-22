//
//  RoutineTaskTemplateLibraryView.swift
//  Lurelia
//
//  The routine-task template library. Search, empty state, and a scroll of
//  neutral template cards. Tapping a card opens a full detail
//  preview (`RoutineTaskTemplateDetailView`). Every surface uses
//  Lurelia's neutral glass tokens so templates do not imply a routine color.
//

import SwiftData
import SwiftUI
import UIKit

struct RoutineTaskTemplateLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \RoutineTaskTemplate.updatedDate, order: .reverse)
    private var templates: [RoutineTaskTemplate]

    @Query(sort: \LureliaRoutine.sortOrder)
    private var routines: [LureliaRoutine]

    @State private var searchText = ""
    @State private var editingTemplate: RoutineTaskTemplate?
    @State private var useTemplate: RoutineTaskTemplate?
    @State private var previewTemplate: RoutineTaskTemplate?
    @State private var newlyCreatedTask: LureliaRoutineTask?

    private let tint: Color = LColors.textSecondary

    private var useFullScreenCover: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var filteredTemplates: [RoutineTaskTemplate] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return templates }
        return templates.filter { template in
            let haystack = [
                template.title,
                template.notes,
                template.context,
                template.purpose,
                template.trigger,
                template.motivation,
                template.reward
            ].joined(separator: " ").lowercased()
            return haystack.contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header

                        if templates.isEmpty {
                            emptyState
                        } else {
                            searchField
                            countStrip

                            if filteredTemplates.isEmpty {
                                noMatchesState
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(filteredTemplates) { template in
                                        templateCard(template)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 60)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editingTemplate) { template in
                RoutineTaskTemplateEditorView(template: template)
            }
            .sheet(item: $useTemplate) { template in
                RoutineTaskTemplateUseSheet(
                    template: template,
                    routines: routines
                ) { routine, phase in
                    materializeTemplate(template, into: routine, phase: phase)
                }
            }
            .sheet(item: $previewTemplate) { template in
                RoutineTaskTemplateDetailView(
                    template: template,
                    onUse: { useTemplate = template },
                    onEdit: { editingTemplate = template }
                )
            }
            .routineTaskEditor(
                isPad: useFullScreenCover,
                task: $newlyCreatedTask,
                routineTint: tint
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Task Templates")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("Reusable blueprints for routine tasks")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Button { dismiss() } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
                    .foregroundStyle(LColors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(LColors.glassSurface2, in: Circle())
                    .overlay { Circle().strokeBorder(LColors.glassBorder, lineWidth: 1) }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Search + count

    private var searchField: some View {
        neutralTemplateCard(cornerRadius: 18, padding: 12) {
            HStack(spacing: 10) {
                Image("cardlines")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(LColors.textSecondary)

                TextField("Search templates", text: $searchText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var countStrip: some View {
        HStack {
            let count = filteredTemplates.count
            Text("\(count) template\(count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.4)
            Spacer()
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Template card

    private func templateCard(_ template: RoutineTaskTemplate) -> some View {
        Button {
            previewTemplate = template
        } label: {
            neutralTemplateCard {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(LColors.glassSurface2).frame(width: 48, height: 48)
                        Circle().strokeBorder(LColors.glassBorder.opacity(0.32), lineWidth: 1).frame(width: 48, height: 48)
                        LureliaIconView(iconId: template.icon.isEmpty ? "sparkle" : template.icon, size: 22)
                            .foregroundStyle(LColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.title.isEmpty ? "Untitled Template" : template.title)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if !cardSubtitle(for: template).isEmpty {
                            Text(cardSubtitle(for: template))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Spacer(minLength: 8)

                    Button {
                        delete(template)
                    } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(LColors.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(LColors.glassSurface2, in: Circle())
                            .overlay(Circle().strokeBorder(LColors.glassBorder.opacity(0.32), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete template")

                    Image("chevright")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(LColors.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func cardSubtitle(for template: RoutineTaskTemplate) -> String {
        let candidates = [
            template.notes,
            template.purpose,
            template.context,
            template.motivation
        ]
        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }

    // MARK: - Empty states

    private var emptyState: some View {
        neutralTemplateCard {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(LColors.glassSurface2).frame(width: 66, height: 66)
                    Circle().strokeBorder(LColors.glassBorder.opacity(0.32), lineWidth: 1).frame(width: 66, height: 66)
                    Image("cardlines")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundStyle(LColors.textSecondary)
                }

                VStack(spacing: 8) {
                    Text("No Templates Yet")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Save your favorite routine tasks as reusable templates so you can quickly add them to future routines.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Button { dismiss() } label: {
                    Text("Close")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(LColors.glassSurface2, in: Capsule())
                        .overlay(Capsule().strokeBorder(LColors.glassBorder.opacity(0.32), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var noMatchesState: some View {
        neutralTemplateCard {
            VStack(spacing: 8) {
                Text("Nothing Matches")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("No templates match \"\(searchText)\". Try another search.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Neutral card helper

    /// Neutral card wrapper for this library. Templates are reusable
    /// blueprints, so they stay visually separate from user routine colors.
    @ViewBuilder
    private func neutralTemplateCard<Content: View>(
        cornerRadius: CGFloat = 22,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LColors.glassSurface2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LColors.glassBorder.opacity(0.32), lineWidth: 1)
            }
    }

    // MARK: - Actions

    private func materializeTemplate(
        _ template: RoutineTaskTemplate,
        into routine: LureliaRoutine,
        phase: LureliaRoutinePhase?
    ) {
        let existingSortOrders = (routine.tasks ?? []).map(\.sortOrder)
        let nextSortOrder = (existingSortOrders.max() ?? -1) + 1

        let (task, steps, supplies, obstacles) = template.makeTask(sortOrder: nextSortOrder)

        modelContext.insert(task)
        task.routine = routine
        if let phase {
            task.phaseID = phase.persistentID
        }

        for step in steps {
            modelContext.insert(step)
            step.task = task
        }
        task.stepItems = steps

        for supply in supplies {
            modelContext.insert(supply)
            supply.task = task
        }
        task.supplyItems = supplies

        for obstacle in obstacles {
            modelContext.insert(obstacle)
            obstacle.task = task
        }
        task.obstacleItems = obstacles

        if routine.tasks == nil { routine.tasks = [] }
        routine.tasks?.append(task)

        try? modelContext.save()

        newlyCreatedTask = task
    }

    private func delete(_ template: RoutineTaskTemplate) {
        modelContext.delete(template)
        try? modelContext.save()
    }
}
