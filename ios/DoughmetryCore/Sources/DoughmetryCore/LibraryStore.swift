import Foundation

/// 기기 안 라이브러리 파일 — `directory`/library.json (LibraryDocument, iCloud 사본과 같은 형식).
/// 옛 형식 recipes.json(레시피 배열)은 library.json이 없을 때 한 번 이전한다.
///
/// 사용자 데이터는 지우지 않는다: JSON이 아닌 library.json은 library.corrupt-<시각>.json으로 치우고,
/// 검증에서 항목이 버려지는 원본은 library.dropped-<시각>.json으로 복사해 둔다 —
/// 그대로 두면 다음 저장이 그 데이터를 영구히 덮어쓴다.
public struct LibraryStore: Sendable {
    public let directory: URL
    /// 손상된 library.json을 치우지 못했다 — 덮어쓰면 되찾을 길이 없으므로 이 저장소로는 쓰지 않는다
    public private(set) var isWriteBlocked = false

    public init(directory: URL) {
        self.directory = directory
    }

    public var libraryURL: URL { directory.appendingPathComponent("library.json") }
    var legacyRecipesURL: URL { directory.appendingPathComponent("recipes.json") }

    public enum StoreError: Error {
        /// isWriteBlocked — 치우지 못한 손상 파일을 덮어쓰지 않으려고 쓰기를 거절했다
        case corruptOriginalNotSetAside
    }

    /// 불러오기 결과 — 파일 작업이 실패해도 불러오기는 계속하고, 호출 측은 진단 기록에 쓴다
    public struct LoadResult {
        public var document = LibraryDocument()
        /// 손상된 library.json을 치워 둔 사본
        public var corruptSetAside: URL?
        /// 손상된 library.json을 치우지 못한 오류 (그래서 isWriteBlocked)
        public var corruptSetAsideError: (any Error)?
        /// 검증에서 버려진 레시피·로그·묘비 수
        public var droppedItemCount = 0
        /// 버려진 항목이 든 원본을 이번에 새로 보관한 사본 (같은 내용이 이미 있으면 nil)
        public var droppedOriginalKept: URL?
        public var droppedOriginalError: (any Error)?
        /// 옛 recipes.json을 읽어 library.json으로 옮겼다 (쓰기 실패는 migrationWriteError)
        public var migratedLegacy = false
        public var migrationWriteError: (any Error)?
    }

    public mutating func load(now: Date = Date()) -> LoadResult {
        var result = LoadResult()
        let fm = FileManager.default
        if let data = try? Data(contentsOf: libraryURL) {
            if (try? JSONSerialization.jsonObject(with: data)) == nil {
                let aside = directory.appendingPathComponent("library.corrupt-\(Int(now.timeIntervalSince1970)).json")
                do {
                    try fm.moveItem(at: libraryURL, to: aside)
                    result.corruptSetAside = aside
                } catch {
                    result.corruptSetAsideError = error
                    isWriteBlocked = true
                }
            } else {
                result.document = LibrarySync.decode(data)
                result.droppedItemCount = LibrarySync.droppedItemCount(in: data, decoded: result.document)
                if result.droppedItemCount > 0 {
                    do {
                        result.droppedOriginalKept = try keepDroppedOriginal(data, now: now)
                    } catch {
                        result.droppedOriginalError = error
                    }
                }
            }
        } else if let data = try? Data(contentsOf: legacyRecipesURL) {
            // 항목별 검증으로 살릴 수 있는 것은 전부 살린다
            result.document = LibrarySync.decode(data)
            result.migratedLegacy = true
            do {
                try write(result.document)
            } catch {
                result.migrationWriteError = error
            }
        }
        return result
    }

    /// 같은 내용의 사본이 이미 있으면 다시 만들지 않는다 (실행할 때마다 쌓이지 않게)
    private func keepDroppedOriginal(_ data: Data, now: Date) throws -> URL? {
        let fm = FileManager.default
        let existing = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let alreadyKept = existing.contains {
            $0.lastPathComponent.hasPrefix("library.dropped-") && (try? Data(contentsOf: $0)) == data
        }
        guard !alreadyKept else { return nil }
        let aside = directory.appendingPathComponent("library.dropped-\(Int(now.timeIntervalSince1970)).json")
        try data.write(to: aside, options: .atomic)
        return aside
    }

    public func write(_ doc: LibraryDocument) throws {
        if isWriteBlocked { throw StoreError.corruptOriginalNotSetAside }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try LibrarySync.encode(doc).write(to: libraryURL, options: .atomic)
    }
}
