///|
pub fn number(n : Int64) -> Json {
  Json::number(n.to_double())
}

///|
/// Keys keep the given order. A repeated key keeps its first position and last value.
pub fn object(fields : Array[(String, Json)]) -> Json {
  let map : Map[String, Json] = Map([])
  for field in fields {
    map[field.0] = field.1
  }

  Json::object(map)
}

///|
/// The `limit` items with the largest `size`; ties keep their input order.
pub fn[T] top(
  items : Array[T],
  limit : Int32,
  size : (T) -> Int64,
  render : (T) -> Json,
) -> Json {
  let ranked = items.mapi((i, item) => (item, i))
  ranked.sort_by((a, b) => {
    let by_size = size(b.0).compare(size(a.0))
    if by_size == 0 {
      a.1.compare(b.1)
    } else {
      by_size
    }
  })

  Json::array(ranked.iter().take(limit).map(entry => render(entry.0)).collect())
}
