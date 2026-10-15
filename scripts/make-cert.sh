#!/bin/bash
# Cria UMA VEZ um certificado de assinatura de código auto-assinado ("WinBar Dev") no Keychain de login.
# Com identidade estável, o par (bundle id + assinatura) não muda a cada build e a permissão de
# Acessibilidade concedida continua válida. Nada sai do Mac; a chave privada fica em ~/Library/Keychains.
set -euo pipefail

NAME="WinBar Dev"
if [ "${1:-}" = "--remove" ]; then
  # Remove o certificado e a chave privada do Keychain de login (desinstalação de quem compila do fonte)
  security delete-identity -c "$NAME" "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null \
    || security delete-certificate -c "$NAME" "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null || true
  echo "Identidade \"$NAME\" removida (se existia)."; exit 0
fi
if security find-identity -v -p codesigning | grep -q "\"$NAME\""; then
  echo "Identidade \"$NAME\" já existe."; exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
chmod 700 "$TMP"

cat > "$TMP/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/openssl.cnf" \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" >/dev/null 2>&1
chmod 600 "$TMP/key.pem"
PASS="$(openssl rand -hex 16)"
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" \
  -out "$TMP/cert.p12" -passout "pass:$PASS" -legacy 2>/dev/null \
  || openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" -out "$TMP/cert.p12" -passout "pass:$PASS"

KC="$HOME/Library/Keychains/login.keychain-db"
security import "$TMP/cert.p12" -k "$KC" -P "$PASS" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
# Confia no certificado para assinatura de código (só para este usuário; pode pedir a senha de login)
security add-trusted-cert -r trustRoot -p codeSign -k "$KC" "$TMP/cert.pem"
echo "Identidade \"$NAME\" criada. Se o codesign pedir acesso ao Keychain, clique em \"Sempre permitir\"."
security find-identity -v -p codesigning | grep "$NAME" || true
