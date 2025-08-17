# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is "Tatsutori" - a task management and reminder import system for moving/decluttering projects. The codebase consists of:

- **JSON task definitions** (`tvmove.json`) - Structured project data with tasks, checklists, links, and metadata
- **JXA automation script** (`tvmove copy.sc.json`) - JavaScript for Automation script to import tasks into Apple Reminders

## Architecture

### Task Definition Format
Tasks are defined in JSON files with this structure:
```json
{
  "project": "Project Name",
  "locale": {"country":"CA","city":"Toronto"},
  "tasks": [
    {
      "id": "LR01",
      "title": "Task description",
      "exit_tag": "SELL|GIVE|RECYCLE",
      "checklist": ["Step 1", "Step 2"],
      "links": ["https://example.com"],
      "notes": "Additional context"
    }
  ]
}
```

### Import System
The JXA script (`tvmove copy.sc.json`) processes JSON task definitions and creates corresponding reminders in Apple Reminders app:
- Reads JSON task data
- Creates or finds target reminder list
- Converts tasks to reminders with structured body text including checklists, links, and metadata
- Sets high-priority tasks (priority >= 4) as flagged

## Usage

To run the import script:
```bash
osascript -l JavaScript /tmp/import_reminders.jxa <json_path> [list_name]
```

The script expects the JXA code to be written to `/tmp/import_reminders.jxa` first (as shown in the shell script portion).

## File Structure

- `tvmove.json` - Main task definition file for a TV area decluttering project
- `tvmove copy.sc.json` - Contains the JXA automation script for importing to Apple Reminders

## Task Categories

Tasks use exit_tag to categorize disposal methods:
- `SELL` - Items to be sold on marketplace platforms
- `GIVE` - Items to be given away or donated  
- `RECYCLE` - Items requiring proper disposal/recycling