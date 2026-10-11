/// How far back a scan reads the inbox (phase-9a.md §5.8, A9, P9a-14).
/// Pure Dart.
library;

/// The first scan after turning SMS on reads this far back (A9).
const firstScanDays = 7;

/// The most a scan reads back, and the age at which pending and dismissed
/// suggestions are purged (§4): one number, so a purged SMS can never be
/// read again. Only the debug look-back (§6.8) changes it, both together.
const smsLookbackDays = 30;

const _dayMs = Duration.millisecondsPerDay;

/// The epoch ms the scan reads from (`date >= since`):
///
/// | cursor | since |
/// |---|---|
/// | null (first scan) | now − 7 days; with a debug [lookbackDays] other than 30, the whole look-back |
/// | in the future (clock moved back) | as null |
/// | a value | the cursor, but not before now − [lookbackDays] |
int scanSince({
  required int nowMs,
  required int? cursorMs,
  int lookbackDays = smsLookbackDays,
}) {
  final floor = nowMs - lookbackDays * _dayMs;
  if (cursorMs == null || cursorMs > nowMs) {
    // The override's point is reading old SMS on a phone without a SIM
    // (§6.8): its first scan reads all of it.
    return lookbackDays == smsLookbackDays
        ? nowMs - firstScanDays * _dayMs
        : floor;
  }
  return cursorMs < floor ? floor : cursorMs;
}
