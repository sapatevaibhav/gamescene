#!/bin/sh
# Measures frame times on the Android phone connected over adb.
#
#   platform/perf-phone.sh               # every style at Battery saver, Balanced and High
#   platform/perf-phone.sh anime blocky  # just those styles, Battery saver with a breakdown
#
# Builds a debug APK that starts straight into `--perf` (the export preset is
# put back afterwards), installs it (app data is kept), runs it, and saves
# the "perf:" lines to build/perf/perf-<date>-<gpu>.log. Keep the phone
# unlocked with the app on screen until it says PERF DONE.
#
# Afterwards the normal (debug) build is put back on the phone: the perf
# build starts a run at every launch and closes the app when it's done.
set -e
cd "$(dirname "$0")/.."
PKG=com.gamescene.studio
adb get-state >/dev/null 2>&1 || { echo "No phone found: connect it and allow USB debugging."; exit 1; }
ARGS="-- --perf $*"
cp export_presets.cfg build/.export_presets.cfg.bak 2>/dev/null || { mkdir -p build && cp export_presets.cfg build/.export_presets.cfg.bak; }
restore() { cp build/.export_presets.cfg.bak export_presets.cfg && rm -f build/.export_presets.cfg.bak; }
trap restore EXIT
# Only the phone preset (the first Android one) starts into the perf run.
awk -v a="$ARGS" '/^name="Android"$/ {inside=1} inside && /^command_line\/extra_args=/ {print "command_line/extra_args=\"" a "\""; inside=0; next} {print}' \
	build/.export_presets.cfg.bak > export_presets.cfg
RELEASE=0 platform/export.sh android
restore
trap - EXIT
adb install -r build/android/GameSceneStudio.apk
mkdir -p build/perf
gpu=$(adb shell getprop ro.hardware.egl 2>/dev/null | tr -dc 'a-zA-Z0-9')
out="build/perf/perf-$(date +%Y%m%d-%H%M)-${gpu:-phone}.log"
adb logcat -c
adb shell am force-stop $PKG
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
echo "Measuring; keep the phone unlocked with the app open. Results: $out"
# The log reader runs in the background; stop it once the run says it's
# done (or after 20 minutes), since logcat itself never ends.
adb logcat -s godot:I | grep --line-buffered -E 'perf:|PERF DONE|SCRIPT ERROR' | sed -u 's/^.*godot *: //' > "$out" &
reader=$!
i=0
until grep -q "PERF DONE" "$out" 2>/dev/null || [ $i -ge 1200 ]; do
	sleep 2
	i=$((i + 2))
done
kill $reader 2>/dev/null || true
pkill -f "adb logcat -s godot:I" 2>/dev/null || true
cat "$out"
echo "Saved $out"
echo "Putting the normal build back on the phone..."
adb shell am force-stop $PKG
RELEASE=0 platform/export.sh android
adb install -r build/android/GameSceneStudio.apk
