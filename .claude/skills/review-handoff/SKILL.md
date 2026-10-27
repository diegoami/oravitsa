---
name: review-handoff
description: Prepare or process a formal release-milestone review, distinct from ordinary PR review.
---

Read `AGENTS.md`, `docs/RELEASES.md` and `docs/review-release.md`. Follow the
milestone issue template. Record the actual full candidate SHA, previous tag
or first-release full-repository scope, implementer identity, gate results,
claims with file/line references, known decisions, artifacts, untested checks
and review rounds. Do not invent a version or mark missing checks as passed.

Give the owner a fresh-session prompt to follow `docs/review-release.md` for
the issue on a different model family, or `/review-release <number>` in a
fresh OpenCode session. Do not spawn your own reviewer.

Read returned findings on GitHub and reproduce them. Fix confirmed defects
through PRs; record disputed evidence for the owner. After fixes merge, update
the candidate, rerun gates and prepare a fresh handoff. Stop after three rounds
without AGREE and let the owner decide. Tagging/publishing follow the owner's
explicit authorization and the exact-SHA requirements in `docs/RELEASES.md`.
