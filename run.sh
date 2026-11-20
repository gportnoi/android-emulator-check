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
S=https://cnt-be0261d6-73d0-4962-bc4e-d4dd35936e97.containerhub.tripleten-services.com
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

st() { echo "== $1"; sleep 2; dumpui | grep -v '^\(FrameLayout\|LinearLayout\|ViewGroup\|View\) |  |  |  | false'; }
curl -s -m 20 -X POST $S/api/v1/orders -H 'Content-Type: application/json' -d '{"firstName":"Anna","lastName":"Volkova","address":"Pine St 7","metroStation":3,"phone":"+78003553538","rentTime":4,"deliveryDate":"2026-11-20","comment":"d","color":["GREY"]}' -w ' HTTP %{http_code}\n'
curl -s -m 20 -X POST $S/api/v1/orders -H 'Content-Type: application/json' -d '{"firstName":"Igor","lastName":"Kuznetsov","address":"Oak Ave 3","metroStation":5,"phone":"+78003553539","rentTime":6,"deliveryDate":"2026-11-20","comment":"e","color":["BLACK"]}' -w ' HTTP %{http_code}\n'


clrfill() { # $1 y of field, $2 text
  adb shell input tap 500 $1; sleep 1; adb shell input keyevent KEYCODE_MOVE_END
  for i in $(seq 1 40); do adb shell input keyevent KEYCODE_DEL; done
  adb shell input text "$2"; adb shell input keyevent 4; sleep 1
}
dologin() { clrfill 690 dupc; clrfill 880 1234; adb shell input tap 540 1090; sleep 3; }
clrfill() { # $1 y of field, $2 text
  adb shell input tap 500 $1; sleep 1; adb shell input keyevent KEYCODE_MOVE_END
  for i in $(seq 1 40); do adb shell input keyevent KEYCODE_DEL; done
  adb shell input text "$2"; adb shell input keyevent 4; sleep 1
}
dologin() { clrfill 690 dupc; clrfill 880 1234; adb shell input tap 540 1090; sleep 3; }

echo "== LOGIN online"
dologin
for i in $(seq 1 14); do sleep 5; adb shell uiautomator dump /sdcard/c.xml >/dev/null 2>&1; adb pull /sdcard/c.xml out/c.xml >/dev/null 2>&1; if grep -qE 'tab_all' out/c.xml; then echo "LOGIN OK after $((i*5))s"; break; fi; done
st X0_after_login
echo "== X1 Accept online, accept dialog shown"
python3 tapt.py Accept; sleep 3; st X1_dialog_online
adb shell cmd connectivity airplane-mode enable; sleep 5
echo "AIRPLANE: $(adb shell settings get global airplane_mode_on)"
echo "== X2 tap No on the accept dialog with no internet"
python3 tapt.py "No"; sleep 3; st X2_after_no_offline; popcheck "X2"
python3 tapt.py "OK"; sleep 2
adb shell cmd connectivity airplane-mode disable; sleep 6
echo "== X3 Accept online again, then lose internet, tap Yes"
python3 tapt.py Accept; sleep 3; st X3_dialog_online_again
adb shell cmd connectivity airplane-mode enable; sleep 5
python3 tapt.py Yes; sleep 4; st X4_after_yes_offline; popcheck "X4"
python3 tapt.py "OK"; sleep 2
adb shell cmd connectivity airplane-mode disable; sleep 8
echo "== X5 state after internet is back"
python3 tapid.py tab_mine; sleep 3; st X5_my_orders
python3 tapid.py tab_all; sleep 3; st X6_all_orders
echo "== DONE"
