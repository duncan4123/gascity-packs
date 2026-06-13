{{ define "lazyjj-mental-model" }}
## LazyJJ Mental Model

LazyJJ leans on JJ's native graph instead of layering branch metadata on top.

- `@` is the working-copy commit, not a separate staging area
- a stack is the ancestry from `trunk()` to your current head
- editing an older commit automatically rebases descendants
- conflicts are recorded as state, so you can resolve them later without losing
  the graph
- `jj undo` and `jj op restore` are the fast recovery tools when you need to
  rewind or time-travel
{{ end }}
