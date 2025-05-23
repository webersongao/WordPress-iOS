import Foundation
import WordPressShared

/// Delete invalid rows in the database whose required blog properties are NULL
///
/// This is born from the investigation of the crash described in #12028 (https://git.io/JePdZ).
/// Unfortunately, we could not find the cause of it. The findings are described in that issue.
///
/// This tries to “fix” the issue by deleting the orphaned entities like `Post` whose `blog` were
/// set to NULL. They are currently inaccessible because they are not attached to any `Blog`. But
/// leaving them in the database would cause a crash if Core Data tries to save new entities.
///
@objc class NullBlogPropertySanitizer: NSObject {
    static let lastSanitizationVersionNumber = "null-property-sanitization"

    private let store: KeyValueDatabase
    private let context: NSManagedObjectContext

    @objc init(context: NSManagedObjectContext) {
        store = UserDefaults.standard
        self.context = context
    }

    init(store: KeyValueDatabase, context: NSManagedObjectContext) {
        self.store = store
        self.context = context
    }

    @objc func sanitize() {
        guard appWasUpdated() else {
            return
        }

        store.set(currentBuildVersion(), forKey: Self.lastSanitizationVersionNumber)

        // FIXME: Not sure why it's necessary to define [String] as the type. Without it, the NSFetchRequest<NSManagedObject>(entityName: entityName) below does not compile.
        let entityNamesWithRequiredBlogProperties: [String] = [
            Post.entityName(),
            Page.entityName(),
            Media.entityName(),
            PostCategory.entityName()
        ]

        let block = {
            entityNamesWithRequiredBlogProperties.forEach { entityName in
                let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                let predicate = NSPredicate(format: "blog == NULL")
                request.predicate = predicate
                request.includesPropertyValues = false

                if let results = try? self.context.fetch(request), !results.isEmpty {
                    results.forEach(self.context.delete)

                    WPAnalytics.track(.debugDeletedOrphanedEntities, withProperties: [
                        "entity_name": entityName,
                        "deleted_count": results.count
                    ])
                }
            }

            try? self.context.save()
        }

        // Make sure the "sanitization" work is done before any other Core Data reads or writes.
        if Thread.isMainThread, context.concurrencyType == .mainQueueConcurrencyType {
            block()
        } else {
            context.perform(block)
        }
    }

    private func appWasUpdated() -> Bool {
        let lastSanitizationVersionNumber = store.object(forKey: Self.lastSanitizationVersionNumber) as? String
        return lastSanitizationVersionNumber != currentBuildVersion()
    }

    private func currentBuildVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
