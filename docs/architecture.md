# Architecture and extension points

`AppState` owns the versioned preferences and association rules. A rule selects a handler by extension and priority; the Android chooser receives the rule's MIME type. Add a handler by extending `FileRule.action`, the editor, and `BrowserScreen.open`; don't advertise it until it can actually open a file.

`FileService` enumerates local files asynchronously and delegates document-tree listing to the Android channel. SAF is currently explicitly read-only in the UI. Platform capabilities are not yet modeled as a provider interface; that refactor is required before adding writable SAF or remote providers. `MainActivity` performs document-tree queries and persistable permission grants through ContentResolver and DocumentsContract, shares file paths via FileProvider, and runs ZIP and transfer work on a worker executor. Never interpret a content URI as a filesystem path.

For a future provider, define capabilities (list, read, write, rename, delete, move, URI grant) before connecting UI actions; use streams and refuse unsupported operations. Remote credential storage, TLS verification, and host-key verification must be designed before enabling any network backend.

Copies reserve destination files and never overwrite; SHA-256 verification precedes source deletion for moves. ZIP extraction checks canonical paths, caps entries and expanded bytes, and refuses collisions. Both operations can leave successfully copied/extracted entries after failure, and are not resumable. Review these semantics before adding background jobs or conflict resolution.
