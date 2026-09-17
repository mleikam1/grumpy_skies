import 'meme_backend.dart';
import 'meme_indexeddb_backend.dart';
import 'package:idb_shim/idb_browser.dart';

// Never use idbFactoryBrowser: its package fallback is ephemeral memory when
// IndexedDB is unavailable, which must not be presented as a saved draft.
MemeBackend createMemeBackend() => IndexedDbMemeBackend(idbFactoryNative);
