///|
let ms_per_day : Int64 = 86_400_000L

///|
/// Matches Python's UTC `isoformat()` so string comparison with log timestamps gives the same result.
pub fn utc_isoformat(ms : Int64) -> String {
  let day_ms = ms - floor_div(ms, ms_per_day) * ms_per_day
  let h = day_ms / 3_600_000L
  let min = day_ms / 60_000L % 60L
  let s = day_ms / 1000L % 60L
  let micros = day_ms % 1000L * 1000L
  let fraction = if micros == 0L { "" } else { ".\{pad(micros, 6)}" }
  "\{utc_date(ms)}T\{pad(h, 2)}:\{pad(min, 2)}:\{pad(s, 2)}\{fraction}+00:00"
}

///|
/// UTC calendar date of a Unix time in milliseconds, as `YYYY-MM-DD`.
fn utc_date(ms : Int64) -> String {
  let (y, m, d) = civil_from_days(floor_div(ms, ms_per_day))
  "\{pad(y, 4)}-\{pad(m, 2)}-\{pad(d, 2)}"
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
