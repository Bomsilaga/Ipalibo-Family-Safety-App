#!/usr/bin/env bash
set -euo pipefail

git clone --depth 1 -b stable https://github.com/flutter/flutter.git /tmp/flutter
export PATH="/tmp/flutter/bin:$PATH"

flutter config --no-analytics
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"
