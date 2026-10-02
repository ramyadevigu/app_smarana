enum CalendarViewMode {
  monthAndWeek,
  nextThreeDays,
  monthOnly,

  // Retained so older callers and stored preferences remain readable.
  stacked,
  split,
}
