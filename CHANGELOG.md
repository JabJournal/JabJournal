# Changelog

All notable changes to JabJournal will be documented here.

## [0.2.0] - 2026-06-29

### Added
- **Re-schedule dose from notification** — new "Re-schedule" action button on scheduled-dose notifications, alongside "Log Dose". Opens a date/time picker and moves just the current occurrence to a new one-shot reminder. Original day and new day both show on the calendar with clear "Rescheduled to / from" indicators (#13).
- **Proactive reschedule from the schedule page** — the popup menu on each schedule card now offers "Re-schedule dose" for any active schedule, not only days that have already been rescheduled (#15).
- **Conflict pop-up for reschedules** — when the chosen new day is also a normal scheduled day, the user is asked to choose "Keep both" or "Replace only this dose".
- **Reschedule persistence** — reschedules are stored on the schedule (DB v7) and re-registered on app launch, so they survive force-stops and reboots.

### Fixed
- **History sections now sort chronologically** — logging or editing a dose to a past date no longer leaves the list out of order. `DoseHistoryProvider` and `WeightProvider` re-sort on every mutation, and `DoseHistoryScreen` sorts within each day group as well (#15).
- **Notification bug** (#11).

### Removed
- **Supabase cloud sync** — the optional sync feature was untested and the user wasn't using it. Removed to clean up the dependency tree. The `sync_status` and `remote_id` columns remain in the database schema (kept as legacy fields, always set to `'pending'` / `null` now), but no longer sync anywhere. If you want to bring back cloud sync, this would need to be re-added from scratch. Deleted files: `lib/config/supabase_config.dart`, `lib/services/supabase/`, `lib/providers/sync_provider.dart`.

### Changed
- **Dependency upgrades** — applied across 53 packages:
  - Minor/patch: `connectivity_plus`, `intl`, `path_provider`, `sqflite`, `sqlite3`, `supabase_flutter` (now removed entirely), and 42 transitives.
  - Major: `flutter_lints` 5→6, `permission_handler` 11→12, `flutter_local_notifications` 21→22, `flutter_foreground_task` 8→9, `share_plus` 12→13, `file_picker` 11→12 (beta).
- **Test coverage** — 70 tests covering the schedule model, provider, notification router, and reschedule screen widget.

## [0.1.0] - 2026-05-11

Initial release.

### Added
- Peptide management — add, edit, and delete peptides with vendor and dosage details
- Dose logging — record injections with amount, site, and side effects
- Injection calculator — compute draw volume from vial specs and desired dose
- Scheduling — set recurring or one-time dose reminders
- Weight tracking — log weight entries with optional dose correlation
- Local notifications — dose reminders via system notifications with foreground service support on Android
- Offline-first SQLite storage — all data stored locally with no account required
- Backup & restore — export and import an encrypted backup of all data
