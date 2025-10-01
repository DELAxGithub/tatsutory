# TatsuTori（たつとり） — Moving-Specific "Get Rid Of" Task Maker

**Take photos → AI generates "exit strategy" tasks → Batch import to native Reminders.**

TatsuTori focuses on **"getting rid of things"** (sell/give/recycle/trash/keep) rather than organizing, providing region-specific guidance and marketplace links.

## Features

- **In-app camera** for photo capture (multiple photos planned)
- **AI plan generation**: OpenAI Vision + Structured Outputs (JSON Schema compliant)
- **Exit tags** (SELL/GIVE/RECYCLE/TRASH/KEEP) mandatory for each task
- **Batch Reminders import** (EventKit). Notes include steps, links, checklist items, due dates, and URLs
- **Offline fallback**: Rule-based templates when AI fails
- **Complete local operation**: API keys stored in Keychain. Image transmission controlled by user toggle

## Supported Regional Guides (Initial)

- **Toronto, Canada**: Waste Wizard / e-waste / Facebook Marketplace / Kijiji
- **Japan**: Municipal waste collection (link search templates) / Mercari / Yahoo Auctions / Jmty
  
*Regional guides are extensible via "search adapters"*

## Requirements

- iOS 17 or later
- Camera and Reminders access permissions
- OpenAI API Key (entered in app → stored in Keychain)

## Setup

1. Open in Xcode → Build to device
2. First launch: **Settings > API Key** to enter your key
3. "Take photo → Preview → Send to Reminders" workflow

## JSON Schema (AI Output & Import Compatible)

```json
{
  "project": "string",
  "locale": { "country": "string", "city": "string" },
  "tasks": [
    {
      "id": "string",
      "title": "string",
      "area": "string",
      "exit_tag": "SELL|GIVE|RECYCLE|TRASH|KEEP",
      "priority": 1,
      "effort_min": 15,
      "labels": ["string"],
      "checklist": ["string"],
      "links": ["string"],
      "url": "https://...",
      "due_at": "2025-08-16T18:00:00Z"
    }
  ]
}
```

## Usage Example

1. Take photo of TV stand → AI suggests "TV is SELL (Marketplace)", "Cables are e-waste", "Books are GIVE/paper recycling"
2. Preview and check desired items → "Send"
3. Created in Reminders with "exit tag, steps, links, due dates" for immediate action

## Error Handling

- **Permissions** error: Check Settings app for Camera/Reminders access
- **AI failure**: Offline templates generate minimum 3 tasks
- **Bulk creation**: 50-item batches. "Delete today's list" button for retries

## Privacy

- Images stay on device by default. AI transmission only when user explicitly enables
- API Keys stored in Keychain. No cloud transmission

## Roadmap

- Multiple photos → deduplication/bbox highlighting
- Automatic price estimation (limited categories)
- CoreData + CloudKit for custom reminders alongside native app

---

## Development

### Spec-Driven Workflow

- Use spec-driven development with Claude Code by following `./.cckiro/specs/spec-driven-development/workflow.md` before starting significant changes.

### Project Structure

```
TatsuTori/
├── Sources/
│   ├── Core/
│   │   ├── Models.swift           # TidyTask, Plan, ExitTag
│   │   ├── Errors.swift           # App-specific errors
│   │   ├── LocaleGuide.swift      # Region-specific links
│   │   └── SearchAdapter.swift    # Future search integration
│   └── Features/
│       ├── Camera/
│       │   └── CameraView.swift   # UIImagePickerController wrapper
│       ├── Planner/
│       │   ├── TidyPlanner.swift  # OpenAI integration + fallback
│       │   └── TidySchema.swift   # JSON Schema definition
│       ├── Reminders/
│       │   └── RemindersService.swift # EventKit batch operations
│       ├── Settings/
│       │   ├── SettingsView.swift # API key configuration
│       │   └── Secrets.swift      # Keychain operations
│       └── Preview/
│           └── PlanPreviewView.swift # Task selection UI
├── Tests/
│   └── ImporterTests.swift        # JSON validation tests
└── Scripts/
    └── dev-seed.json              # Sample data
```

### Key Implementation Details

- **EventKit Integration**: Uses `defaultCalendarForNewReminders().source` for reliable list creation
- **Batch Operations**: 50-task limit per import with progress tracking
- **Image Compression**: 1024px max dimension, 0.6 JPEG quality for API
- **Fallback System**: Local task templates when network/AI fails
- **Error Recovery**: Graceful degradation with user-friendly messages

### Testing

Run unit tests in Xcode:
```bash
⌘ + U
```

Tests cover:
- JSON schema validation
- Task filtering and validation
- Locale guide functionality
- Fallback plan generation

### API Integration

OpenAI Chat Completions API with structured outputs:
- Model: gpt-4o
- Response format: JSON Schema
- Timeout: 30 seconds
- Fallback on any failure

The app prioritizes reliability over AI sophistication - if anything fails, users can still accomplish their goals with template tasks.
