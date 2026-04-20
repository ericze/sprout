# 2026-04-06 Assumptions Log

## Scope

This log records product or release decisions that were not fully re-confirmed during the release-readiness push and were implemented using the current engineering default.

## Active assumptions

- Language behavior:
  Follow the current app behavior of supporting language switching through the existing Settings entry, while keeping all formatting and copy lookup locale-aware.
  Source of assumption: existing app implementation plus `open_questions.md`.

- Unit system:
  Keep metric units only.
  Source of assumption: `open_questions.md`.

- Weekly letters:
  Historical weekly letters remain in the language they were generated in; only newly generated letters use the current language.
  Source of assumption: `open_questions.md`.

- Photo permission copy:
  Use generic “record photos” wording that covers both Home food photos and Treasure photos.
  Source of assumption: `open_questions.md` and current InfoPlist localization.

- Error feedback tone:
  Prefer low-interruption inline/toast feedback for recoverable failures, and reserve blocking alerts for compose-save failures that already occur inside a modal workflow.
  Source of assumption: release-readiness implementation decision aligned with AGENTS.md product tone.

## Confirmed after implementation

- In-app language switching remains a retained V1 feature.

## Remaining manual confirmation

- Decide whether any Treasure wording should further reduce explicit “letter” terminology in English.
