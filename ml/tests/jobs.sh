#!/bin/sh
# Real CLI and filesystem boundaries. Use an installed MNIST and fresh output.
set -eu
command=${1:?Pass host coreml executable}
root=${2:?Pass a fresh canonical absolute job parent}
fixture=${3:?Pass the package-side known-answer image}
test -f "$fixture"
mkdir -p "$root"
# A platform may expose the app home under multiple names (iOS /private/var and
# /var). Only aliases of the trusted home may bypass ancestor no-follow walking.
model_home=${CFFIXED_USER_HOME:-$HOME}
home_job=asml-home-$(uuidgen)
ln -s "$model_home" "$root/home-alias"
if "$command" job create "$model_home"; then exit 1; else test "$?" -eq 2; fi
"$command" job create "$root/home-alias/$home_job" > "$root/home-create.json"
"$command" job status "$model_home/$home_job" > "$root/home-status.json"
jq -e --slurpfile created "$root/home-create.json" '.job == $created[0].job and .state == "prepared"' "$root/home-status.json"
ln -s "$model_home/$home_job" "$model_home/$home_job-link"
if "$command" job status "$root/home-alias/$home_job-link"; then exit 1; else test "$?" -eq 2; fi
"$command" job create "$root/one" > "$root/create.json"
jq -e '.state == "prepared" and (.job | length == 36)' "$root/create.json"
"$command" job run "$root/one" coreml run mnist "$fixture" > "$root/submission.json"
"$command" job status "$root/one" > "$root/status.json"
jq -e '.state == "done" and .exit_code == 0' "$root/status.json"
jq -e '.runs[0].label == "7"' "$root/one/stdout"
test ! -s "$root/one/stderr"
if "$command" job run "$root/one" coreml run mnist "$fixture"; then exit 1; else test "$?" -eq 75; fi
"$command" job create "$root/error"
if "$command" job run "$root/error" coreml run mnist "$root/missing"; then exit 1; else test "$?" -eq 2; fi
jq -e '.state == "done" and .exit_code == 2' "$root/error/result.json"
test ! -s "$root/error/stdout"
test -s "$root/error/stderr"
"$command" job create "$root/unsafe"
ln -s "$root/one/stdout" "$root/unsafe/cancel"
if "$command" job run "$root/unsafe" coreml run mnist "$fixture"; then exit 1; else test "$?" -eq 2; fi
ln -s "$root/one" "$root/link"
if "$command" job status "$root/link"; then exit 1; else test "$?" -eq 2; fi
"$command" job create "$root/cancelled"
jq -jr '.job' "$root/cancelled/result.json" > "$root/cancelled/cancel"
if "$command" job run "$root/cancelled" coreml run mnist "$fixture"; then exit 1; else test "$?" -eq 130; fi
jq -e '.state == "done" and .exit_code == 130' "$root/cancelled/result.json"
test ! -s "$root/cancelled/stdout"
test -f "$root/cancelled/stdout"
"$command" run mnist "$fixture" > "$root/recovery.json"
jq -e '.runs[0].label == "7"' "$root/recovery.json"
if "$command" run mnist "$fixture" --iterations 10000001; then exit 1; else test "$?" -eq 2; fi
"$command" job create "$root/restart"
"$command" job run "$root/restart" coreml run mnist "$fixture" --iterations 100000 > "$root/restart-submit.stdout" 2> "$root/restart-submit.stderr" &
job_pid=$!
attempt=0
while ! jq -e '.state == "running" and .completed_chunks > 0' "$root/restart/result.json" > /dev/null; do
	attempt=$((attempt + 1))
	if [ "$attempt" -gt 400 ]; then echo 'No active restart fixture' >&2; exit 1; fi
	sleep 0.05
done
kill -KILL "$job_pid"
if wait "$job_pid"; then exit 1; else test "$?" -eq 137; fi
"$command" job status "$root/restart" > "$root/interrupted.json"
jq -e '.state == "interrupted" and .exit_code == 75 and .completed_chunks > 0' "$root/interrupted.json"
if "$command" job run "$root/restart" coreml run mnist "$fixture"; then exit 1; else test "$?" -eq 75; fi
"$command" run mnist "$fixture" > "$root/after-restart.json"
jq -e '.runs[0].label == "7"' "$root/after-restart.json"
echo COREML_JOBS_PASS
