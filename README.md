# rn-ios-library-paragraph-descriptor

On iOS, React Native never uses a library's own component descriptor for `Paragraph` (`<Text>`), while it uses the
same library's descriptor for `View`.

`ReproducerApp` runs on `react-native@0.90.0-nightly-20261112-897cca827`. Its library, `ReproducerApp/library`
(`ios/LibraryDescriptors.mm`), registers two component views from `+load` through
`-[RCTComponentViewFactory registerComponentViewClass:]`:

- `LibraryViewComponentView`, whose descriptor `LibraryViewComponentDescriptor` is a `ConcreteComponentDescriptor<ViewShadowNode>`;
- `LibraryParagraphComponentView`, whose descriptor `LibraryParagraphComponentDescriptor` is a `BaseParagraphComponentDescriptor<ParagraphShadowNode>`.

Each descriptor counts the shadow nodes it adopts. `App.tsx` renders a `View` holding two `Text`s, and once that is
mounted it shows both counts on screen, from `LibraryDescriptorsProbe.report()`.

## Steps

1. `cd ReproducerApp && yarn install && cd ios && pod install`
2. `yarn ios --mode Release`, or run the `ReproducerApp` scheme from Xcode.
3. Read the second line on the screen.

Expected: both descriptors adopted shadow nodes.

Actual: `LibraryViewComponentDescriptor` adopted shadow nodes, and `LibraryParagraphComponentDescriptor` adopted 0.

## Script

`./repro.sh` does the steps on the booted simulator and prints the app's report; `./repro.sh build-device` and
`./repro.sh run-device <udid> <app>` do them on a device. It exits 1 while the Paragraph descriptor adopts nothing
and 0 once it adopts the app's `Text`s.
