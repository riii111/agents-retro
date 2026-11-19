///|
let timestamp : @string.Regex = regex(
  "^(?<year>[0-9]{4})-(?<month>[0-9]{2})-(?<day>[0-9]{2})T(?<hour>[0-9]{2}):(?<minute>[0-9]{2}):(?<second>[0-9]{2})(?<sign>[+\\-])(?<offset_hour>[0-9]{2})(?<offset_minute>[0-9]{2})$",
)

///|
fn time_ms(text : String) -> Int64? {
  guard timestamp.execute(text) is Some(m) else { return None }
  guard time_number(m, "year") is Some(year) else { return None }
  guard time_number(m, "month") is Some(month) else { return None }
  guard time_number(m, "day") is Some(day) else { return None }
  guard time_number(m, "hour") is Some(hour) else { return None }
  guard time_number(m, "minute") is Some(minute) else { return None }
  guard time_number(m, "second") is Some(second) else { return None }
  guard time_number(m, "offset_hour") is Some(offset_hour) else { return None }
  guard time_number(m, "offset_minute") is Some(offset_minute) else {
    return None
  }

  guard year > 0L &&
    month >= 1L &&
    month <= 12L &&
    hour < 24L &&
    minute < 60L &&
    second < 60L &&
    offset_hour < 24L &&
    offset_minute < 60L else {
    return None
  }

  let leap = year % 4L == 0L && (year % 100L != 0L || year % 400L == 0L)
  let max_day = if month == 2L && leap {
    29L
  } else {
    [31L, 28L, 31L, 30L, 31L, 30L, 31L, 31L, 30L, 31L, 30L, 31L][month.to_int() -
    1]
  }
  guard day >= 1L && day <= max_day else { return None }

  let sign = if m.named_group("sign") == Some("-") { -1L } else { 1L }
  let offset = sign * (offset_hour * 3600L + offset_minute * 60L)

  let y = year - (if month <= 2L { 1L } else { 0L })
  let era = y / 400L
  let yoe = y - era * 400L
  let mp = month + (if month > 2L { -3L } else { 9L })
  let doy = (153L * mp + 2L) / 5L + day - 1L
  let days = era * 146097L + yoe * 365L + yoe / 4L - yoe / 100L + doy - 719468L

  Some((days * 86400L + hour * 3600L + minute * 60L + second - offset) * 1000L)
}

///|
fn time_number(m : @string.MatchResult, name : String) -> Int64? {
  guard m.named_group(name) is Some(part) else { return None }
  Some(@string.parse_int64(part) catch { _ => return None })
}
