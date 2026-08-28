enum OverlayContextMenuAction: CaseIterable {
    case showOverlay
    case showDashboard
    case hideOverlay
    case quitApplication

    var title: String {
        switch self {
        case .showOverlay: "Show Overlay"
        case .showDashboard: "Show Dashboard"
        case .hideOverlay: "Hide Overlay"
        case .quitApplication: "Quit CC-Overlay"
        }
    }
}
