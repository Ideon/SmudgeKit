# SmudgeKit

SmudgeKit provides a drop in replacement for UIWindow to draw visual representations of all touch events to the screen. Ideal for for creating App Previews or other screencasts where it is crucial to show touch gestures. Not intended for production use.

Originally built to preview The Converted, [check the The Converted website for an example](http://ideon.co/theconverted?utm_source=github&utm_medium=readme&utm_campaign=smudgeKit).


## Usage

### Objective-C

Simply add the Objective-C source files SmudgyWindow.h and SmudgyWindow.m to your project and implement the getter method of the window property in your Application Delegate.

```objectivec

//In Application Delegate. (Remember to #import "SmudgyWindow.h")

- (UIWindow *)window {
    if (!_window) {
        _window = [[SmudgyWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    return _window;
}

```

You can change the appearance by editing the SmudgeLayer implementation in SmudgyWindow.m


### Swift

A swift framework with more features is in the works but not ready due to an apparent bug in the swift compiler.

## Contact

[Hans Petter Eikemo](https://github.com/hpeikemo)
[@hpeikemo](https://twitter.com/hpeikemo)
[Ideon](http://ideon.co/theconverted?utm_source=github&utm_medium=readme&utm_campaign=smudgeKit)

## License

SmudgeKit is available under the MIT license. See the LICENSE file for details.