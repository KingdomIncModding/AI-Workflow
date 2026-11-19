# Repository Naming and Identity

## Naming

- GitHub owner: `KingdomIncModding`.
- Repository name: `{ModName}`.
- Preserve the actual mod identifier's spelling and capitalization.
- Organization repository names have no `KingdomInc_` prefix. When deriving
  a name from an older local folder such as `KingdomInc_VortexExt`, strip
  only that leading prefix and use `VortexExt`. Local folder names and mod
  IDs do not need to change.
- Example: `https://github.com/KingdomIncModding/GlobalLedger`.
- Do not replace underscores, strip words, or guess remote URLs.

The path above is a naming *pattern*. Before filling a real URL in
`mod.json`, verify that the remote repository exists and belongs to
`KingdomIncModding`. If it does not exist, leave its URL and branch `null`.
Do not silently create it; creation requires explicit permission.

## mod.json

Every mod stores its repository identity in `{ModName}/mod.json`, not
in shared workspace docs. Keep these fields accurate:

```json
"repository": {
  "platform": "GitHub",
  "owner": "KingdomIncModding",
  "name": null,
  "url": null,
  "branch": null,
  "visibility": null,
  "topics": [],
  "latestTag": null
}
```

- `owner` is the intended owner. Set `name` when the user chooses the
  canonical repository name; `url` only after the real remote is verified.
- `branch` is the confirmed remote default/working branch; do not assume
  `main` for an uncreated repo.
- `visibility` describes the actual remote, not an intended setting.
- `topics` lists selected/intended repository topics; confirm live topics
  before claiming they were applied. Empty means none specified.
- `latestTag` records an existing *verified* version tag, never a planned
  tag or a guessed version. A new version in `version` is not proof of a tag.
- Other `mod.json` fields, especially Nexus distribution settings, must
  be preserved when updating GitHub metadata.

## Organization ownership migrations

`KingdomIncModding` is the repository owner. Your personal GitHub login remains
only the authenticating account; do not substitute a personal login for the
organization when constructing a repository URL.

1. Update every affected mod's ignored `_AI/Prompts/RepositoryWorkflow.md`
   and any older repository setup prompts first. Then update shared master
   workflows, the mod template, and tools with an embedded owner.
2. Inventory all matching repositories, including older projects and tools.
   Verify administrator access, organization creation permission, and name
   conflicts. Record repository IDs, branch/tag refs and release asset IDs.
3. Transfer each existing repository. Rename it only when the user requests it; organization repository names use the mod name without KingdomInc_. Verify the same
   repository ID under the organization and unchanged branch/tag refs,
   releases and release assets. Never substitute a new repository or rewrite
   history for an ownership transfer.
4. After verifying the destination, update `mod.json` repository ownership,
   repository/release/SDK URLs, local Git remotes and public links. Preserve
   identity, versions, Nexus IDs, dependencies and unrelated local edits.
   Leave destinations that do not exist unset.
5. Mirror Nexus descriptions and README exactly using the formatter. For
   live Nexus pages, change only repository URLs in the current live text;
   do not publish unrelated pending descriptions, binaries or changelogs.
6. Make link-only commits from clean checkouts if working mods have pending
   changes. Do not publish private workflow files. Verify new links and old
   redirects, and retain a local migration receipt under shared `_AI/`.

A user request to migrate repositories and update their links authorizes
those operations. It does not authorize unrelated releases, issue changes,
new repositories, version bumps or feature publication. Future unrelated
pushes still require the user's instruction.

## Other remote operations

- Do not create a remote repository, push a branch or tags, publish a
  release, or change repo settings without explicit user approval.
- When an existing remote is confirmed, use its actual default branch.
- Never force-push unless separately and explicitly authorized.
- After a substantial local task, recommend a push as a decision, not an
  action: "Changes are ready locally. Would you like me to push?"
- Do not store credentials in `mod.json` or public files.
