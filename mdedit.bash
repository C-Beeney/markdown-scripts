#!/bin/bash

fail_on() {
	test -n "${1:-}" && \
		echo "[ERROR] => $1"
	exit 1;
}

command_present() {
        test -z "${1:-}" && fail_on "usage: command_present <binary>"
        command -v "$1" >/dev/null 2>&1
}

setup_tmux() {
	md="$1"      && shift
	session="$1" && shift

	cmd="cat $(printf "%q" "$md") | pandoc | lynx -stdin"

	dir="$(dirname "$md")"
	base="$(basename "$md")"
	name="${base%.*}"

	if tmux has-session -t="$session" 2>/dev/null; then
		exec tmux attach-session -t="$session"
	fi
	
	tmux new-session -d -s "$session" -c "$dir" "nano -0 $(printf "%q" "$md")"
	tmux set -g pane-border-lines double
	tmux split-window -h -t "$session":0.0 -c "$dir" "bash -lc $(printf "%q" "$cmd")"

	(
		old_hash="$(cat "$md" | sha256sum | head -c 8)"
		while true; do
			fswatch -1 $(printf '%q' "$md") >/dev/null

			new_hash="$(cat "$md" | sha256sum | head -c 8)"

			if [[ "$new_hash" != "$old_hash" ]]; then
				old_hash="$new_hash"
				tmux respawn-pane -k -t "$session":0.1 \
					"bash -lc $(printf '%q' "$cmd")"
			fi
		done
	) &

	tmux select-pane -t "$session":0.0

	exec tmux attach-session -t="$session"

}

main() {
	test -z "${1:-}" && fail_on "usage: $0 /path/to/md.md"

	command_present realpath	|| fail_on "missing command: realpath"
	command_present sha256sum	|| fail_on "missing command: sha256sum"
	command_present tmux		|| fail_on "missing command: tmux"
	command_present nano		|| fail_on "missing command: nano"
	command_present pandoc		|| fail_on "missing command: pandoc"
	command_present lynx		|| fail_on "missing command: lynx"
	command_present fswatch		|| fail_on "missing command: fswatch"

	md="$(realpath "$1")"
	test -f "$md" || fail_on "file does not exist: $1"

	session="mdedit_bash_`echo $md | sha256sum | head -c 8`"

	setup_tmux "$md" "$session"


}

set -euo pipefail && main "$@"
