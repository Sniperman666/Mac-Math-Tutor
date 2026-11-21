# Math Tutor for macOS

An offline-first native SwiftUI tutor for math. It produces numbered, copyable work for supported arithmetic, algebra, geometry, trigonometry, calculus, and statistics problems.

## macOS requirement

- Runs on **macOS Big Sur 11 or newer**.
- Supports typed or pasted problems, image import, and handwritten input on a trackpad, mouse, or compatible stylus.
- Apple Vision performs image and handwriting recognition locally.
- Problems are not uploaded to a remote service.

## Run

Open `Package.swift` in Xcode on a Mac, select the `MathTutorMac` executable, and run it.

To build an unsigned `.app` bundle from Terminal:

```bash
cd MathTutorMac
bash Scripts/build-app.sh
codesign --force --deep --sign - dist/MathTutorMac.app
open dist/MathTutorMac.app
```

## Supported examples

```text
2 + 3 * (4 - 1)
2x + 4 = 10
x^2 - 5x + 6 = 0
sin(30) degrees
differentiate x^3 + 2x
integrate 3x^2
mean 8, 10, 12, 14
standard deviation 2, 4, 6
area of a circle with radius 4
hypotenuse with legs 3 and 4
```

The app deliberately reports unsupported or ambiguous requests instead of guessing. Image recognition is always shown for correction before solving.

## Test

```bash
swift test
```

## Important limits

- Equations support one variable named `x`, with linear or quadratic expressions.
- Differentiation supports sums, products, quotients, powers, and common supported functions.
- Integration currently supports a single power term, such as `3x^2`.
- Statistics treats data as a complete population.
- Geometry prompts currently cover circle area/circumference, rectangle/triangle area, and a right-triangle hypotenuse.
- OCR accuracy depends on image quality and handwriting. Check the recognized problem before solving.

Use the generated work as an explanation and learning aid, not as a replacement for understanding or an institution's academic policies.
