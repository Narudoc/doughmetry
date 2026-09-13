import Foundation

/// 사워도우 도메인 모델 — 웹앱(Doughmetry, 저장소 `doughmetry`)의 JSON 스키마 v2와 완전 호환.
/// 인코딩/디코딩 키·값이 웹의 localStorage/내보내기 형식과 일치해야 한다.

public enum LevainType: String, Codable, Sendable, CaseIterable {
    case liquide
    case dur
}

public enum YeastType: String, Codable, Sendable, CaseIterable {
    case fresh
    case instant
}

public struct Flour: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var grams: Double

    public init(id: String = newId(), name: String, grams: Double) {
        self.id = id
        self.name = name
        self.grams = grams
    }
}

public struct Extra: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var grams: Double

    public init(id: String = newId(), name: String, grams: Double) {
        self.id = id
        self.name = name
        self.grams = grams
    }
}

/// 수분을 포함한 액체 재료 (우유, 계란 등). waterRatio는 소수 (0.88 = 88%)
public struct Liquid: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var grams: Double
    public var waterRatio: Double

    public init(id: String = newId(), name: String, grams: Double, waterRatio: Double) {
        self.id = id
        self.name = name
        self.grams = grams
        self.waterRatio = waterRatio
    }
}

/// 이스트 — grams는 선택한 타입 기준의 실제 투입량. 0 = 사용 안 함
public struct Yeast: Codable, Equatable, Sendable {
    public var type: YeastType
    public var grams: Double

    public init(type: YeastType = .fresh, grams: Double = 0) {
        self.type = type
        self.grams = grams
    }
}

public struct Levain: Codable, Equatable, Sendable {
    public var type: LevainType
    /// 르방 수분율, 소수 (liquide 기본 1.0 / dur 기본 0.5)
    public var hydration: Double
    public var grams: Double
    /// 표시용
    public var flourName: String?

    public init(type: LevainType, hydration: Double, grams: Double, flourName: String? = nil) {
        self.type = type
        self.hydration = hydration
        self.grams = grams
        self.flourName = flourName
    }
}

/// 계산 입력 — 웹의 DoughInput과 동일
public struct DoughInput: Codable, Equatable, Sendable {
    public var flours: [Flour]
    public var water: Double
    public var bassinage: Double
    public var salt: Double
    public var levain: Levain
    public var liquids: [Liquid]
    public var yeast: Yeast
    public var extras: [Extra]

    public init(
        flours: [Flour],
        water: Double,
        bassinage: Double = 0,
        salt: Double,
        levain: Levain,
        liquids: [Liquid] = [],
        yeast: Yeast = Yeast(),
        extras: [Extra] = []
    ) {
        self.flours = flours
        self.water = water
        self.bassinage = bassinage
        self.salt = salt
        self.levain = levain
        self.liquids = liquids
        self.yeast = yeast
        self.extras = extras
    }
}

/// 저장 레시피 — 웹 스키마 v2와 JSON 호환 (내보내기/가져오기 왕복 가능)
public struct Recipe: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var schemaVersion: Int
    public var name: String
    public var note: String?
    public var tags: [String]?
    public var createdAt: String // ISO 8601
    public var updatedAt: String
    public var flours: [Flour]
    public var water: Double
    public var bassinage: Double
    public var salt: Double
    public var levain: Levain
    public var liquids: [Liquid]
    public var yeast: Yeast
    public var extras: [Extra]
    public var targetDoughWeight: Double?
    public var pieces: Double?

    public init(
        id: String = newId(),
        name: String,
        note: String? = nil,
        tags: [String]? = nil,
        createdAt: String,
        updatedAt: String,
        input: DoughInput,
        targetDoughWeight: Double? = nil,
        pieces: Double? = nil
    ) {
        self.id = id
        self.schemaVersion = 2
        self.name = name
        self.note = note
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.flours = input.flours
        self.water = input.water
        self.bassinage = input.bassinage
        self.salt = input.salt
        self.levain = input.levain
        self.liquids = input.liquids
        self.yeast = input.yeast
        self.extras = input.extras
        self.targetDoughWeight = targetDoughWeight
        self.pieces = pieces
    }

    public var doughInput: DoughInput {
        DoughInput(
            flours: flours, water: water, bassinage: bassinage, salt: salt,
            levain: levain, liquids: liquids, yeast: yeast, extras: extras
        )
    }
}

public func newId() -> String {
    UUID().uuidString.lowercased()
}

// MARK: - 베이킹 로그 · 라이브러리 문서 (iOS 전용, 웹 레시피 스키마와 별개)

/// 레시피별 "구운 기록" — 날짜·별점·메모
public struct BakeLog: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var recipeId: String
    public var bakedAt: String // ISO 8601
    /// 1...5, 없으면 nil
    public var rating: Int?
    public var note: String
    public var createdAt: String
    public var updatedAt: String

    public init(
        id: String = newId(),
        recipeId: String,
        bakedAt: String,
        rating: Int? = nil,
        note: String = "",
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.recipeId = recipeId
        self.bakedAt = bakedAt
        self.rating = rating
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// 삭제 기록 — 기기 간 동기화에서 "지운 것이 되살아나는" 문제를 막는다
public struct Tombstone: Codable, Equatable, Sendable {
    public var id: String
    public var deletedAt: String

    public init(id: String, deletedAt: String) {
        self.id = id
        self.deletedAt = deletedAt
    }
}

/// 저장소 봉투 — 로컬 library.json과 iCloud 사본이 같은 형식을 쓴다.
/// `recipes` 키를 그대로 두어 웹 가져오기(importJSON)에서도 읽힌다.
public struct LibraryDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var recipes: [Recipe]
    public var logs: [BakeLog]
    public var deleted: [Tombstone]

    public init(
        schemaVersion: Int = LibraryDocument.currentSchemaVersion,
        recipes: [Recipe] = [],
        logs: [BakeLog] = [],
        deleted: [Tombstone] = []
    ) {
        self.schemaVersion = schemaVersion
        self.recipes = recipes
        self.logs = logs
        self.deleted = deleted
    }

    public var isEmpty: Bool { recipes.isEmpty && logs.isEmpty && deleted.isEmpty }
}
