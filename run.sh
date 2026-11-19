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
S=https://cnt-fa4e77f1-da00-4409-80ef-ac607335cb00.containerhub.tripleten-services.com
adb root; sleep 3
adb install -r app.apk >/dev/null
adb shell pm clear com.yandex.samokat
adb shell am force-stop com.yandex.samokat
echo "== server date header"; curl -s -m 20 -D - -o /dev/null $S/api/v1/ping/ | grep -iE '^HTTP|^date'
echo "== api"; curl -s -m 20 -X POST $S/api/v1/courier -H 'Content-Type: application/json' -d '{"login":"dupc","password":"1234","firstName":"DupC"}' -w ' HTTP %{http_code}\n'
ID=$(curl -s -m 20 -X POST $S/api/v1/courier/login -H 'Content-Type: application/json' -d '{"login":"dupc","password":"1234"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
echo "COURIER ID $ID"
adb shell pm list packages | grep -i gms | head -3
echo "== fcm strings in package dump"; adb shell dumpsys package com.yandex.samokat | grep -icE 'firebase|gcm|fcm' || true

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
cat > tapid.py <<'PYI'
import re,sys,subprocess
subprocess.run(['adb','shell','uiautomator','dump','/sdcard/i.xml'],capture_output=True)
subprocess.run(['adb','pull','/sdcard/i.xml','/tmp/i.xml'],capture_output=True)
x=open('/tmp/i.xml').read()
for m in re.finditer(r'<node [^>]*>',x):
    n=m.group(0)
    r=re.search(r'resource-id="([^"]*)"',n)
    r=r.group(1) if r else ''
    if sys.argv[1] in r:
        b=list(map(int,re.findall(r'\d+',re.search(r'bounds="([^"]*)"',n).group(1))))
        cx,cy=(b[0]+b[2])//2,(b[1]+b[3])//2
        print('tapid',sys.argv[1],cx,cy); subprocess.run(['adb','shell','input','tap',str(cx),str(cy)]); break
else: print('ID NOT FOUND',sys.argv[1])
PYI
cat > tapout.py <<'PYO'
import re,subprocess
subprocess.run(['adb','shell','uiautomator','dump','/sdcard/o.xml'],capture_output=True)
subprocess.run(['adb','pull','/sdcard/o.xml','/tmp/o.xml'],capture_output=True)
x=open('/tmp/o.xml').read()
top=None
for m in re.finditer(r'<node [^>]*>',x):
    n=m.group(0)
    t=re.search(r' text="([^"]*)"',n)
    t=t.group(1) if t else ''
    if 'No Internet' in t:
        b=list(map(int,re.findall(r'\d+',re.search(r'bounds="([^"]*)"',n).group(1))))
        top=b[1]; break
if top is None: print('POPUP NOT OPEN')
else:
    y=top-250
    if y<100: y=100
    print('tap outside at 540',y,'popup top',top); subprocess.run(['adb','shell','input','tap','540',str(y)])
PYO
popcheck() { adb shell uiautomator dump /sdcard/p.xml >/dev/null 2>&1; adb pull /sdcard/p.xml out/p.xml >/dev/null 2>&1; if grep -q 'No Internet' out/p.xml; then echo "POPUP VISIBLE: $1"; else echo "POPUP NOT VISIBLE: $1"; fi; }
echo "== order api"
curl -s -m 20 -X POST $S/api/v1/orders -H 'Content-Type: application/json' -d '{"firstName":"Ivan","lastName":"Petrov","address":"State St 1214","metroStation":4,"phone":"+78003553535","rentTime":5,"deliveryDate":"2026-11-19","comment":"call me","color":["BLACK"]}' -w ' HTTP %{http_code}\n'
curl -s -m 20 -X POST $S/api/v1/orders -H 'Content-Type: application/json' -d '{"firstName":"Olga","lastName":"Sidorova","address":"Broadway 55","metroStation":2,"phone":"+78003553536","rentTime":3,"deliveryDate":"2026-11-19","comment":"second door","color":["GREY"]}' -w ' HTTP %{http_code}\n'
curl -s -m 20 -X POST $S/api/v1/orders -H 'Content-Type: application/json' -d '{"firstName":"Petr","lastName":"Smirnov","address":"Lenina 10","metroStation":7,"phone":"+78003553537","rentTime":2,"deliveryDate":"2026-11-20","comment":"third","color":["BLACK"]}' -w ' HTTP %{http_code}\n'
adb shell am start -n com.yandex.samokat/com.yandex.scooter.app.ui.main.MainActivity >/dev/null; sleep 8
st initial_state
adb shell uiautomator dump /sdcard/g.xml >/dev/null 2>&1; adb pull /sdcard/g.xml out/g.xml >/dev/null 2>&1
if grep -q 'tab_all' out/g.xml; then echo ALREADY LOGGED IN, logging out; adb shell input tap 984 136; sleep 2; python3 tapt.py Yes; sleep 2; python3 tapt.py Ok; sleep 2; st after_logout; fi
adb shell input tap 995 2168; sleep 3
st backend_popup
cat > tapfield.py <<'PYF'
import re,subprocess
subprocess.run(['adb','shell','uiautomator','dump','/sdcard/f.xml'],capture_output=True)
subprocess.run(['adb','pull','/sdcard/f.xml','/tmp/f.xml'],capture_output=True)
x=open('/tmp/f.xml').read()
for m in re.finditer(r'<node [^>]*>',x):
    n=m.group(0)
    if 'url_edit' in n:
        b=list(map(int,re.findall(r'\d+',re.search(r'bounds="([^"]*)"',n).group(1))))
        cx,cy=(b[0]+b[2])//2,(b[1]+b[3])//2
        print('tapfield',cx,cy); subprocess.run(['adb','shell','input','tap',str(cx),str(cy)]); break
PYF
python3 tapfield.py; sleep 1
adb shell input text $S; sleep 1
st backend_typed
adb shell input keyevent 4; sleep 1
python3 tapt.py Ok; sleep 2
st backend_closed
adb shell input tap 500 690; sleep 1; adb shell input text dupc; adb shell input keyevent 4; sleep 1
adb shell input tap 500 880; sleep 1; adb shell input text 1234; adb shell input keyevent 4; sleep 1
adb shell input tap 540 1090; sleep 3
st after_login_tap
for i in $(seq 1 14); do sleep 5; adb shell uiautomator dump /sdcard/c.xml >/dev/null 2>&1; adb pull /sdcard/c.xml out/c.xml >/dev/null 2>&1; if grep -qE 'tab_all|swipe_refresh_container|no_order' out/c.xml; then echo "LOGIN OK after $((i*5))s"; break; fi; done
grep -qE 'tab_all|swipe_refresh_container|no_order' out/c.xml && echo LOGIN CONFIRMED || echo LOGIN FAILED
echo "== tab bar nodes"; grep -o 'resource-id="[^"]*tab[^"]*"[^>]*' out/c.xml | head -8
echo "== set device clock BEFORE accepting orders"
adb root; sleep 3
adb shell settings put global auto_time 0; adb shell settings put global auto_time_zone 0
adb shell date 111921462026.00; sleep 2; adb shell date
adb shell am start -n com.yandex.samokat/com.yandex.scooter.app.ui.main.MainActivity >/dev/null; sleep 6
st all_orders
python3 tapt.py Accept; sleep 2
st accept_dialog
python3 tapt.py Yes; sleep 4
st after_accept
adb shell input swipe 540 700 540 1900 500; sleep 3
cat > accept_b.py <<'PYB'
import re,subprocess
subprocess.run(['adb','shell','uiautomator','dump','/sdcard/b.xml'],capture_output=True)
subprocess.run(['adb','pull','/sdcard/b.xml','/tmp/b.xml'],capture_output=True)
x=open('/tmp/b.xml').read()
ay=None; btns=[]
for m in re.finditer(r'<node [^>]*>',x):
    n=m.group(0)
    t=re.search(r' text="([^"]*)"',n)
    t=t.group(1) if t else ''
    b=re.search(r'bounds="([^"]*)"',n)
    if not b: continue
    bb=list(map(int,re.findall(r'\d+',b.group(1))))
    cy=(bb[1]+bb[3])//2; cx=(bb[0]+bb[2])//2
    if t=='Broadway 55': ay=cy
    if t=='Accept': btns.append((cx,cy))
if ay is not None and btns:
    btns.sort(key=lambda p:abs(p[1]-ay))
    print('tap Accept-B',btns[0]); subprocess.run(['adb','shell','input','tap',str(btns[0][0]),str(btns[0][1])])
else: print('ACCEPT-B NOT FOUND', ay, len(btns))
PYB
python3 accept_b.py; sleep 2
python3 tapt.py Yes; sleep 4
echo "== accept dialog for layout (order C, will cancel with No)"
python3 tapt.py Accept; sleep 2
st accept_dialog_c
python3 tapt.py "No"; sleep 3
echo "== alarms right after accepts (clock already 21:4x)"
adb shell date; adb shell dumpsys alarm | grep -iB2 -A6 yandex | head -40
adb shell dumpsys jobscheduler | grep -iB2 -A6 yandex | head -40
python3 tapt.py "My orders"; sleep 3
st my_orders_dup
adb shell uiautomator dump /sdcard/m.xml >/dev/null 2>&1; adb pull /sdcard/m.xml out/m.xml >/dev/null 2>&1
grep -q 'Broadway 55' out/m.xml && echo ORDER B IN MY ORDERS || echo ORDER B MISSING
grep -q 'State St 1214' out/m.xml && echo ORDER A IN MY ORDERS || echo ORDER A MISSING
grep -o 'Complete' out/m.xml | wc -l | sed "s/^/COMPLETE COUNT /"
echo "== API orders for courier $ID"
curl -s -m 20 "$S/api/v1/orders?courierId=$ID&limit=30" > out/orders.json; head -c 1500 out/orders.json; echo
python3 - <<'PY'
import json
d=json.load(open('out/orders.json'))
os=d.get('orders',[])
mine=[o for o in os if o.get('courierId') is not None]
print('ORDERS WITH COURIER ASSIGNED:',len(mine))
print('DISTINCT IDS:',sorted(set(o['id'] for o in mine)))
print('STATUSES:',[(o['id'],o.get('status')) for o in mine])
PY
echo "== foreground notification wait: crossing 21:59 naturally, clock set before accept"
for i in $(seq 1 44); do sleep 25; T=$(adb shell date +%H:%M:%S); N=$(adb shell dumpsys notification --noredact | grep -c 'pkg=com.yandex.samokat'); echo "POLL $T yandex_notif_records=$N"; adb shell dumpsys notification --noredact | grep -iE 'tickerText|android.title|android.text' | grep -viE 'Serial|bootloader' | head -4; if [ "$N" -gt 0 ]; then echo NOTIFICATION DETECTED; break; fi; done
echo "== notifdump final"; adb shell dumpsys notification --noredact | grep -iE 'NotificationRecord|pkg=com.yandex|tickerText|android.title|android.text' | head -40
adb shell cmd statusbar expand-notifications; sleep 3
st shade2
adb shell input keyevent 4; sleep 2
echo "== persistence: switch to Available tab and back"
python3 tapid.py tab_all; sleep 3
st all_orders_again
python3 tapt.py "My orders"; sleep 3
adb shell uiautomator dump /sdcard/m2.xml >/dev/null 2>&1; adb pull /sdcard/m2.xml out/m2.xml >/dev/null 2>&1
grep -o 'Complete' out/m2.xml | wc -l | sed "s/^/COMPLETE COUNT AFTER TAB SWITCH /"
echo "== persistence: force-stop and restart app"
adb shell am force-stop com.yandex.samokat; sleep 2
adb shell am start -n com.yandex.samokat/com.yandex.scooter.app.ui.main.MainActivity >/dev/null; sleep 8
python3 tapt.py "My orders"; sleep 3
st my_orders_after_restart
adb shell uiautomator dump /sdcard/m3.xml >/dev/null 2>&1; adb pull /sdcard/m3.xml out/m3.xml >/dev/null 2>&1
grep -o 'Complete' out/m3.xml | wc -l | sed "s/^/COMPLETE COUNT AFTER RESTART /"
echo "== complete one duplicated card"
python3 tapt.py "Complete"; sleep 3
st complete_dialog
python3 tapt.py Yes; sleep 4
st my_orders_after_complete
adb shell uiautomator dump /sdcard/m4.xml >/dev/null 2>&1; adb pull /sdcard/m4.xml out/m4.xml >/dev/null 2>&1
grep -o 'Complete' out/m4.xml | wc -l | sed "s/^/COMPLETE COUNT AFTER COMPLETE /"
curl -s -m 20 "$S/api/v1/orders?courierId=$ID&limit=30" > out/orders2.json
python3 - <<'PY'
import json
d=json.load(open('out/orders2.json'))
os=[o for o in d.get('orders',[]) if o.get('courierId') is not None]
print('AFTER COMPLETE - STATUSES:',[(o['id'],o.get('status')) for o in os])
PY
echo "== offline tests"
adb shell cmd connectivity airplane-mode enable; sleep 4
python3 tapid.py tab_all; sleep 3
st offline_available
python3 tapt.py "Accept"; sleep 3
st popup_available
popcheck "after Accept tap on Available screen, airplane on"
adb shell input keyevent 4; sleep 2
st popup_back_once
popcheck "after single Back press with popup open"
python3 tapt.py "Accept"; sleep 3
popcheck "retriggered on Available after Back"
python3 tapt.py "My orders"; sleep 3
python3 tapt.py "Complete"; sleep 3
st popup_myorders
popcheck "after Complete tap on My orders, airplane on"
python3 tapt.py "OK"; sleep 2
popcheck "after OK on My orders popup"
python3 tapt.py "Complete"; sleep 3
popcheck "retriggered before outside tap"
python3 tapout.py; sleep 2
st popup_outside2
popcheck "after tap outside popup"
python3 tapt.py "Complete"; sleep 3
popcheck "retriggered before net restore"
adb shell cmd connectivity airplane-mode disable; sleep 5
st popup_still_open_on_net
popcheck "after internet restored with popup open"
python3 tapt.py "OK"; sleep 2
python3 tapt.py "Complete"; sleep 3
st popup_after_restore2
popcheck "after restore + OK + new tap"
adb shell cmd connectivity airplane-mode disable
st final_myorders
