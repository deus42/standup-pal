#!/usr/bin/env bash
# One-time setup: creates a self-signed code-signing identity, "StandUp Pal Local Signing",
# in your login keychain. build-app.sh then signs every build with it, so macOS keeps the
# app's permissions (iCloud Drive, Launch at login) across updates, and the app can check
# that an update really comes from you before installing it.
#
#   scripts/make-signing-cert.sh                 # login keychain
#   scripts/make-signing-cert.sh --keychain PATH # another keychain (testing)
#
# The private key never leaves the keychain: the temporary files are deleted.
set -euo pipefail

NAME="StandUp Pal Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
if [[ "${1:-}" == "--keychain" && -n "${2:-}" ]]; then KEYCHAIN="$2"; fi

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "✓ \"$NAME\" already exists:"
  security find-certificate -c "$NAME" -Z "$KEYCHAIN" | grep "SHA-1"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -sha256 -config "$WORK/cert.cnf" \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null
PASS="$(/usr/bin/openssl rand -hex 16)"
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -name "$NAME" \
  -passout "pass:$PASS" -out "$WORK/identity.p12"
# -T lets codesign use the key without a keychain prompt on every build.
security import "$WORK/identity.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign >/dev/null

echo "✓ Created \"$NAME\":"
security find-certificate -c "$NAME" -Z "$KEYCHAIN" | grep "SHA-1"
echo "Builds from scripts/build-app.sh are now signed with it."
