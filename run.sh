mkdir -p out
P=com.yandex.samokat
adb shell monkey -p $P -c android.intent.category.LAUNCHER 1
sleep 8
adb shell dumpsys window | grep -i mCurrentFocus
adb shell uiautomator dump /sdcard/u1.xml >/dev/null 2>&1; adb pull /sdcard/u1.xml out/u1.xml >/dev/null 2>&1
echo "== UI1"
grep -o 'text="[^"]\+"\|content-desc="[^"]\+"\|resource-id="[^"]\+"' out/u1.xml | sort -u | head -60
adb exec-out screencap -p > out/s1.png; ls -l out/s1.png
echo "== activities"
adb shell cmd package query-activities -a android.intent.action.MAIN -c android.intent.category.LAUNCHER $P | grep -i name
