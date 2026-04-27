Add a new track to the existing roadmap in `docs/roadmap/BACKLOG.yml`.

Ask the user for:
1. Track name (e.g. `mobile`, `infra`, `growth`)
2. ID prefix (single letter, e.g. `M`)
3. Branch prefix (e.g. `mobile`)
4. Issue label (default: `roadmap-<name>`)
5. One-line north star goal

Then:
1. Read `docs/roadmap/BACKLOG.yml`
2. Add a new track section under `tracks:` with the provided config, empty items list, and a cron expression offset from existing tracks
3. Write the updated file
4. If `gh` CLI is available, offer to create the issue label
5. Print the scheduling instructions for the new track's agent

Do NOT modify any existing tracks. Do NOT reorder items. Append the new track at the end of the `tracks:` section.
