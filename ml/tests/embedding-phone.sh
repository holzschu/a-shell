#!/bin/sh
# Lead only. Run each phase once from a new owned fixture directory through dash.
set -eu
root=$(pwd)
phase=${1:?Usage: embedding-phone.sh install|measure|matrix|matrix-cpu|bad|request|cancel-run|cancel-window|cancel-observe MODEL_ID [SHA256_OR_UUID_OR_UNITS]}
model=${2:?Model id required}
case "$model" in minilm-l6|qwen3-embedding-0.6b) ;; *) exit 2 ;; esac
# Observation is repeatable; each attempt retains separate receipts.
if test "$phase" != cancel-observe; then
	test ! -e "$root/$phase.started" || { echo 'Phase already submitted; inspect its receipts.' >&2; exit 2; }
	echo EMBEDDING_STARTED > "$root/$phase.started"
fi
record() {
	name=$1
	shift
	set +e
	"$@" > "$root/$name.stdout" 2> "$root/$name.stderr"
	status=$?
	set -e
	echo "$status" > "$root/$name.status"
	return "$status"
}
case "$phase" in
	install)
		pin=${3:?Pass the immutable archive SHA256 from the Mac receipt}
		record identity coreml status
		record install coreml install "$model" "$root/$model.asmodel" --sha256 "$pin"
		record installation-memory coreml unload
		record installed coreml ls "$model"
		;;
	measure)
		units=${3:?Pass cpu or cpu-ane; relaunch the app before each measure phase}
		case "$units" in cpu|cpu-ane) ;; *) exit 2 ;; esac
		record baseline coreml unload
		record identity coreml status
		record "$units-cold" coreml embed "$model" "$root/validation-input.json" --units "$units"
		for attempt in 1 2 3 4 5; do
			record "$units-warm-$attempt" coreml embed "$model" "$root/validation-input.json" --units "$units"
		done
		record unloaded coreml unload
		recovery_status=0
		record recovery coreml embed "$model" "$root/validation-input.json" --units "$units" || recovery_status=$?
		record idle coreml unload
		test "$recovery_status" -eq 0 || exit "$recovery_status"
		;;
	matrix|matrix-cpu)
		unit_list='cpu cpu-gpu cpu-ane'
		if test "$phase" = matrix-cpu; then unit_list=cpu; fi
		for units in $unit_list; do
			record "unload-$units" coreml unload
			record "$units-cold" coreml embed "$model" "$root/validation-input.json" --units "$units"
			record "$units-warm" coreml embed "$model" "$root/validation-input.json" --units "$units"
			record "$units-documents" coreml embed "$model" "$root/documents.json" --units "$units"
			record "$units-queries" coreml embed "$model" "$root/queries.json" --units "$units"
			record "$units-truncated" coreml embed "$model" "$root/truncated.json" --units "$units"
		done
		;;
	bad)
		for name in empty malformed overlength bad-type; do
			if record "$name" coreml embed "$model" "$root/$name.json" --units cpu; then exit 1; else test "$?" -eq 2; fi
			test ! -s "$root/$name.stdout"
		done
		record recovery coreml embed "$model" "$root/validation-input.json" --units cpu
		;;
	request) record request coreml request ;;
	cancel-observe)
		# Invoke through /type while cancel-window runs through /run (serial).
		command -v jq >/dev/null
		attempt=1
		while test -e "$root/observe-$attempt.started"; do attempt=$((attempt + 1)); done
		echo EMBEDDING_STARTED > "$root/observe-$attempt.started"
		request=$(cat "$root/current-request.stdout")
		record "observe-$attempt" coreml status
		test "$request" = "$(cat "$root/current-request.stdout")" || exit 75
		jq -e '.active == 1 and .completed_chunks > 0' "$root/observe-$attempt.stdout" >/dev/null || exit 75
		printf '%s\n' "$request" > "$root/observe-$attempt.request"
		# Written before cancellation so the running phase can require this proof.
		cp "$root/observe-$attempt.stdout" "$root/progress-$request.stdout"
		record "cancel-$request" coreml cancel "$request"
		exit 0
		;;
	cancel-window)
		command -v jq >/dev/null
		round=1
		while test "$round" -le 32; do
			record "window-$round-request" coreml request
			request=$(jq -er '.request' "$root/window-$round-request.stdout")
			printf '%s\n' "$request" > "$root/current-request.tmp"
			mv "$root/current-request.tmp" "$root/current-request.stdout"
			if record "window-$round" coreml embed "$model" "$root/long.json" --units cpu --request "$request"; then
				# Finished before cancellation: retain it and offer the next batch.
				round=$((round + 1))
				continue
			else
				test "$?" -eq 130
			fi
			test ! -s "$root/window-$round.stdout"
			jq -e '.active == 1 and .completed_chunks > 0' "$root/progress-$request.stdout" >/dev/null
			printf '%s\n' "$request" > "$root/cancelled.request"
			printf '%s\n' "$round" > "$root/cancelled.round"
			for suffix in stdout stderr status; do cp "$root/window-$round.$suffix" "$root/cancelled.$suffix"; done
			record after-cancel coreml status
			jq -e '.active == 0 and .queued == 0 and .requests == 0' "$root/after-cancel.stdout" >/dev/null
			record recovery-after-cancel coreml embed "$model" "$root/validation-input.json" --units cpu
			echo EMBEDDING_PHASE_PASS > "$root/$phase.complete"
			exit 0
		done
		echo 'INVALID_FIXTURE: all 32 bounded batches completed before cancellation.' >&2
		exit 1
		;;
	cancel-run)
		request=${3:?Pass the UUID from request.stdout; cancel using a separate foreground route}
		if record cancelled coreml embed "$model" "$root/long.json" --units cpu --request "$request"; then exit 1; else test "$?" -eq 130; fi
		test ! -s "$root/cancelled.stdout"
		record after-cancel coreml status
		record recovery-after-cancel coreml embed "$model" "$root/validation-input.json" --units cpu
		;;
	*) echo 'Unknown phase' >&2; exit 2 ;;
esac
echo EMBEDDING_PHASE_PASS > "$root/$phase.complete"
