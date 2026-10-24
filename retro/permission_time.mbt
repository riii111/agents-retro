///|
let permission_timestamp : @string.Regex = permission_regex(
  "^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})T([0-9]{1,2}):([0-9]{1,2}):([0-9]{1,2})(Z|[+\\-][0-9]{2}:?[0-9]{2}(:?[0-9]{2}(\\.[0-9]{1,6})?)?)$",
)

///|
/// The hook uses Python's %Y-%m-%dT%H:%M:%S%z, including offsets with seconds.
fn permission_time_us(text : String) -> Int64? {
  guard permission_timestamp.execute(text) is Some(m) else { return None }
  let numbers = []
  for i in 1..<7 {
    guard m.group(i) is Some(s) else { return None }
    numbers.push(@string.parse_int64(s) catch { _ => return None })
  }
  let year = numbers[0]
  let month = numbers[1]
  let day = numbers[2]
  let hour = numbers[3]
  let minute = numbers[4]
  let second = numbers[5]
  guard year > 0L &&
    month >= 1L &&
    month <= 12L &&
    hour < 24L &&
    minute < 60L &&
    second < 60L else {
    return None
  }
  let leap = year % 4L == 0L && (year % 100L != 0L || year % 400L == 0L)
  let month_days = [
    31L,
    if leap {
      29L
    } else {
      28L
    },
    31L,
    30L,
    31L,
    30L,
    31L,
    31L,
    30L,
    31L,
    30L,
    31L,
  ]
  guard day >= 1L && day <= month_days[month.to_int() - 1] else { return None }
  guard m.group(7) is Some(zone) else { return None }
  let mut offset = 0L
  if zone != "Z" {
    let sign = if zone.has_prefix("-") { -1L } else { 1L }
    let raw = zone[1:].to_owned()
    // Python rejects mixed colon and compact offset notation.
    if raw.contains(":") && !(raw.length() >= 5 && raw[2] == ':') {
      return None
    }
    if raw.length() > 5 && raw[2] == ':' && raw[5] != ':' {
      return None
    }
    let zone_parts : Array[StringView] = raw.split(":").collect()
    let compact = zone_parts.join("")
    let parts : Array[StringView] = compact.split(".").collect()
    let digits = parts[0]
    let h = @string.parse_int64(digits[:2]) catch { _ => return None }
    let min = @string.parse_int64(digits[2:4]) catch { _ => return None }
    let sec = if digits.length() == 6 {
      @string.parse_int64(digits[4:6]) catch {
        _ => return None
      }
    } else {
      0L
    }
    guard h < 24L && min < 60L && sec < 60L else { return None }
    let fraction = if parts.length() == 2 {
      @string.parse_int64(
        parts[1].to_owned() + "0".repeat(6 - parts[1].length()),
      ) catch {
        _ => return None
      }
    } else {
      0L
    }
    offset = sign * ((h * 3600L + min * 60L + sec) * 1_000_000L + fraction)
  }
  let y = year - (if month <= 2L { 1L } else { 0L })
  let era = y / 400L
  let yoe = y - era * 400L
  let mp = month + (if month > 2L { -3L } else { 9L })
  let doy = (153L * mp + 2L) / 5L + day - 1L
  let days = era * 146097L + yoe * 365L + yoe / 4L - yoe / 100L + doy - 719468L
  Some(
    (days * 86400L + hour * 3600L + minute * 60L + second) * 1_000_000L - offset,
  )
}
