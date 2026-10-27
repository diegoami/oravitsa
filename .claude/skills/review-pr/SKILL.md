---
name: review-pr
description: Prepare an independent PR review handoff or process its findings. The implementing session does not review itself.
---

Read `AGENTS.md` and `docs/review-pr.md`. For a handoff, fetch live PR metadata
and provide its URL, full head SHA and base SHA. Give the owner a fresh-session
prompt to follow `docs/review-pr.md` for that PR, on a different model family,
or `/review-pr <number>` in a fresh OpenCode session. Do not start your own
reviewer or claim an independent review occurred.

When the owner says a review is in, read the current PR and its reviews on
GitHub, check which SHA they cover, reproduce findings, fix confirmed defects
on the implementation branch and push. Reply with evidence for each finding.
Leave the PR open for the owner unless explicitly asked to merge.
