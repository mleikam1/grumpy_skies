# DayMaker Fun Section — Codex package

This package contains the five approved UI references and two prompts:

- `daymaker_fun_codex_prompt.md` — implementation prompt
- `daymaker_fun_codex_visual_qa_prompt.md` — screenshot comparison and fix pass
- `daymaker_fun_design_refs/` — the five visual references

## Recommended workflow

1. Copy this entire folder into the root of the DayMaker app repository.
2. Open that repository in the Codex desktop app.
3. Attach the five PNGs from `daymaker_fun_design_refs/` to the task.
4. Paste all of `daymaker_fun_codex_prompt.md` into the task and let Codex finish the implementation and verification.
5. Review the diff and the five implementation screenshots.
6. In the same branch/task, paste all of `daymaker_fun_codex_visual_qa_prompt.md`. This second pass requires Codex to fix visible mismatches and rerun tests, not merely list issues.

The mockups include phone status/navigation bars as context. They are not app UI and must not be recreated. Codex should use the real platform system bars, safe areas, and the app's existing bottom-navigation shell.

No prompt can guarantee a defect-free implementation across an unknown codebase. These prompts reduce that risk by requiring repository discovery, incremental integration, automated tests, device checks, and visual comparisons before completion.
