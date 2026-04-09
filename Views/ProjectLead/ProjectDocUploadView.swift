//
//  ProjectDocUploadView.swift
//  DeskHive
//
//  Sheet presented to the project lead for uploading .docx project documents.
//  Shows uploaded docs list, status badges, and a delete action.
//

import SwiftUI
import UniformTypeIdentifiers

// .docx UTType — use the known identifier so it works on all iOS versions
extension UTType {
    static let docx = UTType(importedAs: "com.microsoft.word.docx",
                             conformingTo: .data)
}

struct ProjectDocUploadView: View {
    let communityID: String
    let uploaderUID: String

    @StateObject private var vm = ProjectDocViewModel()
    @State private var showFilePicker = false
    @Environment(\.dismiss) private var dismiss

    private let accent = Color(hex: "#F5A623")
    private let green  = Color(hex: "#4ECDC4")
    private let red    = Color(hex: "#E94560")
    private let purple = Color(hex: "#A78BFA")

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ── Top bar with close button ─────────────────────
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.top, 16)

                    // ── Header ────────────────────────────────────────
                    VStack(spacing: 6) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(accent)
                        Text("Project Documents")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Upload .docx files — they are embedded with AI\nso your team can ask questions about the project.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // ── Upload button ─────────────────────────────────
                    Button(action: { showFilePicker = true }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(accent.opacity(0.15)).frame(width: 42, height: 42)
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(accent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upload .docx Document")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Tap to choose a file from your device")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(accent.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isUploading)

                    // ── Progress / status ─────────────────────────────
                    if vm.isUploading {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: accent))
                            Text(vm.uploadProgress)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(accent.opacity(0.08))
                        .cornerRadius(12)
                    }

                    if let err = vm.errorMessage {
                        ErrorBanner(message: err)
                    }

                    if let msg = vm.successMessage {
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(green)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(green.opacity(0.08))
                            .cornerRadius(12)
                    }

                    // ── Docs list ─────────────────────────────────────
                    if !vm.docs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Uploaded Documents")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 4)

                            ForEach(vm.docs) { doc in
                                docRow(doc)
                            }
                        }
                    } else if !vm.isUploading {
                        VStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.15))
                            Text("No documents yet")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.docx, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFilePick(result)
        }
        .task {
            await vm.loadDocs(communityID: communityID)
        }
    }

    // ── Doc row ───────────────────────────────────────────────────────
    private func docRow(_ doc: ProjectDoc) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(statusColor(doc.status).opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: statusIcon(doc.status))
                    .font(.system(size: 18))
                    .foregroundColor(statusColor(doc.status))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(doc.fileName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(statusLabel(doc.status))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statusColor(doc.status))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(statusColor(doc.status).opacity(0.12))
                        .cornerRadius(5)
                    Text(shortDate(doc.uploadedAt))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                }
            }

            Spacer()

            Button(action: {
                Task { await vm.deleteDoc(doc) }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(red.opacity(0.7))
                    .padding(8)
                    .background(red.opacity(0.08))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    // ── File picker handler ───────────────────────────────────────────
    private func handleFilePick(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let err):
            vm.errorMessage = "Could not open file: \(err.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }

            // Validate extension — we only support .docx
            guard url.pathExtension.lowercased() == "docx" else {
                vm.errorMessage = "Only .docx files are supported. Please export your document as Word (.docx)."
                return
            }

            // Security-scoped resource access required on iOS for files outside sandbox
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url) else {
                vm.errorMessage = "Failed to read file."
                return
            }
            let name = url.lastPathComponent
            Task {
                await vm.uploadAndEmbed(docxData: data,
                                        fileName: name,
                                        communityID: communityID,
                                        uploaderUID: uploaderUID)
            }
        }
    }

    // ── Status helpers ────────────────────────────────────────────────
    private func statusColor(_ s: ProjectDoc.EmbedStatus) -> Color {
        switch s {
        case .ready:      return green
        case .processing: return accent
        case .pending:    return purple
        case .failed:     return red
        }
    }
    private func statusIcon(_ s: ProjectDoc.EmbedStatus) -> String {
        switch s {
        case .ready:      return "checkmark.circle.fill"
        case .processing: return "arrow.triangle.2.circlepath"
        case .pending:    return "clock.fill"
        case .failed:     return "xmark.circle.fill"
        }
    }
    private func statusLabel(_ s: ProjectDoc.EmbedStatus) -> String {
        switch s {
        case .ready:      return "Ready"
        case .processing: return "Processing"
        case .pending:    return "Pending"
        case .failed:     return "Failed"
        }
    }
    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: d)
    }
}
