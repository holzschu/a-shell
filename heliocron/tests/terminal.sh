#!/bin/sh
# Run inside a-Shell with native Dash, Python 3 and the location command.
set -eu
work=${1:?Absolute fresh result directory required}
mkdir -p "$work"
cd "$work"
printf '%s\n' location >phase
location --timeout 15 2>location.err | python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["provider"]=="corelocation"; assert -90<=x["latitude"]<=90 and -180<=x["longitude"]<=180; print(x["latitude"],x["longitude"])' >coordinates
set -- $(cat coordinates)
printf '%s\n' report >phase
heliocron -l "$1" -o "$2" report >report.txt 2>report.err
heliocron -l "$1" -o "$2" report --json >report.json 2>report-json.err
python3 -c 'import json; x=json.load(open("report.json")); assert x["sunset"] and x["sunrise"] and x["day_length"]>0; assert "Sunset" in open("report.txt").read()'
heliocron -l 51.4769 -o -0.0005 -d 2024-06-21 -t +00:00 report --json >reference.json 2>reference.err
python3 -c 'import json,datetime; x=json.load(open("reference.json")); t=datetime.datetime.fromisoformat(x["sunset"]); assert t.date()==datetime.date(2024,6,21); assert 20*3600+15*60<=t.hour*3600+t.minute*60+t.second<=20*3600+30*60'
printf '%s\n' error-and-reentry >phase
heliocron --help >help.out 2>help.err
set +e
heliocron --invalid >invalid.out 2>invalid.err
status=$?
set -e
printf '%s\n' "$status" >invalid.status
[ "$status" -eq 2 ]
mkdir reentry-cwd
cd reentry-cwd
TERM=dumb heliocron -l "$1" -o "$2" report --json >../reentry.json 2>../reentry.err
cd ..
python3 -c 'import json; assert json.load(open("report.json"))==json.load(open("reentry.json"))'
printf '%s\n' wait >phase
python3 -c 'import datetime,json,time; sunset=datetime.datetime.fromisoformat(json.load(open("report.json"))["sunset"]).timestamp(); target=int(time.time())+60; n=target-int(sunset); sign="-" if n<0 else ""; n=abs(n); assert n<86400; json.dump({"start":time.time(),"monotonic":time.monotonic(),"target":target},open("wait-plan.json","w")); print(f"{sign}{n//3600:02}:{n//60%60:02}:{n%60:02}")' >offset
heliocron -l "$1" -o "$2" wait --event sunset --offset "$(cat offset)" >wait.out 2>wait.err
printf '%s\n' 0 >wait.status
python3 -c 'import json,time; p=json.load(open("wait-plan.json")); elapsed=time.monotonic()-p["monotonic"]; lateness=time.time()-p["target"]; assert 55<=elapsed<=75,(elapsed,lateness); assert -0.1<=lateness<=5,(elapsed,lateness); json.dump({"report":True,"reference_sunset":True,"invalid_status":2,"reentry":True,"sunset_wait_status":0,"elapsed_seconds":elapsed,"lateness_seconds":lateness},open("result.json","w"),indent=2)'
printf '%s\n' ordinary-command-returned >ordinary.out
printf '%s\n' complete >phase
