Read `docs/roadmap/BACKLOG.yml` and summarize the current state of all roadmap tracks.

For each track, report:
- Track name and north star
- Whether the track is locked
- Count of items by status (ready, in-progress, staged, blocked, done, deferred)
- The current in-progress item (if any) with its title and branch
- Staged items awaiting human merge (with PR numbers)
- Blocked items with their blocking reason
- The next ready item (first with deps satisfied)

Also check `docs/roadmap-adhoc/STATE.yml` if it exists and report any in-flight ad-hoc items.

Format as a concise table. Don't list every ready item — just the count and the next one up.

At the end, note any items that appear stuck (in-progress for more than one agent tick cycle based on commit timestamps, or staged PRs that have been open for a long time).
