// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Apple Maps (MapKit) View         ║
// ║           KauaiMapView.swift                                 ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI
import MapKit

// MARK: - Kauai Location Model
struct KauaiLocation: Identifiable, Hashable {
    let id      = UUID()
    let name:   String
    let emoji:  String
    let coord:  CLLocationCoordinate2D
    let detail: String

    // CLLocationCoordinate2D isn't Hashable, so implement manually via stable UUID
    static func == (lhs: KauaiLocation, rhs: KauaiLocation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct KauaiMapView: View {
    @EnvironmentObject var bridgeService: BridgeService
    @Environment(\.dismiss) var dismiss

    @State private var selectedLocation: KauaiLocation? = nil
    @State private var mapStyle: MapStyle = .standard(elevation: .realistic, pointsOfInterest: .all, showsTraffic: true)
    @State private var useTrafficOverlay = true
    @State private var coordsCopied = false

    // Camera centered on Kauai
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.05, longitude: -159.50),
            span:   MKCoordinateSpan(latitudeDelta: 0.55, longitudeDelta: 0.55)
        )
    )

    // Key Kauai driver locations
    var locations: [KauaiLocation] = [
        KauaiLocation(name: "Lihue Airport",    emoji: "✈️", coord: .init(latitude: 21.9758, longitude: -159.3390), detail: "LIH — Main pickup/dropoff"),
        KauaiLocation(name: "Princeville",       emoji: "🏡", coord: .init(latitude: 22.2154, longitude: -159.4853), detail: "North shore luxury resort area"),
        KauaiLocation(name: "Hanalei",           emoji: "🌉", coord: .init(latitude: 22.2056, longitude: -159.5019), detail: "Hanalei Bridge checkpoint"),
        KauaiLocation(name: "Kapaa",             emoji: "🏘️", coord: .init(latitude: 22.0752, longitude: -159.3190), detail: "Eastside hub"),
        KauaiLocation(name: "Poipu Beach",       emoji: "🏖️", coord: .init(latitude: 21.8769, longitude: -159.4570), detail: "South shore resort area"),
        KauaiLocation(name: "Waimea",            emoji: "🏔️", coord: .init(latitude: 21.9571, longitude: -159.6671), detail: "Westside · Canyon area"),
        KauaiLocation(name: "Koloa",             emoji: "🌺", coord: .init(latitude: 21.9053, longitude: -159.4677), detail: "Old Koloa Town · South"),
        KauaiLocation(name: "Grand Hyatt Kauai", emoji: "🏨", coord: .init(latitude: 21.8737, longitude: -159.4614), detail: "Grand Hyatt — Poipu resort"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Map ─────────────────────────────────────────────
                Map(position: $cameraPosition, selection: $selectedLocation) {
                    ForEach(locations) { loc in
                        Annotation(loc.name, coordinate: loc.coord, anchor: .bottom) {
                            annotationView(for: loc)
                        }
                        .tag(loc)
                    }
                }
                .mapStyle(mapStyle)
                .ignoresSafeArea(edges: .bottom)

                // ── Bridge Status Overlay ────────────────────────────
                VStack {
                    HStack {
                        Spacer()
                        bridgeOverlay
                            .padding(.top, 12)
                            .padding(.trailing, 12)
                    }
                    Spacer()
                }

                // ── Map Style Toggle ─────────────────────────────────
                VStack {
                    Spacer()
                    mapStylePicker
                        .padding(.bottom, 32)
                }

                // ── Location Detail Sheet ────────────────────────────
                if let loc = selectedLocation {
                    VStack {
                        Spacer()
                        locationDetailCard(loc)
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.move(edge: .bottom))
                    .animation(.spring(), value: selectedLocation?.id)
                }
            }
            .navigationTitle("🗺️ Kauai Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.oceanDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.coral)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Re-center on Kauai
                        withAnimation {
                            cameraPosition = .region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: 22.05, longitude: -159.50),
                                span:   MKCoordinateSpan(latitudeDelta: 0.55, longitudeDelta: 0.55)
                            ))
                        }
                    } label: {
                        Image(systemName: "location.viewfinder").foregroundColor(AppTheme.coral)
                    }
                }
            }
            .onChange(of: selectedLocation?.id) { _, _ in
                if let loc = selectedLocation {
                    withAnimation {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(
                                latitude:  loc.coord.latitude  - 0.02,
                                longitude: loc.coord.longitude
                            ),
                            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                        ))
                    }
                }
            }
        }
    }

    // MARK: - Annotation
    @ViewBuilder
    private func annotationView(for loc: KauaiLocation) -> some View {
        let isSelected = selectedLocation?.id == loc.id
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isSelected ? AppTheme.coral : AppTheme.oceanMedium)
                    .frame(width: isSelected ? 46 : 38, height: isSelected ? 46 : 38)
                    .shadow(color: .black.opacity(0.4), radius: 4)
                Text(loc.emoji)
                    .font(.system(size: isSelected ? 22 : 18))
            }
            if isSelected {
                Text(loc.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.coral)
                    .cornerRadius(5)
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
        .onTapGesture { selectedLocation = isSelected ? nil : loc }
    }

    // MARK: - Bridge Overlay
    private var bridgeOverlay: some View {
        HStack(spacing: 6) {
            Image(systemName: bridgeService.level.sfSymbol)
                .font(.system(size: 14))
                .foregroundColor(bridgeService.level.statusColor)
            Text("Bridge: \(bridgeService.bridgeStatus)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Map Style Picker
    private var mapStylePicker: some View {
        HStack(spacing: 8) {
            ForEach(["Standard", "Satellite", "Hybrid"], id: \.self) { style in
                Button(style) {
                    switch style {
                    case "Satellite": mapStyle = .imagery(elevation: .realistic)
                    case "Hybrid":    mapStyle = .hybrid(elevation: .realistic, pointsOfInterest: .all, showsTraffic: true)
                    default:          mapStyle = .standard(elevation: .realistic, pointsOfInterest: .all, showsTraffic: true)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Location Detail Card
    private func locationDetailCard(_ loc: KauaiLocation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(loc.emoji).font(.system(size: 28))
                VStack(alignment: .leading, spacing: 3) {
                    Text(loc.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(loc.detail)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Spacer()
                Button {
                    selectedLocation = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
            .padding(16)

            Divider().background(AppTheme.oceanLight)

            HStack(spacing: 12) {
                // Navigate in Apple Maps
                Button {
                    let item: MKMapItem
                    if #available(iOS 17.0, *) {
                        item = MKMapItem(location: CLLocation(latitude: loc.coord.latitude, longitude: loc.coord.longitude), address: nil)
                    } else {
                        item = MKMapItem(placemark: MKPlacemark(coordinate: loc.coord))
                    }
                    item.name = loc.name
                    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                } label: {
                    Label("Navigate", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.coral)
                        .cornerRadius(AppTheme.buttonRadius)
                }

                Button {
                    UIPasteboard.general.string = "\(loc.coord.latitude), \(loc.coord.longitude)"
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.easeInOut(duration: 0.15)) { coordsCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeInOut(duration: 0.2)) { coordsCopied = false }
                    }
                } label: {
                    Label(
                        coordsCopied ? "Copied!" : "Copy Coords",
                        systemImage: coordsCopied ? "checkmark.circle.fill" : "doc.on.clipboard"
                    )
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(coordsCopied ? AppTheme.success : AppTheme.coral)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.buttonRadius)
                            .stroke(coordsCopied ? AppTheme.success : AppTheme.coral, lineWidth: 1.5)
                    )
                }
                .disabled(coordsCopied)
            }
            .padding(16)
        }
        .background(AppTheme.oceanMedium)
        .clipCorners(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.4), radius: 20, y: -5)
    }
}

// MARK: - Selective Corner Radius Helper
extension View {
    func clipCorners(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius:  CGFloat      = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
