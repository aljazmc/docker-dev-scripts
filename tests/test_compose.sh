#!/bin/bash
#
# For every environment, "./project.sh compose" writes docker-compose.yml and
# "./project.sh composehack" adds the user line with your UID and GID, once.
# Each runs on a copy of project.sh in a temporary folder, with docker
# replaced by a stand-in, so no container, image or volume is touched.
#
# Run from anywhere: bash tests/test_compose.sh

repo=$(cd "$(dirname "$0")/.." && pwd) || exit 1
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT

# answers "docker compose version", the only call these steps may make
mkdir "$tmp/bin"
cat > "$tmp/bin/docker" <<'EOF'
#!/bin/sh
[ "$1 $2" = "compose version" ] && exit 0
echo "unexpected: docker $*" >&2
exit 1
EOF
chmod +x "$tmp/bin/docker"

user="user: $(id -u):$(id -g)"
failures=0
count=0

fail() {

    echo "FAIL: $1" >&2
    failures=$((failures + 1))

}

for script in "$repo"/*/project.sh; do
    count=$((count + 1))
    name=$(basename "$(dirname "$script")")
    work="$tmp/$name"
    mkdir "$work"
    cp "$script" "$work/project.sh"

    (
        cd "$work" || exit 1
        export PATH="$tmp/bin:$PATH"
        bash project.sh compose && bash project.sh composehack \
            && bash project.sh composehack
    ) > "$work.log" 2>&1 || { fail "$name: compose or composehack failed"; cat "$work.log" >&2; }

    if [ ! -s "$work/docker-compose.yml" ]; then
        fail "$name: no docker-compose.yml"
    elif ! grep -q "^ *services:" "$work/docker-compose.yml"; then
        fail "$name: docker-compose.yml has no services"
    elif ! grep -q "$user" "$work/docker-compose.yml"; then
        fail "$name: docker-compose.yml has no '$user' line"
    elif [ "$(grep -c "Adding user configuration" "$work.log")" -ne 1 ]; then
        fail "$name: composehack added the user line more than once"
    fi

    grep "unexpected: docker" "$work.log" >&2
done

if [ "$failures" -gt 0 ]; then
    echo "FAILED: $failures of $count environments" >&2
    exit 1
fi
echo "PASS: $count environments"
