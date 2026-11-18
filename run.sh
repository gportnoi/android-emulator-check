mkdir -p out
S=https://cnt-ab2d8937-23a9-41e0-bad9-302ddfe8d9ca.containerhub.tripleten-services.com
adb install -r app.apk >/dev/null
echo "== api"; curl -s -m 20 -X POST $S/api/v1/courier -H 'Content-Type: application/json' -d '{"login":"notifqa","password":"1234","firstName":"Notif"}' -w ' HTTP %{http_code}\n'
curl -s -m 20 -X POST $S/api/v1/courier/login -H 'Content-Type: application/json' -d '{"login":"notifqa","password":"1234"}' -w ' HTTP %{http_code}\n'
adb shell am start -n com.yandex.samokat/com.yandex.scooter.app.ui.main.MainActivity >/dev/null; sleep 8
dumpui() { adb shell uiautomator dump /sdcard/u.xml >/dev/null 2>&1; adb pull /sdcard/u.xml out/u.xml >/dev/null 2>&1; python3 - <<'PY'
import re
x=open('out/u.xml').read()
for m in re.finditer(r'<node [^>]*>',x):
    n=m.group(0)
    g=lambda k:(re.search(k+'="([^"]*)"',n) or [None,''])[1]
    print(g('class').split('.')[-1],'|',g('resource-id').split('/')[-1],'|',g('text'),'|',g('content-desc'),'|',g('clickable'),'|',g('bounds'))
PY
}
echo "== UI1"; dumpui
