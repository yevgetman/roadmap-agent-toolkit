Add a new work item to a roadmap track.

Ask the user for:
1. Which track (list available tracks from `docs/roadmap/BACKLOG.yml`)
2. Item title
3. Epic (optional — suggest existing epics from the track, or create new)
4. Dependencies (optional — list existing item IDs in the track)
5. A brief description of what to build

Then:
1. Determine the next available item ID for that track (scan existing IDs, increment)
2. Create a spec file at `docs/roadmap/items/<ID>-<slug>.md` with:
   - Goal section (from the user's description)
   - Empty acceptance criteria checklist (user fills in later, or ask them now)
   - Files likely touched (infer from description if possible)
   - Test plan section
   - Notes section
3. Add the item entry to `docs/roadmap/BACKLOG.yml` under the selected track's `items:` list with `status: ready`
4. If `gh` CLI is available, offer to create a GitHub issue for the item with the track's label

Append the new item at the end of the track's items list. Do NOT reorder existing items.
