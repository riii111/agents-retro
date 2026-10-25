///|
let permission_timestamp : @string.Regex = permission_regex(
  "^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})([+\\-])([0-9]{2})([0-9]{2})$",
)

///|
fn permission_time_ms(text : String) -> Int64? {
  guard text.length() == 24 && permission_timestamp.execute(text) is Some(m) else {
    return None
  }
  let numbers = []
  for i in 1..<10 {
    if i == 7 {
      continue
    }
    guard m.group(i) is Some(s) else { return None }
    numbers.push(@string.parse_int64(s) catch { _ => return None })
  }
  let year = numbers[0]
  let month = numbers[1]
  let day = numbers[2]
  let hour = numbers[3]
  let minute = numbers[4]
  let second = numbers[5]
  let offset_hour = numbers[6]
  let offset_minute = numbers[7]
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
  let sign = if m.group(7) == Some("-") { -1L } else { 1L }
  let offset = sign * (offset_hour * 3600L + offset_minute * 60L)
  let y = year - (if month <= 2L { 1L } else { 0L })
  let era = y / 400L
  let yoe = y - era * 400L
  let mp = month + (if month > 2L { -3L } else { 9L })
  let doy = (153L * mp + 2L) / 5L + day - 1L
  let days = era * 146097L + yoe * 365L + yoe / 4L - yoe / 100L + doy - 719468L
  Some((days * 86400L + hour * 3600L + minute * 60L + second - offset) * 1000L)
}
