---
name: run-pillr-unit-tests
description: Run the Pillr unit test suite and start fixing failures when the user asks to run, rerun, or check Pillr unit tests or the PillrTests scheme.
---

# Run Pillr Unit Tests

Use this skill when the user wants the Pillr unit tests run again and wants failures fixed.

## What to run

From the Pillr project folder, run:

```bash
xcodebuild test -scheme PillrTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'
```

## What to report

- Say whether the tests passed or failed.
- If they failed, give the failing test names and the main reason in plain language.
- If the chosen simulator is unavailable, list available simulators and retry with a close iPhone simulator.
- If tests fail and the cause is inside the project, start fixing the problem, rerun the tests, and report the result.
- If the failure is caused by the environment, simulator availability, signing, or an external package issue, say that clearly and stop.

## Notes

- This is for unit tests only, not UI tests.
- Keep the reply short and focused on the result.
