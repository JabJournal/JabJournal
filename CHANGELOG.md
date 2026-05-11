# Changelog

All notable changes to JabJournal will be documented here.

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

### Notes
- Supabase sync is included but untested in this release — configure credentials at your own risk
