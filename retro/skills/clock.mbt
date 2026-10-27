///|
let ms_per_day : Int64 = 86_400_000L

///|
/// Log timestamps are UTC ISO 8601, so their first 19 characters
/// (`YYYY-MM-DDTHH:MM:SS`) compare in time order as strings.
pub fn utc_timestamp(ms : Int64) -> String {
  let days = floor_div(ms, ms_per_day)
  let day_ms = ms - days * ms_per_day
  let (year, month, day) = civil_from_days(days)
  let hour = day_ms / 3_600_000L
  let minute = day_ms / 60_000L % 60L
  let second = day_ms / 1000L % 60L

  "\{pad(year, 4)}-\{pad(month, 2)}-\{pad(day, 2)}T\{pad(hour, 2)}:\{pad(minute, 2)}:\{pad(second, 2)}"
}

///|
fn in_period(timestamp : String, since~ : String) -> Bool {
  timestamp.length() >= 19 &&
  timestamp[:19].to_owned().lexical_compare(since) >= 0
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
fn pad(n : Int64, width : Int32) -> String {
  let s = n.to_string()
  "0".repeat(width - s.length()) + s
}
