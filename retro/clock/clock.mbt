///|
let ms_per_day : Int64 = 86_400_000L

///|
/// Log timestamps are UTC ISO 8601, so both sides compare as strings once each is normalized to `YYYY-MM-DDTHH:MM:SS.mmm`.
/// A missing or shorter timestamp is outside every period.
pub fn in_period(timestamp : String, since~ : String) -> Bool {
  timestamp.length() >= 19 &&
  millisecond_key(timestamp).lexical_compare(millisecond_key(since)) >= 0
}

///|
/// Pads or truncates the fraction to milliseconds, so `...:41Z` and `...:41.000Z` are the same instant.
fn millisecond_key(text : String) -> String {
  let key = StringBuilder()
  key.write_string(text[:19].to_owned())
  key.write_char('.')

  let mut digits = 0
  if text.length() > 19 && text[19:].has_prefix(".") {
    for c in text[20:] {
      if digits == 3 || c < '0' || c > '9' {
        break
      }
      key.write_char(c)
      digits += 1
    }
  }
  key.write_string("0".repeat(3 - digits))

  key.to_string()
}

///|
/// UTC date and time of a Unix time in milliseconds, as `YYYY-MM-DDTHH:MM:SS.mmm`.
pub fn utc_millis_timestamp(ms : Int64) -> String {
  "\{utc_timestamp(ms)}.\{zero_pad(utc_millisecond(ms), 3)}"
}

///|
/// UTC date and time of a Unix time in milliseconds, as `YYYY-MM-DDTHH:MM:SS`.
pub fn utc_timestamp(ms : Int64) -> String {
  let day_ms = ms - floor_div(ms, ms_per_day) * ms_per_day
  let hour = day_ms / 3_600_000L
  let minute = day_ms / 60_000L % 60L
  let second = day_ms / 1000L % 60L

  "\{utc_date(ms)}T\{zero_pad(hour, 2)}:\{zero_pad(minute, 2)}:\{zero_pad(second, 2)}"
}

///|
/// UTC calendar date of a Unix time in milliseconds, as `YYYY-MM-DD`.
pub fn utc_date(ms : Int64) -> String {
  let (year, month, day) = civil_from_days(floor_div(ms, ms_per_day))
  "\{zero_pad(year, 4)}-\{zero_pad(month, 2)}-\{zero_pad(day, 2)}"
}

///|
/// Millisecond part (0 to 999) of a Unix time in milliseconds.
pub fn utc_millisecond(ms : Int64) -> Int64 {
  ms - floor_div(ms, 1000L) * 1000L
}

///|
pub fn zero_pad(n : Int64, width : Int32) -> String {
  let s = n.to_string()
  "0".repeat(width - s.length()) + s
}

///|
/// Days since 1970-01-01 of the `YYYY-MM-DD` date at the start of a timestamp; `None` when it is not a date.
pub fn days_from_date(text : String) -> Int64? {
  guard text.length() >= 10 && text[4:5] == "-" && text[7:8] == "-" else {
    return None
  }

  let year = @string.parse_int64(text[0:4].to_owned()) catch {
    _ => return None
  }
  let month = @string.parse_int64(text[5:7].to_owned()) catch {
    _ => return None
  }
  let day = @string.parse_int64(text[8:10].to_owned()) catch {
    _ => return None
  }
  guard month >= 1L && month <= 12L && day >= 1L && day <= 31L else {
    return None
  }

  Some(days_from_civil(year, month, day))
}

///|
/// `YYYY-MM-DD` of a day count since 1970-01-01.
pub fn date_from_days(days : Int64) -> String {
  let (year, month, day) = civil_from_days(days)
  "\{zero_pad(year, 4)}-\{zero_pad(month, 2)}-\{zero_pad(day, 2)}"
}

///|
/// The Monday on or before a day count; 1970-01-01 was a Thursday.
pub fn week_start_days(days : Int64) -> Int64 {
  let offset = days + 3L
  days - (offset - floor_div(offset, 7L) * 7L)
}

///|
fn floor_div(a : Int64, b : Int64) -> Int64 {
  let q = a / b
  if a % b != 0L && a < 0L {
    q - 1L
  } else {
    q
  }
}

///|
/// Converts days since 1970-01-01 to a civil date (Howard Hinnant's algorithm).
fn civil_from_days(days : Int64) -> (Int64, Int64, Int64) {
  let z = days + 719468L
  let era = (if z >= 0L { z } else { z - 146096L }) / 146097L
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let day = doy - (153L * mp + 2L) / 5L + 1L
  let month = if mp < 10L { mp + 3L } else { mp - 9L }
  let year = yoe + era * 400L + (if month <= 2L { 1L } else { 0L })

  (year, month, day)
}

///|
fn days_from_civil(year : Int64, month : Int64, day : Int64) -> Int64 {
  let y = if month <= 2L { year - 1L } else { year }
  let era = floor_div(y, 400L)
  let yoe = y - era * 400L
  let doy = (153L * (if month > 2L { month - 3L } else { month + 9L }) + 2L) /
    5L +
    day -
    1L
  let doe = yoe * 365L + yoe / 4L - yoe / 100L + doy
  era * 146097L + doe - 719468L
}
