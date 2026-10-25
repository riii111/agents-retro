///|
async fn read_sessions(
  paths : Array[String],
  report : @analysis.Report,
) -> Unit {
  for path in paths {
    let session = report.start_session()
    @logfiles.each_line(path, line => {
      if @analysis.is_candidate_line(line) {
        session.read_line(@utf8.decode_lossy(line))
      }
    })
  }
}

///|
async fn read_events(
  path : String,
  since_ms : Int64,
  report : @analysis.Report,
) -> Unit {
  if @fs.exists(path) {
    @logfiles.each_line(path, line => {
      report.read_event(@utf8.decode_lossy(line), since_ms~)
    })
  }
}

///|
async fn records(root : String, since_ms : Int64) -> Array[String] {
  let records = []
  if !@fs.exists(root) || @fs.kind(root, follow_symlink=true) != Directory {
    return records
  }

  walk(root, since_ms, records)

  records
}

///|
async fn walk(root : String, since_ms : Int64, records : Array[String]) -> Unit {
  let names = @fs.readdir(root, include_hidden=true)

  for name in names {
    let path = "\{root}/\{name}"
    if !name.has_suffix(".jsonl") {
      continue
    }

    let kind = @fs.kind(path, follow_symlink=true) catch { _ => continue }
    if kind is Regular && !@logfiles.modified_before(path, since_ms) {
      records.push(path)
    }
  }

  for name in names {
    let path = "\{root}/\{name}"
    if @fs.kind(path, follow_symlink=false) is Directory {
      walk(path, since_ms, records)
    }
  }
}
