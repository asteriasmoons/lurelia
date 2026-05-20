//
//  LureliaIconLibrary.swift
//  Lurelia
//

import SwiftUI

// MARK: - Icon Source

enum LureliaIconSource: String, Codable, CaseIterable {
    case asset
    case sfSymbol
}

// MARK: - Icon Item

struct LureliaIconItem: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let source: LureliaIconSource
    let category: String
    
    init(
        name: String,
        source: LureliaIconSource,
        category: String
    ) {
        self.id = "\(source.rawValue)-\(name)"
        self.name = name
        self.source = source
        self.category = category
    }
    
    @ViewBuilder
    var image: some View {
        switch source {
        case .asset:
            Image(name)
                .resizable()
                .scaledToFit()
            
        case .sfSymbol:
            Image(systemName: name)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

// MARK: - Icon Library

enum LureliaIconLibrary {
    
    // MARK: - SF Symbols
    
    static let sfSymbols: [LureliaIconItem] = [
        .init(name: "bell.fill", source: .sfSymbol, category: "Reminders"),
        .init(name: "bell.badge.fill", source: .sfSymbol, category: "Reminders"),
        .init(name: "calendar", source: .sfSymbol, category: "Schedule"),
        .init(name: "calendar.badge.clock", source: .sfSymbol, category: "Schedule"),
        .init(name: "clock.fill", source: .sfSymbol, category: "Time"),
        .init(name: "timer", source: .sfSymbol, category: "Time"),
        .init(name: "hourglass", source: .sfSymbol, category: "Time"),
        .init(name: "checkmark.circle.fill", source: .sfSymbol, category: "Tasks"),
        .init(name: "checklist", source: .sfSymbol, category: "Tasks"),
        .init(name: "list.bullet.clipboard.fill", source: .sfSymbol, category: "Tasks"),
        .init(name: "sparkles", source: .sfSymbol, category: "Magic"),
        .init(name: "wand.and.stars", source: .sfSymbol, category: "Magic"),
        .init(name: "moon.stars.fill", source: .sfSymbol, category: "Magic"),
        .init(name: "star.fill", source: .sfSymbol, category: "Favorites"),
        .init(name: "heart.fill", source: .sfSymbol, category: "Care"),
        .init(name: "heart.text.square.fill", source: .sfSymbol, category: "Care"),
        .init(name: "house.fill", source: .sfSymbol, category: "Home"),
        .init(name: "bed.double.fill", source: .sfSymbol, category: "Home"),
        .init(name: "sofa.fill", source: .sfSymbol, category: "Home"),
        .init(name: "shower.fill", source: .sfSymbol, category: "Home"),
        .init(name: "washer.fill", source: .sfSymbol, category: "Cleaning"),
        .init(name: "basket.fill", source: .sfSymbol, category: "Shopping"),
        .init(name: "cart.fill", source: .sfSymbol, category: "Shopping"),
        .init(name: "pills.fill", source: .sfSymbol, category: "Health"),
        .init(name: "cross.case.fill", source: .sfSymbol, category: "Health"),
        .init(name: "stethoscope", source: .sfSymbol, category: "Health"),
        .init(name: "book.fill", source: .sfSymbol, category: "Reading"),
        .init(name: "bookmark.fill", source: .sfSymbol, category: "Reading"),
        .init(name: "paintbrush.fill", source: .sfSymbol, category: "Creative"),
        .init(name: "pencil.and.outline", source: .sfSymbol, category: "Creative"),
        .init(name: "calendar.badge.plus", source: .sfSymbol, category: "Schedule"),
        .init(name: "calendar.badge.checkmark", source: .sfSymbol, category: "Schedule"),
        .init(name: "calendar.day.timeline.left", source: .sfSymbol, category: "Schedule"),
        .init(name: "alarm.fill", source: .sfSymbol, category: "Time"),
        .init(name: "stopwatch.fill", source: .sfSymbol, category: "Time"),
        .init(name: "repeat", source: .sfSymbol, category: "Reminders"),
        .init(name: "arrow.triangle.2.circlepath", source: .sfSymbol, category: "Reminders"),
        .init(name: "plus.circle.fill", source: .sfSymbol, category: "Actions"),
        .init(name: "xmark.circle.fill", source: .sfSymbol, category: "Actions"),
        .init(name: "trash.fill", source: .sfSymbol, category: "Actions"),
        .init(name: "square.and.pencil", source: .sfSymbol, category: "Writing"),
        .init(name: "note.text", source: .sfSymbol, category: "Notes"),
        .init(name: "doc.text.fill", source: .sfSymbol, category: "Documents"),
        .init(name: "folder.fill", source: .sfSymbol, category: "Documents"),
        .init(name: "tag.fill", source: .sfSymbol, category: "Tags"),
        .init(name: "link", source: .sfSymbol, category: "Links"),
        .init(name: "magnifyingglass", source: .sfSymbol, category: "Search"),
        .init(name: "person.fill", source: .sfSymbol, category: "Profile"),
        .init(name: "person.2.fill", source: .sfSymbol, category: "People"),
        .init(name: "gearshape.fill", source: .sfSymbol, category: "Settings"),
        .init(name: "lock.fill", source: .sfSymbol, category: "Security"),
        .init(name: "key.fill", source: .sfSymbol, category: "Security"),
        .init(name: "creditcard.fill", source: .sfSymbol, category: "Money"),
        .init(name: "dollarsign.circle.fill", source: .sfSymbol, category: "Money"),
        .init(name: "chart.bar.fill", source: .sfSymbol, category: "Stats"),
        .init(name: "chart.line.uptrend.xyaxis", source: .sfSymbol, category: "Stats"),
        .init(name: "drop.fill", source: .sfSymbol, category: "Hydration"),
        .init(name: "flame.fill", source: .sfSymbol, category: "Energy"),
        .init(name: "bolt.fill", source: .sfSymbol, category: "Energy"),
        .init(name: "gift.fill", source: .sfSymbol, category: "Rewards")
    ]
    
    // MARK: - Custom Asset Icons
    
    static let assetIcons: [LureliaIconItem] = [
        .init(name: "spraybottle", source: .asset, category: "Cleaning"),
        .init(name: "bucket", source: .asset, category: "Cleaning"),
        .init(name: "towel", source: .asset, category: "Cleaning"),
        .init(name: "bed", source: .asset, category: "Home"),
        .init(name: "tproll", source: .asset, category: "Bathroom"),
        .init(name: "toiletpaper", source: .asset, category: "Bathroom"),
        .init(name: "pillows", source: .asset, category: "Bedroom"),
        .init(name: "drawers", source: .asset, category: "Bedroom"),
        .init(name: "window", source: .asset, category: "Home"),
        .init(name: "armchair", source: .asset, category: "Living Room"),
        .init(name: "flatscreen", source: .asset, category: "Living Room"),
        .init(name: "teapot", source: .asset, category: "Kitchen"),
        .init(name: "sofa", source: .asset, category: "Living Room"),
        .init(name: "shower", source: .asset, category: "Bathroom"),
        .init(name: "cellphone", source: .asset, category: "Tech"),
        .init(name: "rainbow", source: .asset, category: "Whimsy"),
        .init(name: "vanity", source: .asset, category: "Self Care"),
        .init(name: "heartbox", source: .asset, category: "Care"),
        .init(name: "lovedocs", source: .asset, category: "Documents"),
        .init(name: "laundry", source: .asset, category: "Cleaning"),
        .init(name: "groceries", source: .asset, category: "Shopping"),
        .init(name: "fireplace", source: .asset, category: "Home"),
        .init(name: "coffeemaker", source: .asset, category: "Kitchen"),
        .init(name: "bandaidheart", source: .asset, category: "Health"),
        .init(name: "clockwavy", source: .asset, category: "Time"),
        .init(name: "skipwavy", source: .asset, category: "Actions"),
        .init(name: "starwindow", source: .asset, category: "Whimsy"),
        .init(name: "market", source: .asset, category: "Shopping"),
        .init(name: "washer", source: .asset, category: "Cleaning"),
        .init(name: "xoxocal", source: .asset, category: "Schedule"),
        .init(name: "windowheart", source: .asset, category: "Home"),
        .init(name: "walletfill", source: .asset, category: "Money"),
        .init(name: "calhearts", source: .asset, category: "Schedule"),
        .init(name: "circlefingerprint", source: .asset, category: "Security"),
        .init(name: "circlescal", source: .asset, category: "Schedule"),
        .init(name: "fingerprint", source: .asset, category: "Security"),
        .init(name: "handbook", source: .asset, category: "Reading"),
        .init(name: "handkey", source: .asset, category: "Security"),
        .init(name: "hearttag", source: .asset, category: "Tags"),
        .init(name: "hourglassfill", source: .asset, category: "Time"),
        .init(name: "lineimagepage", source: .asset, category: "Documents"),
        .init(name: "linenotepage", source: .asset, category: "Notes"),
        .init(name: "linescard", source: .asset, category: "Documents"),
        .init(name: "linespiralbook", source: .asset, category: "Reading"),
        .init(name: "lockheartjournal", source: .asset, category: "Journal"),
        .init(name: "lockhearts", source: .asset, category: "Security"),
        .init(name: "luvemail", source: .asset, category: "Communication"),
        .init(name: "luvmail", source: .asset, category: "Communication"),
        .init(name: "moneybaghands", source: .asset, category: "Money"),
        .init(name: "pigbank", source: .asset, category: "Money"),
        .init(name: "play", source: .asset, category: "Actions"),
        .init(name: "sparkle", source: .asset, category: "Whimsy"),
        .init(name: "starnote", source: .asset, category: "Notes"),
        .init(name: "starpopgift", source: .asset, category: "Rewards"),
        .init(name: "sticknote", source: .asset, category: "Notes"),
        .init(name: "tagsparkle", source: .asset, category: "Tags"),
        .init(name: "television", source: .asset, category: "Living Room"),
        .init(name: "threecoins", source: .asset, category: "Money"),
        .init(name: "numcal", source: .asset, category: "Schedule"),
        .init(name: "deadcat", source: .asset, category: "Misc"),
        .init(name: "mailbox", source: .asset, category: "Communication"),
        .init(name: "bells", source: .asset, category: "Reminders"),
        .init(name: "blocks", source: .asset, category: "Objects"),
        .init(name: "writepencil", source: .asset, category: "Writing"),
        .init(name: "micfill", source: .asset, category: "Audio"),
        .init(name: "lovecalendar", source: .asset, category: "Schedule"),
        .init(name: "stopwavy", source: .asset, category: "Actions"),
        .init(name: "infowavy", source: .asset, category: "Info"),
        .init(name: "document", source: .asset, category: "Documents"),
        .init(name: "instagram", source: .asset, category: "Social"),
        .init(name: "discord", source: .asset, category: "Social"),
        .init(name: "threads", source: .asset, category: "Social"),
        .init(name: "facebook", source: .asset, category: "Social"),
        .init(name: "github", source: .asset, category: "Developer"),
        .init(name: "flatbook", source: .asset, category: "Reading"),
        .init(name: "blocksfill", source: .asset, category: "Objects"),
        .init(name: "halfheart", source: .asset, category: "Care"),
        .init(name: "chatsparkle", source: .asset, category: "Communication"),
        .init(name: "medication", source: .asset, category: "Health"),
        .init(name: "objects", source: .asset, category: "Objects"),
        .init(name: "paintbrush", source: .asset, category: "Creative"),
        .init(name: "linespencil", source: .asset, category: "Writing"),
        .init(name: "sparklebrush", source: .asset, category: "Creative"),
        .init(name: "paintdrop", source: .asset, category: "Creative"),
        .init(name: "crossroads", source: .asset, category: "Navigation"),
        .init(name: "cardlines", source: .asset, category: "Documents"),
        .init(name: "imagesign", source: .asset, category: "Images"),
        .init(name: "pbrush", source: .asset, category: "Creative"),
        .init(name: "lovedocslines", source: .asset, category: "Documents"),
        .init(name: "buggy", source: .asset, category: "Developer"),
        .init(name: "lovelist", source: .asset, category: "Tasks"),
        .init(name: "shopbasket", source: .asset, category: "Shopping"),
        .init(name: "starhand", source: .asset, category: "Care"),
        .init(name: "codewindow", source: .asset, category: "Developer"),
        .init(name: "artboard", source: .asset, category: "Creative"),
        .init(name: "moonzs", source: .asset, category: "Rest"),
        .init(name: "startrophy", source: .asset, category: "Rewards"),
        .init(name: "groupfill", source: .asset, category: "People"),
        .init(name: "chatlinesfill", source: .asset, category: "Communication"),
        .init(name: "sparkbolt", source: .asset, category: "Energy"),
        .init(name: "openbook", source: .asset, category: "Reading"),
        .init(name: "blackwindow", source: .asset, category: "Home"),
        .init(name: "tarotcards", source: .asset, category: "Spirituality"),
        .init(name: "lovedate", source: .asset, category: "Schedule"),
        .init(name: "lovecards", source: .asset, category: "Care"),
        .init(name: "plainpencil", source: .asset, category: "Writing"),
        .init(name: "starlinesdoc", source: .asset, category: "Documents"),
        .init(name: "blankpages", source: .asset, category: "Documents"),
        .init(name: "lovejournal", source: .asset, category: "Journal"),
        .init(name: "grimoire", source: .asset, category: "Spirituality"),
        .init(name: "tarot", source: .asset, category: "Spirituality"),
        .init(name: "lovetv", source: .asset, category: "Living Room"),
        .init(name: "pinnednote", source: .asset, category: "Notes"),
        .init(name: "loveairballoon", source: .asset, category: "Whimsy"),
        .init(name: "starshand", source: .asset, category: "Care"),
        .init(name: "starmark", source: .asset, category: "Favorites"),
        .init(name: "timehand", source: .asset, category: "Time"),
        .init(name: "timebook", source: .asset, category: "Time"),
        .init(name: "staroutline", source: .asset, category: "Favorites"),
        .init(name: "heartcircle", source: .asset, category: "Care"),
        .init(name: "checkwavy", source: .asset, category: "Tasks"),
        .init(name: "starcircle", source: .asset, category: "Favorites"),
        .init(name: "sparklecircle", source: .asset, category: "Whimsy"),
        .init(name: "profilewavy", source: .asset, category: "Profile"),
        .init(name: "bellfill", source: .asset, category: "Reminders"),
        .init(name: "chevleft", source: .asset, category: "Navigation"),
        .init(name: "dotscal", source: .asset, category: "Schedule"),
        .init(name: "linedpages", source: .asset, category: "Documents"),
        .init(name: "flame", source: .asset, category: "Energy"),
        .init(name: "chevup", source: .asset, category: "Navigation"),
        .init(name: "chevdown", source: .asset, category: "Navigation"),
        .init(name: "heartfill", source: .asset, category: "Care"),
        .init(name: "stethoscope", source: .asset, category: "Health"),
        .init(name: "copy", source: .asset, category: "Actions"),
        .init(name: "xsmile", source: .asset, category: "Mood"),
        .init(name: "chartcircle", source: .asset, category: "Stats"),
        .init(name: "addwavy", source: .asset, category: "Actions"),
        .init(name: "shoe", source: .asset, category: "Movement"),
        .init(name: "glass", source: .asset, category: "Hydration"),
        .init(name: "chevright", source: .asset, category: "Navigation"),
        .init(name: "plusheart", source: .asset, category: "Care"),
        .init(name: "heartballoon", source: .asset, category: "Whimsy"),
        .init(name: "sunflower", source: .asset, category: "Nature"),
        .init(name: "dumbbell", source: .asset, category: "Movement"),
        .init(name: "medhand", source: .asset, category: "Health"),
        .init(name: "houseoutline", source: .asset, category: "Home"),
        .init(name: "boltsparkle", source: .asset, category: "Energy"),
        .init(name: "goalsparkle", source: .asset, category: "Goals"),
        .init(name: "dropfill", source: .asset, category: "Hydration"),
        .init(name: "blackcal", source: .asset, category: "Schedule"),
        .init(name: "medhouse", source: .asset, category: "Health"),
        .init(name: "heartwavy", source: .asset, category: "Care"),
        .init(name: "cloudmind", source: .asset, category: "Mind"),
        .init(name: "crystalball", source: .asset, category: "Spirituality"),
        .init(name: "wand", source: .asset, category: "Spirituality"),
        .init(name: "pausewavy", source: .asset, category: "Actions"),
        .init(name: "balancewavy", source: .asset, category: "Wellness"),
        .init(name: "trash", source: .asset, category: "Actions"),
        .init(name: "planet", source: .asset, category: "Spirituality"),
        .init(name: "lovelocation", source: .asset, category: "Location"),
        .init(name: "pagefold", source: .asset, category: "Documents"),
        .init(name: "linkcircle", source: .asset, category: "Links"),
        .init(name: "aries", source: .asset, category: "Zodiac"),
        .init(name: "aquarius", source: .asset, category: "Zodiac"),
        .init(name: "cancer", source: .asset, category: "Zodiac"),
        .init(name: "capricorn", source: .asset, category: "Zodiac"),
        .init(name: "gemini", source: .asset, category: "Zodiac"),
        .init(name: "leo", source: .asset, category: "Zodiac"),
        .init(name: "libra", source: .asset, category: "Zodiac"),
        .init(name: "pisces", source: .asset, category: "Zodiac"),
        .init(name: "sagittarius", source: .asset, category: "Zodiac"),
        .init(name: "scorpio", source: .asset, category: "Zodiac"),
        .init(name: "taurus", source: .asset, category: "Zodiac"),
        .init(name: "virgo", source: .asset, category: "Zodiac"),
        .init(name: "trophycircle", source: .asset, category: "Rewards"),
        .init(name: "pencilcircle", source: .asset, category: "Writing"),
        .init(name: "listcircle", source: .asset, category: "Tasks"),
        .init(name: "markcircle", source: .asset, category: "Tasks"),
        .init(name: "bookstand", source: .asset, category: "Reading"),
        .init(name: "health", source: .asset, category: "Health"),
        .init(name: "heartpulse", source: .asset, category: "Health"),
        .init(name: "hearthand", source: .asset, category: "Care"),
        .init(name: "levelup", source: .asset, category: "Rewards"),
        .init(name: "starry", source: .asset, category: "Whimsy"),
        .init(name: "starcal", source: .asset, category: "Schedule"),
        .init(name: "bookmark", source: .asset, category: "Reading"),
        .init(name: "starshield", source: .asset, category: "Protection"),
        .init(name: "bolt", source: .asset, category: "Energy"),
        .init(name: "playwavy", source: .asset, category: "Actions"),
        .init(name: "starcard", source: .asset, category: "Favorites"),
        .init(name: "pilldrop", source: .asset, category: "Health"),
        .init(name: "hashtag", source: .asset, category: "Tags"),
        .init(name: "pillhand", source: .asset, category: "Health"),
        .init(name: "medsymbol", source: .asset, category: "Health"),
        .init(name: "dotswavy", source: .asset, category: "Navigation"),
        .init(name: "heartsum", source: .asset, category: "Care"),
        .init(name: "heartlock", source: .asset, category: "Security"),
        .init(name: "clockfill", source: .asset, category: "Time"),
        .init(name: "bubbles", source: .asset, category: "Cleaning"),
        .init(name: "xmarkwavy", source: .asset, category: "Actions"),
        .init(name: "bottle", source: .asset, category: "Hydration"),
        .init(name: "heartoutline", source: .asset, category: "Care"),
        .init(name: "flipnotebook", source: .asset, category: "Notes"),
        .init(name: "writenote", source: .asset, category: "Writing"),
        .init(name: "pin", source: .asset, category: "Actions"),
        .init(name: "medical", source: .asset, category: "Health"),
        .init(name: "starfill", source: .asset, category: "Favorites"),
        .init(name: "slider", source: .asset, category: "Settings"),
        .init(name: "cake", source: .asset, category: "Celebration"),
        .init(name: "bdaycake", source: .asset, category: "Celebration"),
        .init(name: "store", source: .asset, category: "Shopping"),
        .init(name: "handbuggy", source: .asset, category: "Shopping"),
        .init(name: "sign", source: .asset, category: "Objects"),
        .init(name: "monies", source: .asset, category: "Money"),
        .init(name: "heartsparkle", source: .asset, category: "Care"),
        .init(name: "lovetag", source: .asset, category: "Tags"),
        .init(name: "twinhearts", source: .asset, category: "Care"),
        .init(name: "starphone", source: .asset, category: "Communication"),
        .init(name: "heartphone", source: .asset, category: "Communication"),
        .init(name: "lovehouse", source: .asset, category: "Home"),
        .init(name: "loveflame", source: .asset, category: "Energy"),
        .init(name: "fingersheart", source: .asset, category: "Care"),
        .init(name: "tagstar", source: .asset, category: "Tags"),
        .init(name: "dogstore", source: .asset, category: "Pets"),
        .init(name: "vet", source: .asset, category: "Pets"),
        .init(name: "catface", source: .asset, category: "Pets"),
        .init(name: "catstretch", source: .asset, category: "Pets"),
        .init(name: "catsleep", source: .asset, category: "Pets"),
        .init(name: "dogface", source: .asset, category: "Pets"),
        .init(name: "inbox", source: .asset, category: "Organization"),
        .init(name: "kennel", source: .asset, category: "Pets"),
        .init(name: "paw", source: .asset, category: "Pets"),
        .init(name: "petpaw", source: .asset, category: "Pets"),
        .init(name: "petfood", source: .asset, category: "Pets"),
        .init(name: "petmeds", source: .asset, category: "Pets"),
        .init(name: "sun", source: .asset, category: "Nature")
    ]
    
    // MARK: - Combined Library
    
    static let allIcons: [LureliaIconItem] = assetIcons + sfSymbols
    
    static var categories: [String] {
        Array(Set(allIcons.map(\.category))).sorted()
    }
    
    static func icons(in category: String) -> [LureliaIconItem] {
        allIcons.filter { $0.category == category }
    }
    
    static func search(_ query: String) -> [LureliaIconItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            return allIcons
        }
        
        return allIcons.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
            || $0.category.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
}
