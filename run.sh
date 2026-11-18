mkdir -p out
C=com.yandex.samokat/com.yandex.scooter.app.ui.main.MainActivity
adb shell am start -n $C
sleep 10
adb shell dumpsys window | grep -i mCurrentFocus
adb shell uiautomator dump /sdcard/u1.xml >/dev/null 2>&1; adb pull /sdcard/u1.xml out/u1.xml >/dev/null 2>&1
echo "== UI1"
grep -o 'text="[^"]\+"\|content-desc="[^"]\+"\|resource-id="[^"]\+"' out/u1.xml | sort -u | head -60
adb exec-out screencap -p > out/s1.png
which convert
convert out/s1.png -resize 270x -quality 40 out/s1.jpg; ls -l out/s1.jpg
echo "== B64"; base64 -w 200 out/s1.jpg; echo "== B64END"
true
