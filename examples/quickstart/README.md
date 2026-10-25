# Quickstart

The [developer site's quickstart](https://developers.infranest.io/quickstart) as one script: find your sandbox, read
its sample DNS zones, try an `A` record as a dry run, create it, and undo the change from the zone's history. Each
step checks the answer the page shows, so a failing step names itself.

| File | Language |
|---|---|
| [`quickstart.sh`](quickstart.sh) | POSIX sh, curl, jq |

**Token:** a test token made in your sandbox, with DNS → Read and DNS → Write.

```sh
export INFRANEST_TOKEN='123|in_test_…'
./quickstart.sh
```

## Tested against the sandbox

CI runs it against an InfraNest sandbox (`scripts/sandbox-run.sh quickstart`), so the quickstart page and the API
cannot drift apart unnoticed.
