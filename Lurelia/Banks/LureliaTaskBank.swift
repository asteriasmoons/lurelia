//
//  LureliaTaskBank.swift
//  Lurelia
//

import Foundation

// MARK: - Task Bank Item

struct LureliaTaskBankItem: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let category: String
    let notes: String?
    let coinReward: Int
    
    init(
        title: String,
        category: String,
        notes: String? = nil,
        coinReward: Int = 0
    ) {
        self.id = "\(category)-\(title)"
        self.title = title
        self.category = category
        self.notes = notes
        self.coinReward = coinReward
    }
}

// MARK: - Task Bank

enum LureliaTaskBank {
    
    static let allItems: [LureliaTaskBankItem] = [
        
        // MARK: - Health
        
        .init(title: "Take Morning Medication", category: "Health", coinReward: 10),
        .init(title: "Take Night Medication", category: "Health", coinReward: 10),
        .init(title: "Refill Medication", category: "Health", coinReward: 25),
        .init(title: "Schedule Refill Appointment", category: "Health", coinReward: 30),
        .init(title: "Doctor Appointment Prep", category: "Health", coinReward: 25),
        .init(title: "Track Symptoms", category: "Health", coinReward: 15),
        .init(title: "Drink Water", category: "Health", coinReward: 5),
        .init(title: "Rest Break", category: "Health", coinReward: 5),
        .init(title: "Stretch Gently", category: "Health", coinReward: 10),
        .init(title: "Check Pain Level", category: "Health", coinReward: 10),
        .init(title: "Fill Water Bottle", category: "Health", coinReward: 10),
        .init(title: "Take Vitamins", category: "Health", coinReward: 10),
        .init(title: "Prepare Medication Cup", category: "Health", coinReward: 15),
        .init(title: "Eat a Snack", category: "Health", coinReward: 10),
        .init(title: "Take your Vitals", category: "Health", coinReward: 15),
        .init(title: "Heat Up Heating Pad", category: "Health", coinReward: 10),
        .init(title: "Apply Ice Pack", category: "Health", coinReward: 10),
        .init(title: "Use Bathroom", category: "Health", coinReward: 5),
        .init(title: "Refill Pill Organizer", category: "Health", coinReward: 25),
        .init(title: "Put Medicine Back", category: "Health", coinReward: 5),
        
        // MARK: - Fitness
        
        .init(title: "Morning Stretch", category: "Fitness", coinReward: 15),
        .init(title: "Walk Outside", category: "Fitness", coinReward: 20),
        .init(title: "Light Workout", category: "Fitness", coinReward: 25),
        .init(title: "Yoga Session", category: "Fitness", coinReward: 30),
        .init(title: "Strength Training", category: "Fitness", coinReward: 40),
        .init(title: "Posture Reset", category: "Fitness", coinReward: 10),
        .init(title: "Movement Break", category: "Fitness", coinReward: 10),
        .init(title: "Cooldown Stretch", category: "Fitness", coinReward: 15),
        .init(title: "Stand Up for Two Minutes", category: "Fitness", coinReward: 5),
        .init(title: "Walk Around the Room", category: "Fitness", coinReward: 10),
        .init(title: "Do Ten Shoulder Rolls", category: "Fitness", coinReward: 5),
        .init(title: "Do Five Wall Pushups", category: "Fitness", coinReward: 15),
        .init(title: "March in Place", category: "Fitness", coinReward: 10),
        .init(title: "Do Ankle Circles", category: "Fitness", coinReward: 5),
        .init(title: "Stretch Neck Gently", category: "Fitness", coinReward: 5),
        .init(title: "Do a Chair Stretch", category: "Fitness", coinReward: 10),
        .init(title: "Walk to the Mailbox", category: "Fitness", coinReward: 15),
        .init(title: "Put on Walking Shoes", category: "Fitness", coinReward: 5),
        
        // MARK: - Home
        
        .init(title: "Make Bed", category: "Home", coinReward: 15),
        .init(title: "Laundry Day", category: "Home", coinReward: 35),
        .init(title: "Wash Dishes", category: "Home", coinReward: 25),
        .init(title: "Take Out Trash", category: "Home", coinReward: 20),
        .init(title: "Clean Counters", category: "Home", coinReward: 20),
        .init(title: "Vacuum Floor", category: "Home", coinReward: 30),
        .init(title: "Tidy Living Room", category: "Home", coinReward: 25),
        .init(title: "Clean Bathroom", category: "Home", coinReward: 40),
        .init(title: "Grocery Planning", category: "Home", coinReward: 20),
        .init(title: "Meal Prep", category: "Home", coinReward: 35),
        .init(title: "Start a Laundry Load", category: "Home", coinReward: 15),
        .init(title: "Move Laundry to Dryer", category: "Home", coinReward: 10),
        .init(title: "Fold Five Items", category: "Home", coinReward: 10),
        .init(title: "Put Dishes in Sink", category: "Home", coinReward: 5),
        .init(title: "Load Dishwasher", category: "Home", coinReward: 15),
        .init(title: "Wipe Table", category: "Home", coinReward: 10),
        .init(title: "Clear Nightstand", category: "Home", coinReward: 10),
        .init(title: "Pick Up Floor Items", category: "Home", coinReward: 15),
        .init(title: "Replace Trash Bag", category: "Home", coinReward: 10),
        .init(title: "Put Groceries Away", category: "Home", coinReward: 20),
        
        // MARK: - Work
        
        .init(title: "Review Work Priorities", category: "Work", coinReward: 15),
        .init(title: "Check Email", category: "Work", coinReward: 10),
        .init(title: "Start Focus Session", category: "Work", coinReward: 25),
        .init(title: "Project Planning", category: "Work", coinReward: 30),
        .init(title: "Admin Catch-Up", category: "Work", coinReward: 25),
        .init(title: "End Workday Review", category: "Work", coinReward: 20),
        .init(title: "Open Work App", category: "Work", coinReward: 5),
        .init(title: "Set Up Desk", category: "Work", coinReward: 10),
        .init(title: "Plug In Laptop", category: "Work", coinReward: 5),
        .init(title: "Clear Desk Surface", category: "Work", coinReward: 10),
        .init(title: "Start Timer", category: "Work", coinReward: 5),
        .init(title: "File One Document", category: "Work", coinReward: 15),
        .init(title: "Send One Email", category: "Work", coinReward: 15),
        .init(title: "Update One Task Status", category: "Work", coinReward: 10),
        .init(title: "Close Work Tabs", category: "Work", coinReward: 10),
        .init(title: "Put Away Work Supplies", category: "Work", coinReward: 10),
        
        // MARK: - Study
        
        .init(title: "Study Session", category: "Study", coinReward: 30),
        .init(title: "Review Notes", category: "Study", coinReward: 20),
        .init(title: "Practice Problems", category: "Study", coinReward: 25),
        .init(title: "Read Lesson Material", category: "Study", coinReward: 25),
        .init(title: "Flashcard Review", category: "Study", coinReward: 20),
        .init(title: "Learning Recap", category: "Study", coinReward: 15),
        .init(title: "Open Study Material", category: "Study", coinReward: 5),
        .init(title: "Set Out Notebook", category: "Study", coinReward: 5),
        .init(title: "Write Five Notes", category: "Study", coinReward: 15),
        .init(title: "Read One Page", category: "Study", coinReward: 10),
        .init(title: "Answer One Question", category: "Study", coinReward: 10),
        .init(title: "Organize Study Supplies", category: "Study", coinReward: 15),
        .init(title: "Charge Tablet", category: "Study", coinReward: 5),
        .init(title: "Print Study Sheet", category: "Study", coinReward: 10),
        .init(title: "Put Book on Desk", category: "Study", coinReward: 5),
        .init(title: "Clean Study Area", category: "Study", coinReward: 15),
        
        // MARK: - Care
        
        .init(title: "Check In With Yourself", category: "Care", coinReward: 15),
        .init(title: "Do Something Comforting", category: "Care", coinReward: 20),
        .init(title: "Grounding Exercise", category: "Care", coinReward: 15),
        .init(title: "Step Outside", category: "Care", coinReward: 15),
        .init(title: "Message Someone Safe", category: "Care", coinReward: 15),
        .init(title: "Low-Energy Reset", category: "Care", coinReward: 20),
        .init(title: "Take a Quiet Break", category: "Care", coinReward: 10),
        .init(title: "Make Tea", category: "Care", coinReward: 10),
        .init(title: "Wrap Up in Blanket", category: "Care", coinReward: 5),
        .init(title: "Change Into Comfy Clothes", category: "Care", coinReward: 10),
        .init(title: "Put on Lotion", category: "Care", coinReward: 10),
        .init(title: "Read a Book", category: "Care", coinReward: 20),
        .init(title: "Watch your Favorite Show", category: "Care", coinReward: 10),
        .init(title: "Sit Somewhere Comfortable", category: "Care", coinReward: 5),
        .init(title: "Turn on Soft Lighting", category: "Care", coinReward: 5),
        .init(title: "Put Phone on Charger", category: "Care", coinReward: 5),
        .init(title: "Make Your Bed Cozy", category: "Care", coinReward: 10),
        .init(title: "Prepare a Comfort Snack", category: "Care", coinReward: 10),
        
        // MARK: - Spirituality
        
        .init(title: "Light a Candle", category: "Spirituality", coinReward: 10),
        .init(title: "Pull a Tarot Card", category: "Spirituality", coinReward: 15),
        .init(title: "Meditation", category: "Spirituality", coinReward: 25),
        .init(title: "Ground Your Energy", category: "Spirituality", coinReward: 15),
        .init(title: "Cleanse Your Space", category: "Spirituality", coinReward: 20),
        .init(title: "Daily Devotion", category: "Spirituality", coinReward: 25),
        .init(title: "Set Up Altar Space", category: "Spirituality", coinReward: 20),
        .init(title: "Light Incense", category: "Spirituality", coinReward: 10),
        .init(title: "Pour Offering Water", category: "Spirituality", coinReward: 10),
        .init(title: "Shuffle Tarot Deck", category: "Spirituality", coinReward: 5),
        .init(title: "Put Away Tarot Deck", category: "Spirituality", coinReward: 5),
        .init(title: "Ring a Bell", category: "Spirituality", coinReward: 5),
        .init(title: "Anoint Candle", category: "Spirituality", coinReward: 10),
        .init(title: "Cleanse Hands", category: "Spirituality", coinReward: 5),
        .init(title: "Place Crystal Nearby", category: "Spirituality", coinReward: 5),
        .init(title: "Tidy Spiritual Tools", category: "Spirituality", coinReward: 15),
        
        // MARK: - Relationships
        
        .init(title: "Text a Loved One", category: "Relationships", coinReward: 10),
        .init(title: "Quality Time", category: "Relationships", coinReward: 25),
        .init(title: "Pet Feeding", category: "Relationships", coinReward: 10),
        .init(title: "Dog Potty Trip", category: "Relationships", coinReward: 15),
        .init(title: "Pet Care Check", category: "Relationships", coinReward: 15),
        .init(title: "Plan Time Together", category: "Relationships", coinReward: 20),
        .init(title: "Fill Pet Bowl", category: "Relationships", coinReward: 10),
        .init(title: "Refresh Pet Water", category: "Relationships", coinReward: 10),
        .init(title: "Take Dog Outside", category: "Relationships", coinReward: 15),
        .init(title: "Clean Pet Bowl", category: "Relationships", coinReward: 15),
        .init(title: "Brush Pet", category: "Relationships", coinReward: 20),
        .init(title: "Give Pet Medication", category: "Relationships", coinReward: 20),
        .init(title: "Send Good Morning Text", category: "Relationships", coinReward: 5),
        .init(title: "Call Someone", category: "Relationships", coinReward: 20),
        .init(title: "Prepare Shared Snack", category: "Relationships", coinReward: 15),
        .init(title: "Set Up Quality Time", category: "Relationships", coinReward: 15),
        
        // MARK: - Finances
        
        .init(title: "Check Balance", category: "Finances", coinReward: 10),
        .init(title: "Pay Bill", category: "Finances", coinReward: 30),
        .init(title: "Review Budget", category: "Finances", coinReward: 25),
        .init(title: "Track Spending", category: "Finances", coinReward: 20),
        .init(title: "Grocery Budget Check", category: "Finances", coinReward: 15),
        .init(title: "Subscription Review", category: "Finances", coinReward: 25),
        .init(title: "Open Banking App", category: "Finances", coinReward: 5),
        .init(title: "Save Receipt", category: "Finances", coinReward: 10),
        .init(title: "Take Receipt Photo", category: "Finances", coinReward: 10),
        .init(title: "Put Cash Away", category: "Finances", coinReward: 10),
        .init(title: "Move Money to Savings", category: "Finances", coinReward: 20),
        .init(title: "Pay One Bill", category: "Finances", coinReward: 30),
        .init(title: "Check EBT Balance", category: "Finances", coinReward: 10),
        .init(title: "Update Grocery List", category: "Finances", coinReward: 15),
        .init(title: "Cancel One Subscription", category: "Finances", coinReward: 35),
        .init(title: "File Financial Paper", category: "Finances", coinReward: 15),
        
        // MARK: - Intention
        
        .init(title: "Set Daily Intention", category: "Intention", coinReward: 15),
        .init(title: "Review Today’s Focus", category: "Intention", coinReward: 15),
        .init(title: "Evening Reflection", category: "Intention", coinReward: 20),
        .init(title: "Choose Tomorrow’s Priority", category: "Intention", coinReward: 15),
        .init(title: "Reset Your Mindset", category: "Intention", coinReward: 15),
        .init(title: "Open Planner", category: "Intention", coinReward: 5),
        .init(title: "Write One Priority", category: "Intention", coinReward: 10),
        .init(title: "Place Planner on Desk", category: "Intention", coinReward: 5),
        .init(title: "Set Out Reminder Card", category: "Intention", coinReward: 5),
        .init(title: "Move One Task to Today", category: "Intention", coinReward: 10),
        .init(title: "Clear Yesterday’s Note", category: "Intention", coinReward: 10),
        .init(title: "Put Intention Note Nearby", category: "Intention", coinReward: 5),
        .init(title: "Open Notes App", category: "Intention", coinReward: 5),
        .init(title: "Write Tomorrow’s Priority", category: "Intention", coinReward: 10),
        .init(title: "Close Planner", category: "Intention", coinReward: 5),
        
        // MARK: - Productivity
        
        .init(title: "Plan Top Tasks", category: "Productivity", coinReward: 20),
        .init(title: "Clear Inbox", category: "Productivity", coinReward: 25),
        .init(title: "Organize Task List", category: "Productivity", coinReward: 20),
        .init(title: "Start Focus Timer", category: "Productivity", coinReward: 10),
        .init(title: "Review Progress", category: "Productivity", coinReward: 15),
        .init(title: "Prepare Tomorrow", category: "Productivity", coinReward: 20),
        .init(title: "Open Task List", category: "Productivity", coinReward: 5),
        .init(title: "Move One Item Forward", category: "Productivity", coinReward: 10),
        .init(title: "Delete One Old Task", category: "Productivity", coinReward: 10),
        .init(title: "Set One Reminder", category: "Productivity", coinReward: 10),
        .init(title: "Start One Timer", category: "Productivity", coinReward: 5),
        .init(title: "Put Supplies in One Place", category: "Productivity", coinReward: 10),
        .init(title: "Clear One Surface", category: "Productivity", coinReward: 10),
        .init(title: "Open Calendar", category: "Productivity", coinReward: 5),
        .init(title: "Add One Calendar Event", category: "Productivity", coinReward: 15),
        .init(title: "Close Finished Apps", category: "Productivity", coinReward: 10),
        
        // MARK: - Habits
        
        .init(title: "Habit Check-In", category: "Habits", coinReward: 15),
        .init(title: "Track Daily Habit", category: "Habits", coinReward: 15),
        .init(title: "Habit Reset", category: "Habits", coinReward: 20),
        .init(title: "Streak Review", category: "Habits", coinReward: 15),
        .init(title: "Build One Small Habit", category: "Habits", coinReward: 25),
        .init(title: "Put Habit Item in View", category: "Habits", coinReward: 5),
        .init(title: "Check Off Habit", category: "Habits", coinReward: 10),
        .init(title: "Set Habit Supplies Out", category: "Habits", coinReward: 10),
        .init(title: "Do Habit for Two Minutes", category: "Habits", coinReward: 15),
        .init(title: "Prepare Habit Space", category: "Habits", coinReward: 10),
        .init(title: "Move Habit Card to Top", category: "Habits", coinReward: 5),
        .init(title: "Refill Habit Supplies", category: "Habits", coinReward: 15),
        .init(title: "Reset Habit Tracker", category: "Habits", coinReward: 15),
        .init(title: "Put Habit Reminder Nearby", category: "Habits", coinReward: 5),
        .init(title: "Clean Up After Habit", category: "Habits", coinReward: 10),
        
        // MARK: - Hygiene
        
        .init(title: "Brush Teeth", category: "Hygiene", coinReward: 10),
        .init(title: "Wash Face", category: "Hygiene", coinReward: 10),
        .init(title: "Moisturize", category: "Hygiene", coinReward: 10),
        .init(title: "Shower", category: "Hygiene", coinReward: 30),
        .init(title: "Brush Hair", category: "Hygiene", coinReward: 10),
        .init(title: "Change Clothes", category: "Hygiene", coinReward: 15),
        .init(title: "Skincare Routine", category: "Hygiene", coinReward: 20),
        .init(title: "Put Toothbrush Out", category: "Hygiene", coinReward: 5),
        .init(title: "Floss Teeth", category: "Hygiene", coinReward: 10),
        .init(title: "Apply Deodorant", category: "Hygiene", coinReward: 10),
        .init(title: "Change Underwear", category: "Hygiene", coinReward: 10),
        .init(title: "Wash Hands", category: "Hygiene", coinReward: 5),
        .init(title: "Clip Nails", category: "Hygiene", coinReward: 15),
        .init(title: "Apply Acne Cream", category: "Hygiene", coinReward: 10),
        .init(title: "Put Hair Up", category: "Hygiene", coinReward: 5),
        .init(title: "Lay Out Clean Clothes", category: "Hygiene", coinReward: 10),
        .init(title: "Clean Glasses", category: "Hygiene", coinReward: 5),
        
        
        // MARK: - Creativity
        
        .init(title: "Creative Session", category: "Creativity", coinReward: 30),
        .init(title: "Design Time", category: "Creativity", coinReward: 30),
        .init(title: "Writing Session", category: "Creativity", coinReward: 30),
        .init(title: "Brainstorm Ideas", category: "Creativity", coinReward: 20),
        .init(title: "Update Project Notes", category: "Creativity", coinReward: 15),
        .init(title: "Practice a Skill", category: "Creativity", coinReward: 25),
        .init(title: "Open Canva", category: "Creativity", coinReward: 5),
        .init(title: "Set Up Art Supplies", category: "Creativity", coinReward: 10),
        .init(title: "Save One Design", category: "Creativity", coinReward: 15),
        .init(title: "Export One Image", category: "Creativity", coinReward: 15),
        .init(title: "Sketch One Idea", category: "Creativity", coinReward: 15),
        .init(title: "Organize Design Files", category: "Creativity", coinReward: 20),
        .init(title: "Choose a Color Palette", category: "Creativity", coinReward: 10),
        .init(title: "Open Writing Draft", category: "Creativity", coinReward: 5),
        .init(title: "Write One Paragraph", category: "Creativity", coinReward: 15),
        .init(title: "Clean Creative Space", category: "Creativity", coinReward: 15)
    ]
}

// MARK: - Helpers

extension LureliaTaskBank {
    
    static var categories: [String] {
        Array(Set(allItems.map(\.category))).sorted()
    }
    
    static func items(for category: String) -> [LureliaTaskBankItem] {
        allItems
            .filter { $0.category == category }
            .sorted { $0.title < $1.title }
    }
    
    static func items(for categories: [String]) -> [LureliaTaskBankItem] {
        allItems
            .filter { categories.contains($0.category) }
            .sorted {
                if $0.category == $1.category {
                    return $0.title < $1.title
                }
                
                return $0.category < $1.category
            }
    }
    
    static func search(
        _ query: String,
        within categories: [String]? = nil
    ) -> [LureliaTaskBankItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let baseItems: [LureliaTaskBankItem]
        
        if let categories {
            baseItems = items(for: categories)
        } else {
            baseItems = allItems
        }
        
        guard !trimmedQuery.isEmpty else {
            return baseItems
        }
        
        return baseItems.filter {
            $0.title.localizedCaseInsensitiveContains(trimmedQuery)
            || $0.category.localizedCaseInsensitiveContains(trimmedQuery)
            || ($0.notes?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
        }
    }
}
