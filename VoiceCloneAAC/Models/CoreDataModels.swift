import CoreData
import Foundation

@objc(CachedAudio)
public class CachedAudio: NSManagedObject {}

extension CachedAudio {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedAudio> {
        NSFetchRequest<CachedAudio>(entityName: "CachedAudio")
    }

    @NSManaged public var createdAt: Date
    @NSManaged public var fileSize: Int64
    @NSManaged public var lastUsedAt: Date
    @NSManaged public var localFilePath: String
    @NSManaged public var text: String
    @NSManaged public var textHash: String
    @NSManaged public var voiceId: String
}

@objc(PendingSynthesis)
public class PendingSynthesis: NSManagedObject {}

extension PendingSynthesis {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PendingSynthesis> {
        NSFetchRequest<PendingSynthesis>(entityName: "PendingSynthesis")
    }

    @NSManaged public var category: String
    @NSManaged public var createdAt: Date
    @NSManaged public var status: String
    @NSManaged public var text: String
}
