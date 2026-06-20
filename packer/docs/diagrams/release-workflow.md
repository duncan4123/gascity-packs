# Release Workflow

This diagram shows how tested pack work moves from local `main` to GitHub.

## Release steps

```mermaid
flowchart TD
  start["Release triggered from default@ after local testing"]
  fetch["jj git fetch"]
  check{"main@origin ahead of main?"}
  rebase["jj rebase -s main -d main@origin"]
  merge["jj new main@origin <pack-tips...> -m 'Land packs'"]
  move_main["jj bookmark move main --to @"]
  verify["gc lint <pack>"]
  push["jj git push"]
  confirm["main@origin == main"]

  start --> fetch
  fetch --> check
  check -->|yes| rebase
  check -->|no| merge
  rebase --> merge
  merge --> move_main --> verify --> push --> confirm
```

## Notes

- Always fetch first. `main@origin` is the live target.
- If origin has moved, rebase local `main` onto `main@origin` before landing.
- If multiple pack lines land together, create one merge commit whose parents
  include `main@origin` and every pack tip.
- After moving `main`, verify the landed packs still lint cleanly.
- Push only after verification.
- Do not push `gc/*` workspace bookmarks to origin; they are local-only.
