import Foundation

public struct TidySchema {
    public static let jsonSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "project": [
                "type": "string",
                "description": "Name of the decluttering project"
            ],
            "locale": [
                "type": "object",
                "properties": [
                    "country": ["type": "string"],
                    "city": ["type": "string"]
                ],
                "required": ["country", "city"]
            ],
            "tasks": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "id": [
                            "type": "string",
                            "description": "Unique task identifier"
                        ],
                        "title": [
                            "type": "string",
                            "description": "Clear task description"
                        ],
                        "area": [
                            "type": "string",
                            "description": "Room or area name"
                        ],
                        "exit_tag": [
                            "type": "string",
                            "enum": ["SELL", "GIVE", "RECYCLE", "TRASH", "KEEP"],
                            "description": "How to dispose of items"
                        ],
                        "priority": [
                            "type": "integer",
                            "minimum": 1,
                            "maximum": 4,
                            "description": "Task urgency (1=low, 4=urgent)"
                        ],
                        "effort_min": [
                            "type": "integer",
                            "minimum": 5,
                            "maximum": 120,
                            "description": "Estimated time in minutes"
                        ],
                        "labels": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "Tags for categorization"
                        ],
                        "checklist": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "Step-by-step actions"
                        ],
                        "links": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "Helpful URLs"
                        ],
                        "url": [
                            "type": "string",
                            "format": "uri",
                            "description": "Primary action URL"
                        ],
                        "due_at": [
                            "type": "string",
                            "format": "date-time",
                            "description": "ISO8601 deadline"
                        ]
                    ],
                    "required": ["id", "title", "exit_tag"]
                ]
            ]
        ],
        "required": ["project", "locale", "tasks"]
    ]
}

