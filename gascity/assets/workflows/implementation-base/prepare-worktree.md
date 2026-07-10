This is the `implementation-base` methodology contract workspace preparation
step. The stable step ID remains `prepare-worktree` for extension compatibility.

Concrete methodology packs override this step only when their implementation
items need different setup. Preserve the source-anchor metadata contract, pass
through optional context `{{context_path}}`, and do not edit launcher-checkout
files here.
