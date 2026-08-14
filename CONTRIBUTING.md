# Contributing to WordFlow

Thank you for helping make WordFlow a better open-source vocabulary-learning
experience. Contributions of all sizes are welcome: bug reports, accessibility
improvements, documentation, vocabulary resources, tests, and product features.

## Local setup

```bash
git clone https://github.com/mikufoxxx/WordFlow.git
cd WordFlow
flutter pub get
flutter run
```

WordFlow currently requires Flutter 3.6.0+ and Dart 3.0.0+.

## Before opening a pull request

1. Create a focused branch from `dev`.
2. Keep changes small and explain their user impact.
3. Format, analyze, and test the project locally:

   ```bash
   dart format <changed Dart files>
   flutter analyze
   flutter test
   ```

4. Update `CHANGELOG.md` when a change is visible to learners or affects
   maintainers.
5. Add or update tests when you change business logic.

## Design and data guidelines

- Preserve WordFlow's local-first learning records. Do not send learning data
  to a network service unless the user explicitly opts in.
- Never commit API keys, generated keystores, device data, or exported learning
  records.
- Keep AI-backed features optional and ensure the non-AI learning path remains
  usable.
- Prefer accessible labels, clear Chinese copy, responsive layouts, and light/
  dark theme support for new UI.

## Reporting issues

Use the provided GitHub issue forms for bugs and feature requests. A useful bug
report includes the app version, device or platform, clear reproduction steps,
the expected result, the actual result, and relevant logs or screenshots with
personal information removed.

## Pull request review

Pull requests are easier to review when they describe the motivation, list the
tests run, and include screenshots or a short recording for UI changes. Please
respond to review feedback in the same thread so the project history remains
helpful to future contributors.
