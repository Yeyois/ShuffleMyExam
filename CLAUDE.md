# Agent Workflow Guide — JCT MixExam Project

This document is intended for the coding agent (Claude Code) that will actually build the app, based on the PRD. Goal: reduce mistakes, keep work incremental and reviewable, and prevent "big bang" code drops that produce large, unverified changes.

Recommended: save this file at the repo root as `CLAUDE.md` — Claude Code reads it automatically at the start of every session.

---

## 0. Execution Mode

Unless the user explicitly says otherwise, run autonomously through all phases (0 → 4) without pausing for review after each one. At the end of each phase: run `flutter analyze` and the relevant tests, and if they pass, commit automatically using the commit format below, then continue immediately to the next phase.

Only stop and wait for the user if:
- You hit a genuine ambiguity in the PRD that can't be reasonably resolved (see Section 5), or
- Tests keep failing after real, repeated attempts to fix them, or
- You run out of context/turns mid-phase (in which case, leave the repo in a committed, working state so the next session can resume cleanly), or
- All phases are complete and the app runs end-to-end.

Do not ask "should I continue?" or "would you like me to proceed to the next phase?" between phases — just proceed. The checklists and phase boundaries in this document are for your own internal tracking and commit structure, not review checkpoints with the user.

---

## 1. Core Principle: Small, Verifiable Steps

Don't let the agent write the entire app in one pass. A project like this (Flutter + Isolates + PDF parsing + Riverpod) is prone to bugs that are hard to trace if everything is written together. Break work into phases, and within each phase: implement → test → commit → move on.

---

## 2. Git Usage

### Basic Structure
- `main` — stable code only. Never committed to directly.
- `develop` (optional for a small project, but recommended) — integration base.
- Feature branches: `feature/<short-name>`, e.g. `feature/pdf-parsing-engine`, `feature/practice-screen`, `feature/results-screen`.

### Working Rules
- **Before starting any new step** — confirm there are no uncommitted changes (`git status` clean).
- **Commit after each complete, working unit of work** (not after every line, but not only at the end of the day either). Example unit of work: "data model + tests", "Bidi algorithm + test", "Home screen + DB connection".
- **Commit messages in Conventional Commits format:**
  - `feat: add Bidi reversal for Hebrew RTL text`
  - `fix: use a fair shuffle so answer order gives nothing away`
  - `test: add unit tests for question regex detection`
  - `refactor: extract PDF parsing into isolated service`
  - `chore: update dependencies`
- **Never push code that doesn't run.** If `flutter analyze` or tests fail — fix before committing, or explicitly mark the commit as WIP.
- **Open a Pull Request for every feature branch**, even if only the user reviews it — this gives a checkpoint before merging to main.
- Don't rewrite git history, don't force-push, unless explicitly requested.

---

## 3. Recommended Work Order (Phases)

### Phase 0 — Project Scaffold
- Create the Flutter project, set up `flutter_riverpod`, folder structure per Clean Architecture:
  ```
  lib/
    core/            # constants, themes, utils, error handling
    data/             # data sources: sqflite/hive, file_picker, pdf parsing
    domain/           # models (Exam, Question, Answer) + repository contracts
    application/       # Riverpod providers / state notifiers
    presentation/      # screens and widgets
  ```
- Set up Material 3 theme + global RTL.
- Commit: `chore: initial project scaffold with clean architecture folders`.

### Phase 1 — Models and Data Layer
- Implement `Exam`, `Question`, `Answer` exactly per the PRD structure.
- Set up local storage layer (sqflite/hive) + tests for basic CRUD.
- **Checkpoint:** verify serialization/deserialization works correctly before moving on.

### Phase 2 — Parsing Engine (the critical core)
This is the most sensitive part of the project — break it into separate sub-steps, each with its own test:
1. Question-start detection (regex) — test against several different numbering formats.
2. Text vs. visual distinction (bounding box) — test with a sample PDF of each type.
3. Bidi algorithm for Hebrew character reversal — **a dedicated test is mandatory**, using strings that mix Hebrew, numbers, and English words in the same line, to verify partial ordering is preserved correctly.
4. Answer extraction (א./ב./ג./ד.) + marking isOriginalCorrect + shuffling.
5. Smart Cropping for visual questions — test that the detected Y-coordinate actually cuts above the "א." bullet.
6. Wrapping all of the above in `compute()` — verify in practice (not just in code) that there are no synchronous calls blocking the UI thread.

**Iron rule:** don't move to the next step within Phase 2 before the current step has a passing test. A bug here propagates to every screen.

### Phase 3 — UI Screens
- Home screen → Loading/Processing screen → Practice screen (text/visual) → Results screen.
- Build one screen at a time, wire it to the Riverpod providers already built in Phase 2, and run it manually (or write a widget test) before moving to the next screen.
- Pay special attention to the Silent UX rule (no indication that a question wasn't shuffled) — verify there's no suspicious visual difference between the two question types beyond the content itself.

### Phase 4 — Polish and Integration
- Full Dark/Light mode toggle.
- Verify RTL across all screens, including animations and transitions.
- Test end-to-end flows: PDF import → parsing → practice → results, for both a purely textual PDF and one with visual questions.

---

## 4. Standing Rules the Agent Should Keep in Mind Throughout

- **100% offline** — any new package usage must be checked to ensure it doesn't send data over the network. If in doubt — ask before installing.
- **compute() for anything heavy** — PDF parsing, regex, Bidi, image cropping. If new code does any of these outside an isolate — that's a bug to fix immediately, not something to "document for later."
- **fullImageUrl is never the default** — any change to the visual practice screen must re-verify this rule hasn't been broken by accident.
- **No `flutter analyze` warnings left open** at the end of any Phase — clean up before committing the phase as done.

---

## 5. When the Agent Should Stop and Ask Instead of Assuming

- If the question-detection regex is ambiguous (e.g., a real document with a numbering format that deviates from the PRD examples) — stop and ask, don't invent an arbitrary rule.
- If there's a conflict between a PRD requirement and a technical limitation of a package (Syncfusion/pdfx) — surface the gap to the user before proceeding.
- If a task requires choosing a new package not mentioned in the PRD — briefly propose 1-2 alternatives and ask, don't install and silently continue.

---

## 6. Definition of Done for Each Phase

Before closing out a commit/PR for a phase:
- [ ] `flutter analyze` is clean
- [ ] Relevant tests for the phase pass (`flutter test`)
- [ ] No network calls (manually search for `http`, `dio`, etc.)
- [ ] Heavy operations are wrapped in `compute()`
- [ ] Commit with a clear message following the agreed format
- [ ] Short PR description: what was built, what was tested, what's still open
