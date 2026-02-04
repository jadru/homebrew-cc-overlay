import SwiftUI

struct PanelDetailEditor: View {
    @State var config: PanelConfiguration
    let configStore: PanelConfigStore

    var body: some View {
        Form {
            Section("General") {
                TextField("Title", text: $config.title)
                Toggle("Visible", isOn: $config.isVisible)
                Toggle("Click-through", isOn: $config.clickThrough)
                Toggle("Auto-hide with dev tools", isOn: $config.autoHideWithDevTools)
            }

            Section("Appearance") {
                HStack {
                    Text("Opacity: \(Int(config.opacity * 100))%")
                    Slider(value: $config.opacity, in: 0.3...1.0)
                }

                HStack {
                    Text("Glass intensity: \(Int(config.glassTintIntensity * 100))%")
                    Slider(value: $config.glassTintIntensity, in: 0.05...0.60, step: 0.01)
                }

                HStack {
                    Text("Corner radius: \(Int(config.cornerRadius))")
                    Slider(value: $config.cornerRadius, in: 8...32, step: 1)
                }
            }

            Section("Position & Size") {
                LabeledContent("Position") {
                    Text("\(Int(config.originX)), \(Int(config.originY))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Size") {
                    Text("\(Int(config.width)) x \(Int(config.height))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Button("Reset to Default Size") {
                    let defaultSize = config.contentType.defaultSize
                    config.width = defaultSize.width
                    config.height = defaultSize.height
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: config) { _, newConfig in
            configStore.updatePanel(newConfig)
        }
    }
}

extension PanelConfiguration: Equatable {
    static func == (lhs: PanelConfiguration, rhs: PanelConfiguration) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.isVisible == rhs.isVisible
            && lhs.opacity == rhs.opacity
            && lhs.glassTintIntensity == rhs.glassTintIntensity
            && lhs.cornerRadius == rhs.cornerRadius
            && lhs.clickThrough == rhs.clickThrough
            && lhs.autoHideWithDevTools == rhs.autoHideWithDevTools
            && lhs.width == rhs.width
            && lhs.height == rhs.height
            && lhs.originX == rhs.originX
            && lhs.originY == rhs.originY
    }
}
