# MyServe

## Run the Flutter app

MyServe initializes Supabase at startup. Supply the publishable key as a
build-time define; the project URL defaults to the current Supabase project URL
and can also be overridden:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

For builds, pass the same `--dart-define` options to the relevant `flutter build`
command. Do not put secret service-role keys in a Flutter client application.
