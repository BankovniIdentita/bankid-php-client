#!/bin/bash

publicKeyPath="key.public.pem"
privateKeyPath="key.private.pem"

# Check if certificate file path is provided as first parameter
if [ -n "$1" ] && [ -f "$1" ]; then
  certFile="$1"
else
  # Prompt user for subject details
  echo "Enter subject details (CN): "
  read CN

  # Generate new x509 self-signed certificate
  openssl req \
    -x509 \
    -newkey rsa:4096 \
    -sha256
    -keyout "${privateKeyPath}" \
    -out cert.pem \
    -days 3650 \
    -nodes \
    -subj "/CN=$CN" \
    -addext "extendedKeyUsage=codeSigning" \
    -addext "keyUsage=digitalSignature"

  certFile="cert.pem"
fi

if [ ! -f "${privateKeyPath}" ]; then
  echo "Could not find private key in ${privateKeyPath}"
  exit 1
fi

# Output public key
openssl rsa -in "${privateKeyPath}" -outform PEM -pubout -out "${publicKeyPath}"

rsaInfo=$(php <<'EOF'
<?php
  $keyInfo = openssl_pkey_get_details(openssl_pkey_get_public(file_get_contents('key.public.pem')));
  $encode = fn ($val) => rtrim(str_replace(['+', '/'], ['-', '_'], base64_encode($val)), '=');

  echo sprintf(
    "%s:%s",
    $encode($keyInfo["rsa"]["n"]),
    $encode($keyInfo["rsa"]["e"]),
  );
EOF
)

kid=$(uuidgen)
modulus=$(echo "${rsaInfo}" | cut -d':' -f1)
exponent=$(echo "${rsaInfo}" | cut -d':' -f2)
x5c=$(cat "${certFile}" | sed '1d;$d' | tr -d '\n')
x5t=$(openssl x509 -in "${certFile}" -noout -fingerprint -sha256 | cut -d "=" -f 2 | tr -d ":")

# Output JSON Web Key representation
echo "{\"kty\": \"RSA\", \"x5t#S256\": \"$x5t\", \"e\": \"$exponent\", \"use\": \"sig\", \"kid\": \"$kid\", \"x5c\": [\"$x5c\"], \"n\": \"$modulus\"}"
