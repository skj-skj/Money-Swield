/// Calendar days between the device-local dates of [moment] and [now]: 0
/// for the same day, 1 for yesterday. Something at 23:00 no longer reads
/// "today" at 01:00. Negative when [moment] is on a later day.
int calendarDaysAgo(DateTime moment, DateTime now) =>
    _localDate(now).difference(_localDate(moment)).inDays;

/// The device-local calendar date of [moment], as a UTC midnight so that
/// day arithmetic can't be shifted by a DST change.
DateTime _localDate(DateTime moment) {
  final local = moment.toLocal();
  return DateTime.utc(local.year, local.month, local.day);
}
