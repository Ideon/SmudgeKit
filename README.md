# SmudgeKit

SmudgeKit draws every touch on screen as a soft dot that follows the finger and flies off along its last direction when it lifts. It's made for App Store previews, screen recordings and demos, where viewers need to see the gestures. It isn't meant to ship in production builds.

Version 2 is a Swift rewrite. It no longer replaces your `UIWindow`: a watch-only gesture recognizer on each window of a scene sees every touch without cancelling, delaying or competing with your own gestures, and the dots are drawn with Core Animation in a pass-through overlay window above the app.

Requires iOS 17 and Swift 6.

## Installation

Add the package in Xcode, or in `Package.swift`:

```swift
.package(url: "https://github.com/Ideon/SmudgeKit", from: "2.0.0")
```

## Usage

### SwiftUI

Apply the modifier once near the root of each scene:

```swift
import SmudgeKit

WindowGroup {
    ContentView()
        .showsTouches()
}
```

Touches show up across the whole scene, including sheets, alerts and any other windows in it. Each scene, such as each window on iPad or each display, draws its own touches.

To keep it out of release builds, gate it behind a flag:

```swift
ContentView()
    .showsTouches(isRecordingPreview)
```

### UIKit

```swift
let smudges = TouchSmudges.show(in: windowScene)
// …
smudges.stop()
```

### Placement

By default the dots are drawn in their own window above the app. Some recorders, such as ReplayKit's in-app recording on some devices, only capture the app's own windows. For those, draw on top of the window each touch lands in instead:

```swift
.showsTouches(isRecordingPreview, placement: .hostWindow)
```

The layer is raised back to the top whenever something else is added above it. Touches in other windows, such as alerts, are drawn in those windows.

### Style

`SmudgeStyle` sets the dot's size, colour, softness and rim, how it appears, and how far it drifts after the finger lifts. There are three presets:

- `.soft`, the default: a translucent white dot with a faint rim that reads on light and dark content.
- `.glow`: a larger, rimless glow for dark content.
- `.classic`: the 2014 SmudgeKit look, an opaque light disc with an outline and drop shadow.

```swift
.showsTouches(style: .glow)

var style = SmudgeStyle.soft
style.diameter = 52
style.drift = 0.15
.showsTouches(style: style)
```

`SmudgeTuner` is a view with sliders for every property over a few backdrops, and shows the resulting style as code to paste back. Open `SmudgeTuner.swift` in Xcode and use the "Tune the look" preview, or run the demo app.

## Demo

`Demo/SmudgeDemo.xcodeproj` has the tuner, scrolling lists, a sheet, an alert and a pinch and rotate view whose gestures claim every touch.

## The Objective-C version

SmudgeKit 0.1 was a `UIWindow` subclass written in Objective-C. It's still available at the `0.1.2` tag and through CocoaPods.

## Contact

[Hans Petter Eikemo](https://github.com/hpeikemo), [Ideon](https://ideon.co)

## License

SmudgeKit is available under the MIT license. See the LICENSE file for details.
