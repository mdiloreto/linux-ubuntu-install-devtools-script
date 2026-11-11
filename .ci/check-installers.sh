#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASH_BIN="${TEST_BASH:-/bin/bash}"
if [[ "${1:-}" != --isolated ]]; then
    exec env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$HOME" TEST_BASH="$BASH_BIN" "$BASH_BIN" "$0" --isolated
fi

TMP="$(mktemp -d "$ROOT/.ci/checks.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" USER=installer-check TMPDIR="$TMP/tmp" CALLS="$TMP/calls" TEST_OS=Darwin TEST_ARCH=arm64
mkdir -p "$HOME" "$TMPDIR" "$TMP/bin" "$TMP/dispatch"
printf 'externally managed\n' > "$HOME/.zshrc"
cp "$HOME/.zshrc" "$HOME/.bashrc"
cp "$HOME/.zshrc" "$HOME/.gitconfig"
cp -R "$HOME" "$TMP/home-before"
: > "$CALLS"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
contains() { grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"; }
no_calls() { [[ ! -s "$CALLS" ]] || { cat "$CALLS"; fail "unexpected command execution"; }; }

for script in "$ROOT"/install*.sh "$ROOT/.ci/check-installers.sh"; do
    "$BASH_BIN" -n "$script"
done

cat > "$TMP/bin/uname" <<'EOF'
#!/bin/bash
case "${1:-}" in
    -m) printf '%s\n' "$TEST_ARCH" ;;
    *) printf '%s\n' "$TEST_OS" ;;
esac
EOF
cat > "$TMP/bin/forbidden" <<'EOF'
#!/bin/bash
printf '%s %s\n' "${0##*/}" "$*" >> "$CALLS"
exit 97
EOF
chmod +x "$TMP/bin/uname" "$TMP/bin/forbidden"
for cmd in brew uv rustup sudo curl wget npm pipx apt-cache dpkg lsb_release kubectl chsh git mktemp; do
    ln -s forbidden "$TMP/bin/$cmd"
done
ln -s "$BASH_BIN" "$TMP/bin/bash"
export PATH="$TMP/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Replace only host filesystem constants in disposable copies, never host files.
sed "s|/etc/os-release|$TMP/os-release|g" "$ROOT/install.sh" > "$TMP/dispatch/install.sh"
for os in macos ubuntu arch; do
    cat > "$TMP/dispatch/install-$os.sh" <<'EOF'
#!/bin/bash
printf '%s\n' "${0##*/}"
printf '<%s>\n' "$@"
exit 23
EOF
done
for os in macos ubuntu arch; do
    if [[ "$os" == macos ]]; then
        export TEST_OS=Darwin
        rm -f "$TMP/os-release"
    else
        export TEST_OS=Linux
        printf 'ID=%s\n' "$os" > "$TMP/os-release"
    fi
    status=0
    "$BASH_BIN" "$TMP/dispatch/install.sh" --dry-run -y --skip-shell-config 'two words' > "$TMP/dispatch-output" || status=$?
    [[ "$status" == 23 ]] || fail "$os dispatch did not preserve exit status"
    printf 'install-%s.sh\n<--dry-run>\n<-y>\n<--skip-shell-config>\n<two words>\n' "$os" > "$TMP/expected"
    diff -u "$TMP/expected" "$TMP/dispatch-output"
done
export TEST_OS=Darwin
mkdir "$TMP/remote"
cp "$ROOT/install.sh" "$TMP/remote/install.sh"
"$BASH_BIN" "$TMP/remote/install.sh" --dry-run > "$TMP/remote-output"
contains "$TMP/remote-output" 'install-macos.sh'
no_calls
printf 'PASS: Darwin/Linux dispatch, argument forwarding, exit status and remote dry-run\n'

"$BASH_BIN" "$ROOT/install-macos.sh" --help > "$TMP/help-output"
contains "$TMP/help-output" '--skip-shell-config'
if "$BASH_BIN" "$ROOT/install-macos.sh" --unknown > "$TMP/invalid-output" 2>&1; then
    fail 'unknown option accepted'
fi
if "$BASH_BIN" "$ROOT/install-macos.sh" < /dev/null > "$TMP/unconfirmed-output" 2>&1; then
    fail 'noninteractive install accepted without -y'
fi
no_calls

# Run the real macOS path with a present brew, then exercise the no-brew path.
"$BASH_BIN" "$ROOT/install.sh" --dry-run --skip-shell-config > "$TMP/mac-output"
contains "$TMP/mac-output" 'install --cask orbstack'
contains "$TMP/mac-output" 'install --formula herdr'
contains "$TMP/mac-output" 'install --formula googleworkspace-cli'
contains "$TMP/mac-output" 'npm install -g @shortcut-cli/shortcut-cli'
contains "$TMP/mac-output" 'uv python install 3.13'
contains "$TMP/mac-output" 'google-cloud-cli-darwin-'
contains "$TMP/mac-output" 'components install gke-gcloud-auth-plugin --quiet'
contains "$TMP/mac-output" 'https://awscli.amazonaws.com/v2/install.sh'
for package in ghostty font-ubuntu-mono linearmouse; do
    contains "$TMP/mac-output" "install --cask $package"
done
if grep -Eq 'install --(formula|cask) (python|pipx|awscli|gcloud-cli|azure-cli|ansible|docker-desktop|virtualbox|vagrant|claude|chromium)( |$)' "$TMP/mac-output"; then
    fail "macOS selected an excluded Homebrew package"
fi
sed "s|/opt/homebrew/bin/brew|$TMP/missing-arm-brew|g" \
    "$ROOT/install-macos.sh" > "$TMP/macos-no-brew.sh"
rm "$TMP/bin/brew"
"$BASH_BIN" "$TMP/macos-no-brew.sh" --dry-run -y > "$TMP/no-brew-output"
contains "$TMP/no-brew-output" 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh'
contains "$TMP/no-brew-output" '[dry-run] sudo -n -v'
contains "$TMP/no-brew-output" 'install --formula herdr'
no_calls
diff -r "$TMP/home-before" "$HOME"

# Linux dry-runs exercise optional package and plugin probes as well as Herdr.
printf 'ID=ubuntu\nVERSION_CODENAME=noble\n' > "$TMP/os-release"
for os in ubuntu arch; do
    sed "s|/etc/os-release|$TMP/os-release|g" "$ROOT/install-$os.sh" > "$TMP/install-$os.sh"
    "$BASH_BIN" "$TMP/install-$os.sh" --dry-run --skip-shell-config > "$TMP/$os-output"
    contains "$TMP/$os-output" 'https://herdr.dev/install.sh'
done
no_calls
diff -r "$TMP/home-before" "$HOME"
[[ -z "$(find "$TMPDIR" -mindepth 1 -print)" ]] || fail 'dry-run created temporary files'
rm "$TMP/bin/mktemp"
cat > "$TMP/bin/mktemp-fixture" <<'EOF'
#!/bin/bash
[[ "$*" == -d ]] || exit 98
/usr/bin/mktemp -d "$TMPDIR/installer.XXXXXX"
EOF
chmod +x "$TMP/bin/mktemp-fixture"
ln -s mktemp-fixture "$TMP/bin/mktemp"
printf 'PASS: full dry-runs execute no package/network/plugin commands and change no home files\n'

# A fake upstream installer only writes a fake executable inside this fixture.
cat > "$TMP/herdr-installer" <<'EOF'
#!/bin/sh
mkdir -p "${HERDR_INSTALL_DIR:-$HOME/.local/bin}"
printf '#!/bin/sh\nexit 0\n' > "${HERDR_INSTALL_DIR:-$HOME/.local/bin}/herdr"
chmod +x "${HERDR_INSTALL_DIR:-$HOME/.local/bin}/herdr"
EOF
cat > "$TMP/bin/curl-fixture" <<'EOF'
#!/bin/bash
printf 'curl %s\n' "$*" >> "$CALLS"
while [[ $# -gt 0 ]]; do
    if [[ "$1" == -o ]]; then
        cp "$DOWNLOAD_FIXTURE" "$2"
        exit "${DOWNLOAD_STATUS:-0}"
    fi
    shift
done
exit 98
EOF
chmod +x "$TMP/bin/curl-fixture"
rm "$TMP/bin/curl"
ln -s curl-fixture "$TMP/bin/curl"

cat > "$TMP/bin/sudo-fixture" <<'EOF'
#!/bin/bash
printf 'sudo %s\n' "$*" >> "$CALLS"
[[ "$*" == '-n -v' ]] || exit 98
exit "${SUDO_STATUS:-1}"
EOF
cat > "$TMP/bootstrap-brew" <<'EOF'
#!/bin/bash
printf 'bootstrap-brew %s\n' "$*" >> "$CALLS"
[[ "$*" == --prefix ]] || exit 98
printf '%s\n' "$TEST_BREW_PREFIX"
EOF
cat > "$TMP/bootstrap-installer" <<'EOF'
#!/bin/bash
printf 'bootstrap NONINTERACTIVE=%s\n' "${NONINTERACTIVE:-unset}" >> "$CALLS"
[[ "${BOOTSTRAP_STATUS:-0}" == 0 ]] || exit "$BOOTSTRAP_STATUS"
cp "$BOOTSTRAP_BREW_FIXTURE" "$BOOTSTRAP_BREW"
chmod +x "$BOOTSTRAP_BREW"
EOF
chmod +x "$TMP/bin/sudo-fixture"
rm "$TMP/bin/sudo"
ln -s sudo-fixture "$TMP/bin/sudo"
export DOWNLOAD_FIXTURE="$TMP/bootstrap-installer" BOOTSTRAP_BREW_FIXTURE="$TMP/bootstrap-brew"
export BOOTSTRAP_BREW="$TMP/missing-arm-brew" TEST_BREW_PREFIX="$TMP/bootstrap-prefix"
fresh_failures=0
: > "$CALLS"
status=0
TEST_ARCH=x86_64 BOOTSTRAP_STATUS=97 "$BASH_BIN" "$TMP/macos-no-brew.sh" -y > "$TMP/intel-output" 2>&1 || status=$?
if [[ "$status" == 0 || -s "$CALLS" ]] || ! grep -Fq 'Apple Silicon' "$TMP/intel-output"; then
    printf 'FAIL: Intel reached installation instead of being rejected at entry\n' >&2
    cat "$CALLS"
    fresh_failures=$((fresh_failures + 1))
fi
: > "$CALLS"
status=0
SUDO_STATUS=1 BOOTSTRAP_STATUS=97 "$BASH_BIN" "$TMP/macos-no-brew.sh" -y > "$TMP/denied-output" 2>&1 || status=$?
if [[ "$status" == 0 || "$(cat "$CALLS")" != 'sudo -n -v' ]] || ! grep -Fq 'sudo -v' "$TMP/denied-output"; then
    printf 'FAIL: unattended bootstrap did not stop at noninteractive sudo denial with recovery advice\n' >&2
    cat "$CALLS"
    fresh_failures=$((fresh_failures + 1))
fi
[[ "$fresh_failures" == 0 ]] || fail 'fresh-install regressions'
[[ ! -e "$BOOTSTRAP_BREW" ]] || fail 'denied bootstrap created Homebrew'
diff -r "$TMP/home-before" "$HOME"

for unattended in true false; do
    (
        source "$TMP/macos-no-brew.sh"
        ASSUME_YES="$unattended"
        export SUDO_STATUS=0
        : > "$CALLS"
        prepare_homebrew
        [[ "$BREW" == "$BOOTSTRAP_BREW" && -x "$BREW" ]] || fail 'bootstrap did not find installed Homebrew'
        contains "$CALLS" 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh'
        contains "$CALLS" 'bootstrap-brew --prefix'
        if $ASSUME_YES; then
            [[ "$(head -n 1 "$CALLS")" == 'sudo -n -v' ]] || fail 'sudo preflight did not precede bootstrap'
            contains "$CALLS" 'bootstrap NONINTERACTIVE=1'
        else
            if grep -q '^sudo ' "$CALLS"; then fail 'interactive bootstrap ran sudo preflight'; fi
            contains "$CALLS" 'bootstrap NONINTERACTIVE=unset'
        fi
        : > "$CALLS"
        export SUDO_STATUS=1
        prepare_homebrew
        [[ "$(cat "$CALLS")" == 'bootstrap-brew --prefix' ]] || fail 'existing Homebrew was bootstrapped again'
    ) > "$TMP/bootstrap-$unattended-output" 2>&1
    rm "$BOOTSTRAP_BREW"
done
printf 'PASS: Apple Silicon entry gate and unattended/interactive Homebrew bootstrap preflight\n'

export DOWNLOAD_FIXTURE="$TMP/herdr-installer"
for os in ubuntu arch; do
    (
        # shellcheck source=/dev/null
        source "$ROOT/install-$os.sh"
        export HERDR_INSTALL_DIR="$HOME/$os-herdr"
        : > "$CALLS"
        install_herdr
        [[ -x "$HERDR_INSTALL_DIR/herdr" ]] || fail "$os Herdr installation"
        contains "$CALLS" 'https://herdr.dev/install.sh'
        : > "$CALLS"
        install_herdr
        no_calls
        installed_herdr_dir="$HERDR_INSTALL_DIR"
        PATH="$installed_herdr_dir:$PATH" HERDR_INSTALL_DIR="$HOME/unused" install_herdr
        no_calls
        export HERDR_INSTALL_DIR="$HOME/$os-herdr-failed" DOWNLOAD_STATUS=22
        install_herdr
        [[ ! -e "$HERDR_INSTALL_DIR" ]] || fail 'executed a failed/partial download'
        [[ ${#FAILED[@]} == 1 ]] || fail 'Herdr failure was not recorded'
    ) > "$TMP/herdr-$os-output"
done
printf 'PASS: Linux Herdr install, PATH/custom-dir idempotence and download failure\n'

cat > "$TMP/bin/brew-fixture" <<'EOF'
#!/bin/bash
printf 'brew %s\n' "$*" >> "$CALLS"
case "$1" in
    --prefix) printf '%s\n' "$TEST_BREW_PREFIX" ;;
    list) grep -Fxq -- "$3" "$BREW_INSTALLED" ;;
    install)
        [[ "$3" != "${BREW_FAIL:-}" ]] || exit 1
        printf '%s\n' "$3" >> "$BREW_INSTALLED"
        ;;
    *) exit 98 ;;
esac
EOF
chmod +x "$TMP/bin/brew-fixture"
ln -s brew-fixture "$TMP/bin/brew"
export BREW_INSTALLED="$TMP/brew-installed"
: > "$BREW_INSTALLED"
(
    source "$ROOT/install-macos.sh"
    : > "$CALLS"
    install_herdr
    install_herdr
    [[ "$(grep -c 'brew install --formula herdr' "$CALLS")" == 1 ]] || fail 'brew Herdr reinstalled'
    install_core_tools
    install_core_tools
    [[ "$(grep -c 'brew install --formula googleworkspace-cli' "$CALLS")" == 1 ]] || fail 'gws reinstalled'
    export BREW_FAIL=broken
    brew_install --formula broken
    [[ ${#FAILED[@]} == 1 ]] || fail 'brew failure was not recorded'
    if summary; then fail 'summary masked package failure'; fi
) > "$TMP/brew-output" 2>&1
printf 'PASS: Homebrew Herdr/gws idempotence and failure reporting\n'

cat > "$TMP/bin/npm-fixture" <<'EOF'
#!/bin/bash
printf 'npm %s\n' "$*" >> "$CALLS"
[[ "$*" == 'install -g @shortcut-cli/shortcut-cli' ]] || exit 98
[[ "${NPM_STATUS:-0}" == 0 ]] || exit "$NPM_STATUS"
printf '#!/bin/bash\nexit 0\n' > "${0%/*}/short"
chmod +x "${0%/*}/short"
EOF
chmod +x "$TMP/bin/npm-fixture"
rm "$TMP/bin/npm"
ln -s npm-fixture "$TMP/bin/npm"
(
    source "$ROOT/install-macos.sh"
    : > "$CALLS"
    install_shortcut_cli
    install_shortcut_cli
    [[ "$(cat "$CALLS")" == 'npm install -g @shortcut-cli/shortcut-cli' ]] || fail 'Shortcut CLI installed twice or from wrong package'
    rm "$TMP/bin/short"
    export NPM_STATUS=1
    install_shortcut_cli
    [[ ${#FAILED[@]} == 1 ]] || fail 'Shortcut CLI failure was not recorded'
    if summary; then fail 'summary masked Shortcut CLI failure'; fi
) > "$TMP/shortcut-output" 2>&1
printf 'PASS: Shortcut CLI npm install, installed-command skip and failure reporting\n'

# Stub the entire Python/runtime boundary, including a failing XML health check.
cat > "$TMP/python3.13" <<'EOF'
#!/bin/bash
printf 'python3.13 %s\n' "$*" >> "$CALLS"
exit "${PYTHON_STATUS:-0}"
EOF
cat > "$TMP/bin/uv-fixture" <<'EOF'
#!/bin/bash
printf 'uv %s\n' "$*" >> "$CALLS"
if [[ "$*" == 'python find --managed-python 3.13' ]]; then
    printf '%s\n' "$HEALTHY_PYTHON"
fi
EOF
cat > "$TMP/bin/rustup-fixture" <<'EOF'
#!/bin/bash
printf 'rustup %s\n' "$*" >> "$CALLS"
EOF
chmod +x "$TMP/python3.13" "$TMP/bin/uv-fixture" "$TMP/bin/rustup-fixture"
rm "$TMP/bin/uv" "$TMP/bin/rustup"
ln -s uv-fixture "$TMP/bin/uv"
export TEST_BREW_PREFIX="$TMP/brew-prefix" HEALTHY_PYTHON="$TMP/python3.13"
mkdir -p "$TEST_BREW_PREFIX/opt/rustup/bin"
ln -s "$TMP/bin/rustup-fixture" "$TEST_BREW_PREFIX/opt/rustup/bin/rustup"
(
    source "$ROOT/install-macos.sh"
    : > "$CALLS"
    prepare_homebrew
    install_languages
    [[ "$UV_PYTHON" == "$HEALTHY_PYTHON" ]] || fail 'not using managed Python'
    contains "$CALLS" 'uv python find --managed-python 3.13'
    contains "$CALLS" 'rustup default stable'
    contains "$CALLS" 'python3.13 -c import ssl, xml.parsers.expat'
    contains "$CALLS" "uv tool install --managed-python --python $HEALTHY_PYTHON pipx"
    contains "$CALLS" "uv tool install --managed-python --python $HEALTHY_PYTHON virtualenv"
    contains "$CALLS" "uv tool install --managed-python --python $HEALTHY_PYTHON azure-cli"
    : > "$CALLS"
    export PYTHON_STATUS=1
    install_languages && fail 'unhealthy Python accepted'
    install_google_cloud && fail 'Google SDK accepted unhealthy Python'
    if grep -Eq 'uv tool|curl ' "$CALLS"; then fail 'continued after Python failure'; fi
    [[ ${#FAILED[@]} == 2 ]] || fail 'Python/SDK failure was not recorded'
) > "$TMP/python-output" 2>&1
printf 'PASS: uv-managed Python 3.13 tools and XML/SSL failure gating\n'

mkdir -p "$TMP/sdk/google-cloud-sdk/bin"
cat > "$TMP/sdk/google-cloud-sdk/bin/gcloud" <<'EOF'
#!/bin/bash
[[ "$CLOUDSDK_PYTHON" == "$HEALTHY_PYTHON" ]] || exit 98
printf 'gcloud %s\n' "$*" >> "$CALLS"
case "$*" in
    --version) exit "${GCLOUD_STATUS:-0}" ;;
    'components install gke-gcloud-auth-plugin --quiet') exit "${GKE_STATUS:-0}" ;;
    *) exit 98 ;;
esac
EOF
chmod +x "$TMP/sdk/google-cloud-sdk/bin/gcloud"
tar -czf "$TMP/gcloud.tar.gz" -C "$TMP/sdk" google-cloud-sdk
export DOWNLOAD_FIXTURE="$TMP/gcloud.tar.gz"
for arch in arm64 x86_64; do
    (
        source "$ROOT/install-macos.sh"
        export HOME="$TMP/cloud-$arch" TEST_ARCH="$arch"
        UV_PYTHON="$HEALTHY_PYTHON"
        mkdir -p "$HOME"
        : > "$CALLS"
        install_google_cloud
        [[ -x "$HOME/.local/share/google-cloud-sdk/bin/gcloud" ]] || fail 'SDK archive not installed'
        archive_arch="$arch"
        [[ "$arch" != arm64 ]] || archive_arch=arm
        contains "$CALLS" "google-cloud-cli-darwin-$archive_arch.tar.gz"
        : > "$CALLS"
        install_google_cloud
        printf 'gcloud --version\ngcloud components install gke-gcloud-auth-plugin --quiet\n' > "$TMP/expected-gcloud"
        diff -u "$TMP/expected-gcloud" "$CALLS"
        : > "$CALLS"
        export GCLOUD_STATUS=1
        install_google_cloud && fail 'unhealthy SDK accepted'
        [[ "$(cat "$CALLS")" == 'gcloud --version' ]] || fail 'component install ran after SDK health failure'
        [[ ${#FAILED[@]} == 1 ]] || fail 'SDK health failure was not recorded'
        export GCLOUD_STATUS=0 GKE_STATUS=1
        install_google_cloud
        [[ ${#FAILED[@]} == 2 ]] || fail 'GKE plugin failure was not recorded'
        if summary; then fail 'summary masked GKE plugin failure'; fi
    ) > "$TMP/sdk-$arch-output" 2>&1
done

cat > "$TMP/aws-installer" <<'EOF'
#!/bin/bash
[[ "$XDG_DATA_HOME" == "$HOME/.local" && "$XDG_BIN_HOME" == "$HOME/.local/bin" ]] || exit 98
[[ "$AWS_CLI_INSTALL_SKIP_SIGNATURE_VERIFICATION" == false ]] || exit 98
mkdir -p "$XDG_DATA_HOME/aws-cli"
printf '#!/bin/bash\nprintf "aws %%s\\n" "$*" >> "$CALLS"\n' > "$XDG_DATA_HOME/aws-cli/aws"
chmod +x "$XDG_DATA_HOME/aws-cli/aws"
EOF
export DOWNLOAD_FIXTURE="$TMP/aws-installer"
(
    source "$ROOT/install-macos.sh"
    : > "$CALLS"
    install_aws_cli
    [[ -x "$HOME/.local/aws-cli/aws" ]] || fail 'AWS installed to wrong path'
    contains "$CALLS" 'https://awscli.amazonaws.com/v2/install.sh'
    : > "$CALLS"
    install_aws_cli
    [[ "$(cat "$CALLS")" == 'aws --version' ]] || fail 'existing AWS downloaded again'
) > "$TMP/aws-output"
printf 'PASS: official SDK archive architectures, AWS installer environment and existing SDK reuse\n'

for file in .bashrc .zshrc .gitconfig; do
    cmp "$TMP/home-before/$file" "$HOME/$file"
done
printf 'All installer checks passed (%s).\n' "$BASH_VERSION"
