## 0.1.0

### Breaking Changes

* The old monolithic `lib/src/wfs_layer.dart` has been split into focused files.
  If you were importing internal paths directly (not recommended), update your imports
  to use the top-level `package:wfs_layer/wfs_layer.dart` barrel file.

### New Features

* **`WfsFeatureParser`** — New injectable, subclassable parser class.
  Override `buildMarker`, `buildPolyline`, or `buildPolygon` to customise
  geometry rendering without forking the package.

* **`WfsFeature` / `WfsGeometry` models** — Typed GeoJSON models for type-safe
  property access in callbacks and custom builders.

* **`WfsCache`** — Extracted, publicly accessible cache class with `get`, `put`,
  `evictExpired`, and `clear` APIs. Can be used independently.

* **`WfsLayer.parser`** — New optional parameter to supply a custom
  `WfsFeatureParser` subclass.

* **Full `MultiLineString` support** — Previously only the first line segment was
  rendered. Now all line segments in a `MultiLineString` are emitted.

* **Full `MultiPolygon` support** — Previously only the first polygon was rendered.
  Now all polygon members in a `MultiPolygon` are emitted.

* **`WfsLayerOptions.==` and `hashCode`** — Options equality is now field-based,
  enabling proper `didUpdateWidget` change detection.

* **`WfsLayer.didUpdateWidget`** — The widget now responds to options changes at
  runtime, clearing the cache and triggering a reload automatically.

### Bug Fixes

* Removed `import 'dart:io'` — the package now works on **Web** (previously,
  `SocketException` and `HttpException` from `dart:io` caused web compilation errors).

* Fixed `Colors.withOpacity()` deprecation — replaced with
  `Color.withValues(alpha:)` throughout.

* Removed dead commented-out `onTap` code on `Polyline` and `Polygon`.

* Fixed unused variable lint warnings (`_currentMarkerCount`, `now` in
  `_cleanupCache`).

* Removed unused `WfsRequestType` and `GeometryType` enums.

### Improvements

* All public API members now have `///` documentation comments.
* `analysis_options.yaml` upgraded to `strict-casts`, `strict-inference`, and
  `strict-raw-types` with additional recommended linter rules.
* `pubspec.yaml` cleaned up: removed deprecated `author` field, fixed
  `homepage` to a valid URL, added `repository` and `issue_tracker` fields,
  updated `flutter` SDK constraint from `>=1.17.0` to `>=3.10.0`.
* Example app polished: removed `//TODO` comments, uses `onError` correctly,
  shows tapped feature properties in a bottom card.
* Tests expanded to cover `WfsFeatureParser`, `WfsCache`, `WfsLayerOptions`
  equality, and the MultiGeometry data-loss fixes.

---

## 0.0.1

* Initial release.
