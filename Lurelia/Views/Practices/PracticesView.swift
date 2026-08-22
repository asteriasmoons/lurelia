//
//  PracticesView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct PracticesView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \LureliaPractice.sortOrder)
    private var practices: [LureliaPractice]
    
    @Query(sort: \LureliaRoutine.sortOrder)
    private var routines: [LureliaRoutine]
    
    @State private var showAdd = false
    @State private var editingPractice: LureliaPractice? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // MARK: - Header
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Practices")
                                    .font(.system(size: 30, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                Text("Cultivate areas of your life with intention.")
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
                        
                        // MARK: - Content
                        
                        LazyVStack(spacing: 14) {
                            if practices.isEmpty {
                                emptyState
                            } else {
                                ForEach(practices) { practice in
                                    NavigationLink(value: practice.id) {
                                        PracticeCard(
                                            practice: practice,
                                            routines: routines
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationDestination(for: UUID.self) { practiceID in
                if let practice = practices.first(where: { $0.id == practiceID }) {
                    PracticeDetailView(practice: practice)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddPracticeView()
            }
            .sheet(item: $editingPractice) { practice in
                AddPracticeView(editingPractice: practice)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image("sparkle")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundStyle(LGradients.header)
            
            Text("No practices yet")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.adaptivePrimaryText)
            
            Text("A practice is a collection of routines\nthat support the same area of your life.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            
            Button {
                showAdd = true
            } label: {
                Text("Create your first practice")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.adaptivePrimaryText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(LGradients.header, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 60)
    }
}
