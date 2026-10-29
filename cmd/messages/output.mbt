///|
/// Removes the chunks of an earlier run on the same day, which may have left more files than this run writes.
async fn write_unmatched_chunks(
  out_dir : String,
  today : String,
  chunks : Array[Array[@analysis.Message]],
) -> Array[String] {
  let prefix = "\{today}-unmatched-"
  for name in @fs.readdir(out_dir, include_hidden=false) {
    if name.has_prefix(prefix) && name.has_suffix(".tsv") {
      @fs.remove("\{out_dir}/\{name}")
    }
  }

  let paths = []
  for i, chunk in chunks {
    let number = if i < 9 { "0\{i + 1}" } else { "\{i + 1}" }
    let path = "\{out_dir}/\{prefix}\{number}.tsv"
    write_lines(path, chunk.iter().map(@analysis.unmatched_tsv_line))
    paths.push(path)
  }

  paths
}

///|
let write_buffer_bytes : Int32 = 1 << 16

///|
async fn previous_metrics(
  out_dir : String,
  today : String,
) -> @analysis.PreviousMetrics? {
  let names = @fs.readdir(out_dir, include_hidden=false).filter(name => {
    name.has_suffix("-metrics.json") &&
    !name.has_suffix("\{today}-metrics.json")
  })
  guard !names.is_empty() else { return None }

  names.sort_by((a, b) => a.lexical_compare(b))
  let latest = names[names.length() - 1]

  @analysis.parse_previous_metrics(
    read_text("\{out_dir}/\{latest}"),
    date=@analysis.take_chars(latest, 10),
  )
}

///|
/// Streams through a fixed-size buffer so the formatted lines never exist as one array or one string.
async fn write_lines(path : String, lines : Iter[String]) -> Unit {
  let file = @fs.create(path)
  defer file.close()

  let out = @io.BufferedWriter::new(file, size=write_buffer_bytes)
  for line in lines {
    out.write(line)
    out.write("\n")
  }

  out.flush()
}
