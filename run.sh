mkdir -p out
P=com.yandex.samokat
echo "== dump"
adb shell dumpsys package $P | grep -iE -B1 -A4 'android.intent.action.MAIN|Activity Resolver' | head -40
echo "== activities all"
adb shell dumpsys package $P | grep -iE 'Activity filter|[a-z]+/[.a-zA-Z0-9]+Activity' | sort -u | head -20
echo "== aapt"
AAPT=$(ls /usr/local/lib/android/sdk/build-tools/*/aapt | tail -1); $AAPT dump badging app.apk | grep -iE 'launchable|package:|sdkVersion|application-label'
true
