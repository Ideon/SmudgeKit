import SmudgeKit
import SwiftUI

@main
struct SmudgeDemoApp: App {
    @State private var style = SmudgeStyle.soft
    @State private var isShowingTouches = true
    @State private var placement = SmudgePlacement.overlayWindow

    var body: some Scene {
        WindowGroup {
            DemoView(style: $style, isShowingTouches: $isShowingTouches, placement: $placement)
                .showsTouches(isShowingTouches, style: style, placement: placement)
        }
    }
}

struct DemoView: View {
    @Binding var style: SmudgeStyle
    @Binding var isShowingTouches: Bool
    @Binding var placement: SmudgePlacement
    @State private var isShowingSheet = false
    @State private var isShowingAlert = false

    var body: some View {
        TabView {
            Tab("Tune", systemImage: "slider.horizontal.3") {
                SmudgeTuner(style: $style)
            }
            Tab("Gestures", systemImage: "hand.draw") {
                NavigationStack {
                    List {
                        Toggle("Show touches", isOn: $isShowingTouches)
                        Picker("Draw in", selection: $placement) {
                            Text("Overlay window").tag(SmudgePlacement.overlayWindow)
                            Text("Host window").tag(SmudgePlacement.hostWindow)
                        }
                        Button("Present a sheet") { isShowingSheet = true }
                        Button("Show an alert") { isShowingAlert = true }
                        NavigationLink("Pinch and rotate") { PinchView() }
                        ForEach(1...40, id: \.self) { Text("Row \($0)") }
                    }
                    .navigationTitle("Gestures")
                }
            }
        }
        .sheet(isPresented: $isShowingSheet) {
            ScrollView {
                Text("Touches show on sheets too.")
                    .padding(.top, 40)
                ForEach(1...30, id: \.self) { Text("Item \($0)").padding(8) }
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Alerts too", isPresented: $isShowingAlert) {
            Button("OK") {}
        }
    }
}

/// A view whose gestures claim every touch, to check the observer keeps seeing them.
struct PinchView: View {
    @State private var scale: CGFloat = 1
    @State private var angle: Angle = .zero
    @State private var offset: CGSize = .zero

    var body: some View {
        RoundedRectangle(cornerRadius: 32)
            .fill(.indigo.gradient)
            .frame(width: 220, height: 220)
            .scaleEffect(scale)
            .rotationEffect(angle)
            .offset(offset)
            .gesture(
                DragGesture().onChanged { offset = $0.translation }
                    .simultaneously(with: MagnifyGesture().onChanged { scale = $0.magnification })
                    .simultaneously(with: RotateGesture().onChanged { angle = $0.rotation })
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .navigationTitle("Pinch and rotate")
    }
}
