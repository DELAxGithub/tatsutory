import XCTest
@testable import TatsuTori

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
    
    func testPlanDecoding() throws {
        let json = """
        {
            "project": "Test Project",
            "locale": {
                "country": "CA",
                "city": "Toronto"
            },
            "tasks": [
                {
                    "id": "T01",
                    "title": "Task 1",
                    "exit_tag": "SELL"
                },
                {
                    "id": "T02",
                    "title": "Task 2",
                    "exit_tag": "GIVE"
                }
            ]
        }
        """.data(using: .utf8)!
        
        let plan = try JSONDecoder().decode(Plan.self, from: json)
        
        XCTAssertEqual(plan.project, "Test Project")
        XCTAssertEqual(plan.locale.country, "CA")
        XCTAssertEqual(plan.locale.city, "Toronto")
        XCTAssertEqual(plan.tasks.count, 2)
    }
    
    func testExitTagDecoding() throws {
        let sellJson = "\"SELL\"".data(using: .utf8)!
        let giveJson = "\"GIVE\"".data(using: .utf8)!
        let invalidJson = "\"INVALID\"".data(using: .utf8)!
        
        let sellTag = try JSONDecoder().decode(ExitTag.self, from: sellJson)
        let giveTag = try JSONDecoder().decode(ExitTag.self, from: giveJson)
        
        XCTAssertEqual(sellTag, .sell)
        XCTAssertEqual(giveTag, .give)
        
        XCTAssertThrowsError(try JSONDecoder().decode(ExitTag.self, from: invalidJson))
    }
    
    func testFallbackPlan() {
        let plan = TidyPlanner.fallbackPlan()
        
        XCTAssertFalse(plan.tasks.isEmpty)
        XCTAssertTrue(plan.tasks.allSatisfy { $0.isValid })
        XCTAssertEqual(plan.locale.country, "CA")
        XCTAssertEqual(plan.locale.city, "Toronto")
    }
    
    func testLocaleGuide() {
        let torontoLocale = UserLocale(country: "CA", city: "Toronto")
        let japanLocale = UserLocale(country: "JP", city: "Tokyo")
        
        let canadaSellLinks = LocaleGuide.getDefaultLinks(for: torontoLocale, exitTag: .sell)
        let japanSellLinks = LocaleGuide.getDefaultLinks(for: japanLocale, exitTag: .sell)
        
        XCTAssertTrue(canadaSellLinks.contains("https://www.facebook.com/marketplace/"))
        XCTAssertTrue(japanSellLinks.contains("https://www.mercari.com/jp/"))
        
        let recycleChecklist = LocaleGuide.getTemplateChecklist(for: .recycle, locale: torontoLocale)
        XCTAssertFalse(recycleChecklist.isEmpty)
    }
}