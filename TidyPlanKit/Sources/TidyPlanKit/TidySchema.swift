import Foundation

struct TidySchema {
    static let jsonSchema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "properties": [
            "project": [
                "type": "string",
                "description": "Name of the decluttering project"
            ],
            "locale": [
                "type": "object",
                "additionalProperties": false,
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
                    "additionalProperties": false,
                    "properties": [
                        "id": [
                            "type": "string",
                            "description": "Unique task identifier"
                        ],
                        "title": [
                            "type": "string",
                            "description": "Clear task description"
                        ],
                        "note": [
                            "type": "string",
                            "description": "Reminder notes"
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
                        "due_at": [
                            "type": "string",
                            "format": "date-time",
                            "description": "ISO8601 deadline"
                        ]
                    ],
                    "required": ["id", "title", "due_at"]
                ]
            ]
        ],
        "required": ["project", "locale", "tasks"]
    ]
}
