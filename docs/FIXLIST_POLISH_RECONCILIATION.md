# Polish plan reconciliation (IP-230 / IP-231 / IP-394)

Head reference: `cursor/integrate-pre-sunday-polish-c1b7` @ `751c72ac`, then fixlist batches on
`cursor/fixlist-code-751c`.

## polish-plan.md (P0–P2, Nov)

Most P0/P1 UI and copy items from the November baseline landed in pre-Sunday PRs **#112**,
**#135**, **#136**, and the UI fixlist branch `cursor/fixlist-ui-751c`. Remaining P0/P1 rows
that are **layout or copy** stay on the UI agent; code-only stability items are on
`cursor/fixlist-code-751c`.

## polish-plan-2.md / polish-plan-3.md (P3)

The 122 P3 items were not re-walked line-by-line in this batch. Spot checks against git on
`751c72ac` show the majority of fight/home/town polish from rounds 4–7 already merged into
#135. **Do not bulk-close** P3 IDs here without a dedicated audit pass; track in a future
content week, not this stability release.

## Agent action

| ID | Status | Note |
|----|--------|------|
| IP-230 | deferred | Needs owner-led P0/P1 checklist vs #135, not agent guess. |
| IP-231 | deferred | P3 spreadsheet vs git — out of scope for 95-item code batch. |
| IP-394 | deferred | Same as IP-230 for plan-2. |