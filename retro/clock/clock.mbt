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
