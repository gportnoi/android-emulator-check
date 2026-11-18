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
for i in range(0,len(b),180): print('S:'+b[i:i+180])
print('SNAPEND')
PYEOF
mkdir -p out
S=https://cnt-3f7e5c1c-920a-484f-b83d-c092ad915663.containerhub.tripleten-services.com
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
st() { echo "== $1"; sleep 2; dumpui | grep -v '^\(FrameLayout\|LinearLayout\|ViewGroup\|View\) |  |  |  | false'; python3 snap.py $1; }
st login_screen
adb shell input tap 995 2168; sleep 2
adb shell input tap 400 2164; sleep 1
adb shell input text https://cnt-3f7e5c1c-920a-484f-b83d-c092ad915663.containerhub.tripleten-services.com; sleep 1
adb shell input tap 864 2164; sleep 2
st url_set
adb shell input tap 500 690; adb shell input text notifqa
adb shell input tap 500 880; adb shell input text 1234
adb shell input keyevent 111
st login_filled
adb shell input tap 540 1090; sleep 8
st after_login
