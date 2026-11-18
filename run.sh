mkdir -p out
AAPT=$(ls /usr/local/lib/android/sdk/build-tools/*/aapt | tail -1)
echo "== manifest"
$AAPT dump xmltree app.apk AndroidManifest.xml | grep -E 'E: (activity|intent-filter|action|category|service|receiver)|A: android:name|A: android:exported' | head -60
echo "== end"
true
