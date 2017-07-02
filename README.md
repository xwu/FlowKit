# FlowKit

[![Build Status](https://travis-ci.org/xwu/FlowKit.svg?branch=master)](https://travis-ci.org/xwu/FlowKit)

A library for analyzing flow cytometry data, written in Swift.

## Requirements

- macOS 10.12.5+
- Xcode 9.0+

## Installation

You can integrate FlowKit into your Xcode project manually in two steps.

* Add `FlowKit.xcodeproj` to your Xcode project by:
	* dragging `FlowKit.xcodeproj` into the project in the project navigator; or
	* selecting the name of your project in the project navigator, choosing File > Add Files to "Your Project Name", then selecting `FlowKit.xcodeproj` and clicking Add.
* Add `FlowKit.framework` as a linked framework in your target settings by:
	* selecting the name of your project in the project navigator to open the project editor, then selecting the name of your target from the pop-up menu in the top left corner of the editor (or, if visible, from the list in the left column of the editor); and
	* clicking General at the top of the editor, navigating to the Linked Frameworks and Libraries section, clicking "+", selecting `FlowKit.framework`, then clicking Add.

## Usage

### Reading a Sample

```swift
import Foundation
import FlowKit

// Assuming `url` is a URL for your data file of interest
let data = try! Data(contentsOf: url)
let sample = Sample(data)!

// In an FCS data set, metadata are stored in key-value pairs
// in so-called "TEXT segments"
print(sample.keywords)

// Each parameter is stored as its own array of values
for parameter in sample.parameters {
  print(sample.events[parameter])
}
```

FlowKit automatically compensates the sample with its own acquisition matrix, if one can be parsed from the data.

### Compensating

```swift
let compensation = Compensation(
  detectors: ["FSC-A", "SSC-A"],
  matrix: [1, 0, 0, 1]
)
compensation.unmix(sample)
```

In this example, no fluorochrome names are given, so existing event data for FSC-A and SSC-A are replaced with unmixed event data.

### Transforming (Adjusting Axis Scaling)

```swift
let biexponential = LogicleTransform()! // Default parameters
print(biexponential.scaling(262144)) // 1
print(biexponential.unscaling(1)) // 262144
biexponential.scale(sample, dimensions: ["FITC-A", "PE-A"])
```

Applying a transform replaces existing event data with scaled event data.

For a Logicle (biexponential) transform, the top-of-scale value (`T`), desired number of decades (`M`), width basis or number of quasi-linear decades (`W`), and number of additional negative decades (`A`) are all adjustable parameters. Linear, Log (logarithmic), and Asinh (inverse hyperbolic sine) transforms are also available, each with adjustable parameters.

### Gating

```swift
let rectangle = RectangularGate(
  dimensions: ["FSC-A", "SSC-A"],
  ranges: [0.1..<0.5, 0.2..<0.4]
)
let population = rectangle.masking(sample)!
print(population.count)

let ellipse = EllipsoidGate(
  dimensions: ["FITC-A", "PE-A"],
  means: [-0.2, -0.2],
  covariances: [1, 0, 0, 1],
  distanceSquared: 0.2
)
let subpopulation = ellipse.masking(population)!
print(subpopulation.count)
```

Masking a sample using a gate returns a population subset, which can be masked in turn using another gate.

Rectangular gates can have one or more dimensions and ellipsoid gates can have two or more dimensions. Two-dimensional polygon gates and multidimensional Boolean gates are also available.

### Advanced Usage

In the examples above, a sample _parameter_ is also called a gating _dimension_, which can be a _detector_ dimension (e.g., FITC-A) or a compensated _fluorochrome_ dimension (e.g., CD4). These and other terms are defined in standards from the International Society for Advancement of Cytometry (ISAC).

For advanced usage of FlowKit, you may find it helpful to consult the following standards:

* [Data File Standard for Flow Cytometry, Version FCS 3.1](http://www.ncbi.nlm.nih.gov/pmc/articles/PMC2892967/bin/NIHMS203250-supplement-Supp_Fig_1.pdf)
* [Gating-ML 2.0: International Society for Advancement of Cytometry (ISAC) Standard for Representing Gating Descriptions in Flow Cytometry](http://flowcyt.sourceforge.net/gating/latest.pdf)

## License and acknowledgments

All original work is released under the MIT license.

Documentation describing the FCS and Gating-ML standards implemented by FlowKit are in part copyrighted by ISAC and released under a Creative Commons Attribution-ShareAlike 3.0 Unported license. The Logicle transform is patented by, and its implementation is ported from an original version copyrighted by, Stanford Unversity and released under a BSD three-clause license.

See LICENSE for details.
