# TidyPlanKit

Reusable Swift Package for turning a photo into a structured decluttering plan (JSON → models) using OpenAI, with a safe offline fallback.

## Features
- Models: `Plan`, `TidyTask`, `UserLocale`, `ExitTag`
- JSON schema contract via `TidySchema`
- Planner: `TidyPlanner` with fallback when network or API key is unavailable
- OpenAI client: `OpenAIService` (vision + json_schema response)
- No UIKit dependency; image input is `Data`

## Requirements
- iOS 15+ / macOS 12+
- Swift Concurrency (async/await)

## Installation (Local path)
- Add Package in Xcode: `Add Packages...` → `Add Local...` → select `TidyPlanKit`
- Or use as a submodule and reference by path.

## Usage
```swift
import TidyPlanKit

let apiKey: String? = "YOUR_OPENAI_API_KEY" // inject securely
let planner = TidyPlanner(apiKey: apiKey)
let locale = UserLocale(country: "JP", city: "Tokyo")

// Convert UIImage (or NSImage) to JPEG Data on the app side
// let imageData = uiImage.jpegData(compressionQuality: 0.6)!

let plan = await planner.generate(from: imageData, locale: locale, allowNetwork: true)
// Map plan.tasks to your Todo model
```

## JSON Contract
- See `Sources/TidyPlanKit/TidySchema.swift`
- Sample: mirror `Scripts/dev-seed.json` in the app repo for testing

## Notes
- Network failures or missing API key return a deterministic fallback plan
- Keep images <= 1024px long edge, ~0.6 JPEG quality for latency/size

## License
- This package is part of the host app repository; follow its license.

