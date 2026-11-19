# GitHub Tags, Topics, and Issue Labels

These are three different GitHub concepts; do not mix them up.

## 1. Git version tags

Use release/version tags such as `v1.0.0` to mark a specific commit.
- Base tag values on actual, user-approved version numbers.
- Keep the mod's `version` and existing released tag in `mod.json`
  accurate; `repository.latestTag` is set only after the tag exists.
- Do not create/push version tags or GitHub releases automatically.
- Pushing tags (`git push --tags`, `git push origin vX.Y.Z`) is a push
  and always requires the user's explicit approval.
- Check whether the tag already exists before proposing a new one.

## 2. Repository topics

GitHub repository topics help people find the mod. Select only accurate
topics based on the mod's real gameplay functionality. Candidate topics
may include `kingdominc`, `modding`, and an accurate mod category, but
do not set a topic merely because it appears in this example.
- Desired topics can be stored in `repository.topics` in `mod.json`.
- Verify live topics before claiming they were applied.
- Editing GitHub topics is a remote write and requires user approval.

## 3. Issue labels

Labels classify existing issues, not release versions. A minimal label
vocabulary, when available, is `bug`, `enhancement`, and `question`.
Reuse a repository's existing labels; never assume a label exists.
- Do not add, remove, or create labels unless explicitly instructed.
- Never relabel an issue automatically when reading or fixing it.
- `enhancement` means a requested feature, not permission to implement
  it or post anything to GitHub.

See `ISSUES.md` and `FEATURES.md` for all approval rules.
