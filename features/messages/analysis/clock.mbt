///|
/// Matches Python's UTC `isoformat()` so string comparison with log timestamps gives the same result.
pub fn utc_isoformat(ms : Int64) -> String {
  let micros = @clock.utc_millisecond(ms) * 1000L
  let fraction = if micros == 0L {
    ""
  } else {
    ".\{@clock.zero_pad(micros, 6)}"
  }

  "\{@clock.utc_timestamp(ms)}\{fraction}+00:00"
}
