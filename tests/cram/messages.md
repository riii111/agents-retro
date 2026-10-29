# messages

`messages` が会話ログから成果物と標準出力を作るまでを、匿名の小さな合成ログで確認する。
`--days` は十分に大きくして、固定した記録日時がすべて期間に入るようにする。

## 準備

```mooncram
$ export HOME="$PWD/home"
> cp -R "$TESTDIR/fixtures/messages/." .
> today=$(date +%Y-%m-%d)
> touch "out/$today-unmatched-02.tsv"
```

## 標準出力

前回の集計は、同じ日の `metrics.json` を除いて日付が最も新しいものを使う。

```mooncram
$ main.exe messages --days 18000 --patterns patterns.json --out-dir out
Owner messages: 8 in 5 sessions (agent-to-agent messages excluded: 1)
  claude/main: 5
  claude/worker: 1
  codex/user: 1
  codex/worker: 1

Patterns (messages / sessions)  vs 2000-01-08
  review: 2 / 2  (was 1 / 1)
  fix: 3 / 3

Unmatched by any pattern: 3

Examples: out/????-??-??-examples.tsv (glob)
Unmatched: out/????-??-??-unmatched-01.tsv (glob)
Messages (full text, line number = id): out/????-??-??-messages.tsv (glob)
```

## 成果物

同じ日の古い未一致ファイルは消え、別の日のファイルは残る。

```mooncram
$ ls out
2000-01-01-metrics.json
2000-01-01-unmatched-01.tsv
2000-01-08-metrics.json
????-??-??-examples.tsv (glob)
????-??-??-messages.tsv (glob)
????-??-??-metrics.json (glob)
????-??-??-unmatched-01.tsv (glob)
```

全文は1行に整形される。
重複した記録と、サイドチェーン・メタ情報・注入文・期間前の記録は含まれない。
複製された記録の所属セッションは読み込み順で決まるため、セッション列は除く。

```mooncram
$ cut -f1-4,6- "out/$today-messages.tsv"
1\t2026-10-20T01:00\tclaude\tmain\t/Users/me/work/app\tレビューをお願いします (escaped)
2\t2026-10-20T02:00\tclaude\tmain\t/Users/me/work/app\tfix the typed bug please second part (escaped)
3\t2026-10-20T03:00\tclaude\tmain\t/Users/me/work/app\tところで今日の天気は (escaped)
4\t2026-10-20T04:01\tcodex\tuser\t/Users/me/work/cx\treview the diff (escaped)
5\t2026-10-20T04:30\tclaude\tmain\t/Users/me/work/app\tfix: フォーク後の追記 (escaped)
6\t2026-10-20T05:00\tclaude\tworker\t/Users/me/.codex/worktrees/ab12/app\tfix: ワーカーの修正 (escaped)
7\t2026-10-20T06:00\tclaude\tmain\t/Users/me/work/app\tああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああ😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀 (escaped)
8\t2026-10-20T07:02\tcodex\tworker\t/Users/me/.codex/worktrees/cd34/cx\t調整してください (escaped)
```

例は、パターンごとに異なるセッションから最大3件を取る。

```mooncram
$ cat "out/$today-examples.tsv"
review\t1\tmain-1\tレビューをお願いします (escaped)
review\t4\t0123abcd-0123-4567-89ab-0123456789ab\treview the diff (escaped)
fix\t2\tmain-1\tfix the typed bug please second part (escaped)
fix\t5\tmain-1-fork\tfix: フォーク後の追記 (escaped)
fix\t6\twork-1\tfix: ワーカーの修正 (escaped)
```

長い発言は先頭140字と末尾60字に省略され、サロゲートペアは分割されない。

```mooncram
$ cat "out/$today-unmatched-01.tsv"
3\tところで今日の天気は (escaped)
7\tああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああああ …[250字]… 😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀 (escaped)
8\t調整してください (escaped)
```

```mooncram
$ cat "out/$today-metrics.json"
{
 "since": "\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{6}\+00:00", (re)
 "messages": 8,
 "sessions": 5,
 "delegated": 1,
 "by_role": {
  "claude/main": 5,
  "claude/worker": 1,
  "codex/user": 1,
  "codex/worker": 1
 },
 "unmatched": 3,
 "patterns": {
  "review": {
   "messages": 2,
   "sessions": 2
  },
  "fix": {
   "messages": 3,
   "sessions": 3
  }
 }
} (no-eol)
```

## 再実行

同じ日に再実行しても、前回の集計は変わらない。

```mooncram
$ main.exe messages --days 18000 --patterns patterns.json --out-dir out | grep ' vs '
Patterns (messages / sessions)  vs 2000-01-08
```

## 該当なし

期間内の発言がない場合は、空の成果物を書く。

```mooncram
$ main.exe messages --days 0 --patterns patterns.json --out-dir empty
Owner messages: 0 in 0 sessions (agent-to-agent messages excluded: 0)

Patterns (messages / sessions)
  review: 0 / 0
  fix: 0 / 0

Unmatched by any pattern: 0

Examples: empty/????-??-??-examples.tsv (glob)
Messages (full text, line number = id): empty/????-??-??-messages.tsv (glob)
```

```mooncram
$ ls empty
????-??-??-examples.tsv (glob)
????-??-??-messages.tsv (glob)
????-??-??-metrics.json (glob)
```

```mooncram
$ test -s "empty/$today-messages.tsv" || echo empty
empty
```

## 不正なパターン

```mooncram
$ echo '[]' > bad.json
> main.exe messages --patterns bad.json --out-dir bad-out 2>/dev/null
[1]
```
