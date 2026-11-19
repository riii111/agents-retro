///|
/// UTC time as `YYYY-MM-DDTHH:MM:SS`, the form `since` takes.
pub fn utc_timestamp(ms : Int64) -> String {
  @clock.utc_timestamp(ms)
}
