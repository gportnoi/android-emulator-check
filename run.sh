mkdir -p out
log=out/log.txt
{
echo "== api"; adb shell getprop ro.build.version.sdk
echo "== install"; adb install -r app.apk
echo "== pkgs"; adb shell pm list packages -3
echo "== root"; adb root; sleep 3; adb shell id
echo "== date before"; adb shell date
echo "== set auto_time off"; adb shell settings put global auto_time 0; adb shell settings put global auto_time_zone 0
echo "== set date"; adb shell date 111823592026.00
adb shell date
echo "== airplane"; adb shell cmd connectivity airplane-mode enable; sleep 3; adb shell settings get global airplane_mode_on
adb shell ping -c 1 -W 2 8.8.8.8
adb shell cmd connectivity airplane-mode disable; sleep 3
adb shell ping -c 1 -W 2 8.8.8.8
echo "== launch"; adb shell monkey -p com.yandex.scooter.app -c android.intent.category.LAUNCHER 1; sleep 6
} > $log 2>&1
adb exec-out screencap -p > out/s1.png
adb shell uiautomator dump /sdcard/u1.xml >> $log 2>&1; adb pull /sdcard/u1.xml out/u1.xml >> $log 2>&1
cat $log
echo "== UI texts"
grep -o 'text="[^"]\+"\|content-desc="[^"]\+"\|resource-id="[^"]\+"' out/u1.xml | sort -u | head -60
