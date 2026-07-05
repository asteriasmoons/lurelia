//
//  ProfileView.swift
//  Lurelia
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var settings: [UserSettings]
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoSourceDialog = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showOnboardingResetConfirmation = false
    
    private var userSettings: UserSettings? {
        settings.first
    }
    
    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    
                    // MARK: - Header
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profile")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // MARK: - Profile Card
                    
                    profileCard
                        .padding(.horizontal, 24)

                    devControlsCard
                        .padding(.horizontal, 24)
                    
                    Spacer()
                        .frame(height: 110)
                }
            }
            
            if showPhotoSourceDialog {
                photoSourcePopup
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .zIndex(10)
            }

            if showOnboardingResetConfirmation {
                onboardingResetPopup
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .zIndex(11)
            }
        }
        .sheet(isPresented: $showCamera) {
            LureliaImagePicker(sourceType: .camera) { image in
                saveProfileImage(image)
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) {
            Task {
                guard let item = selectedPhotoItem else { return }
                
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    saveProfileImage(image)
                }
            }
        }
    }

    private var photoSourcePopup: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(duration: 0.22)) {
                        showPhotoSourceDialog = false
                    }
                }
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LColors.glassSurface2)
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(LGradients.header)
                }
                
                VStack(spacing: 5) {
                    Text("Profile Photo")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Choose a source for your profile picture.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(duration: 0.22)) {
                            showPhotoSourceDialog = false
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            showPhotoPicker = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 14, weight: .bold))
                            
                            Text("Choose From Gallery")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(LGradients.header)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        withAnimation(.spring(duration: 0.22)) {
                            showPhotoSourceDialog = false
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            showCamera = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .bold))
                            
                            Text("Use Camera")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(LColors.glassSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .strokeBorder(LColors.glassBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        withAnimation(.spring(duration: 0.22)) {
                            showPhotoSourceDialog = false
                        }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(maxWidth: 330)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(lureliaHex: "#10101A").opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                LColors.gradientBlue.opacity(0.42),
                                LColors.gradientPurple.opacity(0.42)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .padding(.horizontal, 24)
        }
    }
    
    private var onboardingResetPopup: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(duration: 0.22)) {
                        showOnboardingResetConfirmation = false
                    }
                }

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 52, height: 52)

                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.red.opacity(0.92))
                }

                VStack(spacing: 5) {
                    Text("Reset Onboarding?")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("This will mark onboarding as incomplete so you can go through it again. Your profile photo and other saved profile details will stay intact.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button {
                        resetOnboardingState()

                        withAnimation(.spring(duration: 0.22)) {
                            showOnboardingResetConfirmation = false
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .bold))

                            Text("Reset Onboarding")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(Color.red.opacity(0.32))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .strokeBorder(Color.red.opacity(0.48), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(duration: 0.22)) {
                            showOnboardingResetConfirmation = false
                        }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(maxWidth: 330)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(lureliaHex: "#10101A").opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.42),
                                LColors.gradientPurple.opacity(0.32)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .padding(.horizontal, 24)
        }
    }
    
    private func saveProfileImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            return
        }
        
        let userSettings: UserSettings
        
        if let existing = settings.first {
            userSettings = existing
        } else {
            userSettings = UserSettings()
            modelContext.insert(userSettings)
        }
        
        userSettings.profileImageData = data
        
        try? modelContext.save()
    }

    private func resetOnboardingState() {
        let userSettings: UserSettings

        if let existing = settings.first {
            userSettings = existing
        } else {
            userSettings = UserSettings()
            modelContext.insert(userSettings)
        }

        userSettings.hasCompletedOnboarding = false
        userSettings.selectedCategories = []
        userSettings.selectedStarterRoutines = []

        try? modelContext.save()
    }

    private var profileCard: some View {
        GlassCard {
            VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LColors.glassSurface)
                    .frame(width: 92, height: 92)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                LColors.gradientBlue.opacity(0.18),
                                LColors.gradientPurple.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 92)
                
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                LColors.gradientBlue.opacity(0.65),
                                LColors.gradientPurple.opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 92, height: 92)
                
                Group {
                    if let data = userSettings?.profileImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image("profilewavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 38, height: 38)
                            .foregroundStyle(.white)
                            .padding(18)
                            .background(
                                Circle()
                                    .fill(LGradients.header)
                            )
                    }
                }
                .frame(width: 82, height: 82)
                .clipShape(Circle())
                
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button {
                            showPhotoSourceDialog = true
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(LGradients.header, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 92, height: 92)
               } // may need to delete
            }
        }
    }

    private var devControlsCard: some View {
        profileSectionCard(
            title: "Dev Controls",
            icon: "wrench.and.screwdriver.fill"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Temporary testing controls for pre-release setup.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    withAnimation(.spring(duration: 0.22)) {
                        showOnboardingResetConfirmation = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .bold))

                        Text("Reset Onboarding State")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.red.opacity(0.24))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.red.opacity(0.42), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func profileSectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                iconView(icon, size: 18)
                    .foregroundStyle(LGradients.header)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                LColors.gradientBlue.opacity(0.72),
                                                LColors.gradientPurple.opacity(0.72),
                                                Color.white.opacity(0.34)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.05
                                    )
                            )
                    )
                
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
            }
            
            content()
            }
        }
    }
    
    private func iconView(_ icon: String, size: CGFloat) -> some View {
        Group {
            if UIImage(named: icon) != nil {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: icon)
                    .font(.system(size: size, weight: .semibold))
            }
        }
        .frame(width: size, height: size)
    }
}


// MARK: - Image Picker

struct LureliaImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: LureliaImagePicker
        
        init(_ parent: LureliaImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
