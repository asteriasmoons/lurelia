//
//  RoutinesView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \LureliaRoutine.sortOrder)
    private var routines: [LureliaRoutine]
    
    @State private var showAdd = false
    @State private var activeRoutine: LureliaRoutine? = nil
    @State private var editRoutine: LureliaRoutine? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // MARK: - Header
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Routines")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                Text("Build flexible flows you can start, pause, and complete.")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            Button {
                                showAdd = true
                            } label: {
                                Image("addwavy")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .foregroundStyle(LGradients.header)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        LazyVStack(spacing: 14) {
                            if routines.isEmpty {
                                emptyState
                            } else {
                                ForEach(routines) { routine in
                                    NavigationLink(destination: RoutineDetailView(routine: routine)) {
                                        RoutineCard(
                                            routine: routine,
                                            onRun: {
                                                if let run = routine.activeRun, run.isPaused {
                                                    RoutineManager.shared.resumeRun(
                                                        run: run,
                                                        routine: routine
                                                    )
                                                }
                                                
                                                activeRoutine = routine
                                            },
                                            onPause: {
                                                if let run = routine.activeRun {
                                                    RoutineManager.shared.pauseRun(
                                                        run: run,
                                                        routine: routine
                                                    )
                                                }
                                            },
                                            onStop: {
                                                if let run = routine.activeRun {
                                                    RoutineManager.shared.finishRun(
                                                        run: run,
                                                        routine: routine,
                                                        wasCompleted: false
                                                    )
                                                }
                                            },
                                            onEdit: {
                                                editRoutine = routine
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deleteRoutine(routine)
                                        } label: {
                                            Label("Delete Routine", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 120)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddRoutineView()
            }
            .sheet(item: $editRoutine) { routine in
                AddRoutineView(editingRoutine: routine)
            }
            .fullScreenCover(item: $activeRoutine) { routine in
                RoutineRunView(routine: routine)
            }
        }
    }
    
    private func deleteRoutine(_ routine: LureliaRoutine) {
        if activeRoutine?.persistentID == routine.persistentID {
            activeRoutine = nil
        }

        if editRoutine?.persistentID == routine.persistentID {
            editRoutine = nil
        }

        modelContext.delete(routine)
        try? modelContext.save()
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 80)
            
            Image("sparkle")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(LGradients.header)
            
            Text("No routines yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(LColors.textSecondary)
            
            Text("Tap + to build your first routine")
                .font(.subheadline)
                .foregroundStyle(LColors.textSecondary.opacity(0.7))
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
