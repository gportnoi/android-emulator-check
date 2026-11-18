cat > snap.py <<'PYEOF'
import sys,zlib,struct,base64,subprocess
raw=subprocess.run(['adb','exec-out','screencap'],capture_output=True).stdout
w,h=struct.unpack('<II',raw[:8]); off=len(raw)-w*h*4; px=raw[off:]
f=4; W,H=w//f,h//f
rows=[]
for y in range(H):
    r=bytearray([0]); base=y*f*w*4
    for x in range(W):
        i=base+x*f*4; r+=px[i:i+3]
    rows.append(bytes(r))
def ch(t,d): c=struct.pack('>I',len(d))+t+d; return c+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',W,H,8,2,0,0,0))+ch(b'IDAT',zlib.compress(b''.join(rows),9))+ch(b'IEND',b'')
b=base64.b64encode(png).decode()
print('SNAP',sys.argv[1],len(b))
for i in range(0,len(b),180): print('S:%s:%03d:'%(sys.argv[1],i//180)+b[i:i+180])
print('SNAPEND')
PYEOF
mkdir -p out
S=https://cnt-39843425-4c5d-4389-a973-22bcda266b37.containerhub.tripleten-services.com
adb install -r app.apk >/dev/null
adb shell pm clear com.yandex.samokat
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
st() { echo "== $1"; sleep 2; dumpui | grep -v '^\(FrameLayout\|LinearLayout\|ViewGroup\|View\) |  |  |  | false'; python3 snap.py $1; }
cat > tapt.py <<'PYT'
import re,sys,subprocess
subprocess.run(['adb','shell','uiautomator','dump','/sdcard/t.xml'],capture_output=True)
subprocess.run(['adb','pull','/sdcard/t.xml','/tmp/t.xml'],capture_output=True)
x=open('/tmp/t.xml').read()
for m in re.finditer(r'<node [^>]*>',x):
    n=m.group(0)
    t=re.search(r' text="([^"]*)"',n).group(1)+'|'+re.search(r'content-desc="([^"]*)"',n).group(1)
    if sys.argv[1] in t:
        b=list(map(int,re.findall(r'\d+',re.search(r'bounds="([^"]*)"',n).group(1))))
        cx,cy=(b[0]+b[2])//2,(b[1]+b[3])//2
        print('tap',sys.argv[1],cx,cy); subprocess.run(['adb','shell','input','tap',str(cx),str(cy)]); break
else: print('NOT FOUND',sys.argv[1])
PYT
echo "== order api"
curl -s -m 20 -X POST $S/api/v1/orders -H 'Content-Type: application/json' -d '{"firstName":"Ivan","lastName":"Petrov","address":"State St 1214","metroStation":4,"phone":"+78003553535","rentTime":5,"deliveryDate":"2026-11-18","comment":"call me","color":["BLACK"]}' -w ' HTTP %{http_code}\n'
curl -s -m 20 -X POST $S/api/v1/orders -H 'Content-Type: application/json' -d '{"firstName":"Olga","lastName":"Sidorova","address":"Broadway 55","metroStation":2,"phone":"+78003553536","rentTime":3,"deliveryDate":"2026-11-19","comment":"second door","color":["GREY"]}' -w ' HTTP %{http_code}\n'
adb shell am start -n com.yandex.samokat/com.yandex.scooter.app.ui.main.MainActivity >/dev/null; sleep 8
adb shell input tap 995 2168; sleep 2
adb shell input tap 400 2164; sleep 1
adb shell input text https://cnt-39843425-4c5d-4389-a973-22bcda266b37.containerhub.tripleten-services.com; sleep 1
adb shell input keyevent 4; sleep 1
adb shell input tap 864 2164; sleep 2
adb shell input tap 500 690; sleep 1; adb shell input text notifqa; adb shell input keyevent 4; sleep 1
adb shell input tap 500 880; sleep 1; adb shell input text 1234; adb shell input keyevent 4; sleep 1
adb shell input tap 540 1090; sleep 8
adb shell uiautomator dump /sdcard/c.xml >/dev/null 2>&1; adb pull /sdcard/c.xml out/c.xml >/dev/null 2>&1
if grep -q auth_login_button out/c.xml; then echo "LOGIN RETRY"; adb shell input keyevent 4; sleep 1; adb shell input tap 540 1090; sleep 8; adb shell uiautomator dump /sdcard/c.xml >/dev/null 2>&1; adb pull /sdcard/c.xml out/c.xml >/dev/null 2>&1; grep -q auth_login_button out/c.xml && echo "LOGIN FAILED" || echo "LOGIN OK on retry"; else echo "LOGIN OK"; fi
adb shell input swipe 540 700 540 1900 500; sleep 4
st all_orders
python3 tapt.py Accept; sleep 2
python3 tapt.py Yes; sleep 4
python3 tapt.py Accept; sleep 2
st accept_dialog
python3 tapt.py Yes; sleep 4
st after_accept
python3 tapt.py "My orders"; sleep 3
st my_orders
adb root; sleep 3
adb shell settings put global auto_time 0; adb shell settings put global auto_time_zone 0
echo "== alarms"
adb shell dumpsys alarm | grep -iB2 -A6 yandex | head -40
adb shell date 111921552026.00; sleep 3; adb shell date
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do sleep 20; adb shell date +%H:%M:%S; adb shell dumpsys notification --noredact | grep -iE 'tickerText|android.title|android.text' | grep -viE 'Serial|bootloader' | head -6; done
adb shell cmd statusbar expand-notifications; sleep 3
st shade
python3 tapt.py "2 hours"; sleep 4
st after_tap_notif
adb shell dumpsys window | grep -i mCurrentFocus
adb shell input keyevent 4; sleep 2
adb shell cmd connectivity airplane-mode enable; sleep 4
python3 tapt.py "My orders"; sleep 3
python3 tapt.py "Complete"; sleep 3
st offline_popup
python3 tapt.py "OK"; sleep 2
st offline_ok
python3 tapt.py "Complete"; sleep 3
st offline_popup2
adb shell cmd connectivity airplane-mode disable
