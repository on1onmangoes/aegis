// aegis_content_view_260629.swift
// Added 260629: Main two-pane UI.
//   Left  : drop zone for the badge image, Verify button, speed HUD, verdict, nearby list
//   Right : the credential graph (World Tree)
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = AegisViewModel()
    @State private var dragOver = false
    @State private var showImporter = false

    var body: some View {
        HSplitView {
            leftPane
                .frame(minWidth: 360, idealWidth: 420)
            rightPane
                .frame(minWidth: 460)
        }
        .frame(minWidth: 900, minHeight: 620)
    }

    // MARK: Left

    private var leftPane: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.lefthalf.filled").foregroundColor(.accentColor)
                Text("Aegis").font(.system(size: 22, weight: .bold))
                Text("Multiverse Credential Verification")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }

            dropZone

            Button {
                showImporter = true
            } label: {
                Label("Choose Image…", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.image, .png, .jpeg],
                          allowsMultipleSelection: false) { result in
                handleImport(result)
            }

            examplesStrip

            criteriaPanel

            Button(action: { Task { await vm.run() } }) {
                HStack {
                    if vm.isRunning { ProgressView().controlSize(.small) }
                    Text(vm.isRunning ? "Verifying across realms…" : "Verify Credentials")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .disabled(vm.nsImage == nil || vm.isRunning)

            Text(vm.status).font(.system(size: 12)).foregroundColor(.secondary)

            if let err = vm.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12)).foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SpeedHUDView(timings: vm.timings, aggregateTokensPerSec: vm.aggregateTokensPerSec)

            if let v = vm.verdict { verdictCard(v) }
            if vm.cmsProfile != nil || vm.background != nil { educationCard }
            if !vm.matches.isEmpty { matchesList }
            if !vm.publications.isEmpty { publicationsList }
            if !vm.videos.isEmpty { videosList }
            if !vm.nearby.isEmpty { nearbyList }

            Spacer()
        }
        .padding(16)
        }
    }

    private var criteriaPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Match criteria (Realm 5)").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            HStack {
                Text("Specialty").font(.system(size: 11)).frame(width: 64, alignment: .leading)
                TextField("e.g. Child Psychiatry", text: $vm.matchCriteria.neededSpecialty)
                    .textFieldStyle(.roundedBorder).font(.system(size: 11))
            }
            HStack {
                Text("Max dist").font(.system(size: 11)).frame(width: 64, alignment: .leading)
                Slider(value: $vm.matchCriteria.maxDistanceKm, in: 1...25, step: 1)
                Text("\(Int(vm.matchCriteria.maxDistanceKm)) km")
                    .font(.system(size: 11, design: .monospaced)).frame(width: 44, alignment: .trailing)
            }
            Toggle("Accepting new patients", isOn: $vm.matchCriteria.mustAcceptNewPatients)
                .font(.system(size: 11))
            Picker("Modality", selection: $vm.matchCriteria.modality) {
                Text("In-person").tag("in-person")
                Text("Telehealth").tag("telehealth")
                Text("Either").tag("either")
            }
            .pickerStyle(.segmented)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    private var matchesList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ranked matches · gemma-4-31b").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            ForEach(Array(vm.matches.enumerated()), id: \.element.id) { idx, m in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("\(idx + 1).").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                        Text(m.name).font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text(String(format: "%.0f%%", m.score * 100))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(idx == 0 ? .green : .secondary)
                    }
                    Text(m.reason).font(.system(size: 10)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !m.gaps.isEmpty {
                        Text("gaps: " + m.gaps.joined(separator: ", "))
                            .font(.system(size: 10)).foregroundColor(.orange)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(idx == 0 ? Color.green.opacity(0.12) : Color.secondary.opacity(0.05)))
            }
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundColor(dragOver ? .accentColor : .secondary.opacity(0.5))
            if let img = vm.nsImage {
                Image(nsImage: img).resizable().scaledToFit().padding(8)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "person.text.rectangle").font(.system(size: 32)).foregroundColor(.secondary)
                    Text("Drop a provider ID badge").font(.system(size: 13))
                    Text("(PNG / JPEG)").font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
        }
        .frame(height: 200)
        .contentShape(Rectangle())
        .onTapGesture { showImporter = true }
        .onDrop(of: [.image, .fileURL], isTargeted: $dragOver) { providers in
            handleDrop(providers)
        }
    }

    // MARK: Examples (bundled demo badges)

    private struct ExampleBadge: Identifiable {
        let id: String      // resource base name (no extension)
        let title: String
    }
    private var examples: [ExampleBadge] {
        [
            .init(id: "rex_adamson_badge_260629",   title: "Adamson · verified"),
            .init(id: "mismatch_demo_badge_260629", title: "Kumar · fraud"),
            .init(id: "nancy_beckman_badge_260629", title: "Beckman · UChicago"),
            .init(id: "devon_addonizio_badge_260629", title: "Addonizio · NYC")
        ]
    }

    private var examplesStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Examples (click to load)").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(examples) { ex in
                        Button { loadExample(ex.id) } label: {
                            VStack(spacing: 3) {
                                if let img = exampleImage(ex.id) {
                                    Image(nsImage: img).resizable().scaledToFill()
                                        .frame(width: 88, height: 56).clipped().cornerRadius(5)
                                } else {
                                    RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.2))
                                        .frame(width: 88, height: 56)
                                }
                                Text(ex.title).font(.system(size: 9)).foregroundColor(.secondary)
                                    .lineLimit(1).frame(width: 88)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func exampleImage(_ name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "examples") else { return nil }
        return NSImage(contentsOf: url)
    }
    private func loadExample(_ name: String) {
        if let img = exampleImage(name) { vm.setImage(img) }
        else { vm.errorMessage = "Example '\(name)' not found in app bundle." }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let img = NSImage(contentsOf: url) {
                vm.setImage(img)
            } else {
                vm.errorMessage = "Could not read image at \(url.lastPathComponent)"
            }
        case .failure(let err):
            vm.errorMessage = err.localizedDescription
        }
    }

    private func verdictCard(_ v: AnalystVerdict) -> some View {
        let icon: String
        let color: Color
        switch v.status {
        case "verified":        icon = "checkmark.seal.fill"; color = .green
        case "needs_attention": icon = "exclamationmark.triangle.fill"; color = .orange
        default:                icon = "xmark.seal.fill"; color = .red
        }
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(v.displayLabel).fontWeight(.bold).foregroundColor(color)
                Text(String(format: "· score %.0f%%", v.score * 100))
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
            Text(v.summary).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            ForEach(v.discrepancies, id: \.self) { d in
                Label(d, systemImage: "arrow.triangle.branch").font(.system(size: 11)).foregroundColor(.orange)
            }
            ForEach(v.risk_flags, id: \.self) { f in
                Label(f, systemImage: "flag.fill").font(.system(size: 11)).foregroundColor(.red)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }

    private var educationCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Background & education").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            if let cms = vm.cmsProfile {
                Label("\(cms.medSchool)\(cms.gradYear.isEmpty ? "" : " · \(cms.gradYear)")",
                      systemImage: "graduationcap.fill")
                    .font(.system(size: 11)).foregroundColor(.primary)
                if cms.residency.isEmpty && cms.undergrad.isEmpty {
                    Text("Residency / undergrad: no free authoritative source")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
            if let bg = vm.background {
                Text(bg.summary).font(.system(size: 10)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !bg.focus_areas.isEmpty {
                    Text("Focus: " + bg.focus_areas.joined(separator: ", "))
                        .font(.system(size: 10)).foregroundColor(.indigo)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    private var publicationsList: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Publications · PubMed").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            ForEach(vm.publications) { p in
                if let url = URL(string: p.url) {
                    Link(destination: url) {
                        HStack(alignment: .top, spacing: 5) {
                            Image(systemName: "doc.text.fill").foregroundColor(.purple).font(.system(size: 10))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(p.title).font(.system(size: 10)).lineLimit(2)
                                    .multilineTextAlignment(.leading).foregroundColor(.primary)
                                Text("\(p.journal) \(p.year)").font(.system(size: 9)).foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var videosList: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Related videos · YouTube").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            ForEach(vm.videos) { v in
                if let url = URL(string: v.url) {
                    Link(destination: url) {
                        HStack(spacing: 5) {
                            Image(systemName: "play.rectangle.fill").foregroundColor(.pink).font(.system(size: 10))
                            Text(v.title).font(.system(size: 10)).lineLimit(2)
                                .multilineTextAlignment(.leading).foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var nearbyList: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Nearby wellness providers").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            ForEach(vm.nearby) { p in
                HStack {
                    Image(systemName: "mappin.circle.fill").foregroundColor(.blue).font(.system(size: 11))
                    Text(p.name).font(.system(size: 11))
                    if let d = p.distanceMeters {
                        Text(String(format: "%.1f km", d / 1000)).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: Right

    private var rightPane: some View {
        ZStack {
            Color(NSColor.textBackgroundColor)
            if let g = vm.graph {
                CredentialGraphView(graph: g).padding(24)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.5))
                    Text("The credential graph appears here").foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: Drop handling

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.canLoadObject(ofClass: NSImage.self) {
            _ = provider.loadObject(ofClass: NSImage.self) { obj, _ in
                if let img = obj as? NSImage {
                    DispatchQueue.main.async { vm.setImage(img) }
                }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      let img = NSImage(contentsOf: url) else { return }
                DispatchQueue.main.async { vm.setImage(img) }
            }
            return true
        }
        return false
    }
}
