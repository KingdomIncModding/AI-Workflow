# Foundation is the game integration boundary

Foundation supplies the framework: stable game access, hooks, events, and compatibility adapters. Mods retain their feature behavior, UI policy, selection and batch orchestration. Do not move entire mod implementations into Foundation.

Native game calls, private field access, reflection names and Harmony targets belong inside Foundation. New consumer contracts should use Foundation-owned values/opaque identities and Unity/framework types. Returning a native object and calling its methods in the mod still bypasses this boundary. Existing native-facing SDK APIs remain for compatibility while consumers migrate; their presence is not proof of isolation from game updates.

Use `Foundation/Tools/Architecture/Audit-GameBoundary.ps1 -Mod <name> -Enforce` after building a migrated consumer. Review reflection findings as well as the compiled assembly report. Keep all update audit outputs under the game root's `_ModUpdates/{ModName}` and never modify `_SrcExtraction`.
