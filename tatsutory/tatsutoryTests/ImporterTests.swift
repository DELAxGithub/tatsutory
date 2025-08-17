import XCTest
@testable import tatsutory

class ImporterTests: XCTestCase {
    
    func testTidyTaskDecoding() throws {
        let json = """
        {
            "id": "TEST01",
            "title": "Test Task",
            "area": "living",
            "exit_tag": "SELL",
            "priority": 4,
            "effort_min": 30,
            "labels": ["test", "sell"],
            "checklist": ["Step 1", "Step 2"],
            "links": ["https://example.com"],
            "url": "https://example.com",
            "due_at": "2025-08-20T18:00:00Z"
        }
        """.data(using: .utf8)!
        
        let task = try JSONDecoder().decode(TidyTask.self, from: json)
        
        XCTAssertEqual(task.id, "TEST01")
        XCTAssertEqual(task.title, "Test Task")
        XCTAssertEqual(task.exitTag, .sell)
        XCTAssertEqual(task.taskPriority, 4)
        XCTAssertTrue(task.isHighPriority)
        XCTAssertNotNil(task.dueDate)
    }
    
    func testTidyTaskValidation() {
        let validTask = TidyTask(
            id: "VALID01",
            title: "Valid Task",
            area: nil,
            exit_tag: .sell,
            priority: nil,
            effort_min: nil,
            labels: nil,
            checklist: nil,
            links: nil,
            url: nil,
            due_at: nil
        )
        
        let invalidTask = TidyTask(
            id: "",
            title: "",
            area: nil,
            exit_tag: nil,
            priority: nil,
            effort_min: nil,
            labels: nil,
            checklist: nil,
            links: nil,
            url: nil,
            due_at: nil
        )
        
        XCTAssertTrue(validTask.isValid)
        XCTAssertFalse(invalidTask.isValid)
        
        let tasks = [validTask, invalidTask]
        let validatedTasks = TidyTask.validate(tasks)
        
        XCTAssertEqual(validatedTasks.count, 1)
        XCTAssertEqual(validatedTasks.first?.id, "VALID01")
    }
    
    func testFallbackPlan() {
        let plan = TidyPlanner.fallbackPlan()
        
        XCTAssertFalse(plan.tasks.isEmpty)
        XCTAssertTrue(plan.tasks.allSatisfy { $0.isValid })
        XCTAssertEqual(plan.locale.country, "CA")
        XCTAssertEqual(plan.locale.city, "Toronto")
    }
}