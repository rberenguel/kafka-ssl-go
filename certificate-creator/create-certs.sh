#!/bin/bash
set -u -e

SOURCE=$1
PASSWORD=very_secure

# Create keystore for Kafka
keytool -genkey -noprompt \
  -alias $SOURCE \
  -dname "o=Organisation, c=ES" \
  -ext "SAN=DNS:kafka" \
  -keystore kafka.$SOURCE.keystore.jks \
  -keyalg RSA \
  -validity 365 \
  -storetype pkcs12 \
  -storepass $PASSWORD \
  -keypass $PASSWORD

# Create CSR (certificate signing request)
keytool -keystore kafka.$SOURCE.keystore.jks -alias $SOURCE -certreq -file $SOURCE.csr -storepass $PASSWORD -keypass $PASSWORD -ext SAN=DNS:kafka

# Get CSR Signed with the CA:
openssl x509 -req -CA our_ca.crt -CAkey our_ca.key -in $SOURCE.csr -out $SOURCE-ca-signed.crt -days 365 -CAcreateserial -passin pass:$PASSWORD -extensions req_ext -extfile ssl.conf

# Verify certificate is legit, just so we know how to do it
openssl verify -CAfile our_ca.crt $SOURCE-ca-signed.crt

# Import CA certificate in keystore (for JVM targets)
keytool -keystore kafka.$SOURCE.keystore.jks -alias CARoot -import -file our_ca.crt -storepass $PASSWORD -keypass $PASSWORD -ext SAN=DNS:kafka -noprompt

# Extract public and private key for $SOURCE, for kafkacat or go, or other languages
keytool -importkeystore -srckeystore kafka.$SOURCE.keystore.jks -destkeystore kafka.$SOURCE.keystore.p12 -deststoretype PKCS12 -storepass $PASSWORD -keypass $PASSWORD -srckeypass $PASSWORD -srcstorepass $PASSWORD -noprompt -alias $SOURCE
openssl pkcs12 -in kafka.$SOURCE.keystore.p12 -nodes -out $SOURCE.key -passin pass:$PASSWORD
openssl pkcs12 -in kafka.$SOURCE.keystore.p12 -nokeys -out $SOURCE.cer.pem -passin pass:$PASSWORD
openssl pkcs12 -in kafka.$SOURCE.keystore.p12 -nodes -nocerts -out $SOURCE.key.pem -passin pass:$PASSWORD
openssl rsa -in $SOURCE.key -pubout > $SOURCE.pub

# Delete exported keystore since it's no longer needed
rm kafka.$SOURCE.keystore.p12

# Import signed CSR In keystore
keytool -keystore kafka.$SOURCE.keystore.jks -alias $SOURCE -import -file $SOURCE-ca-signed.crt -storepass $PASSWORD -keypass $PASSWORD -ext SAN=DNS:kafka -noprompt

# Import CA certificate In truststore
keytool -keystore kafka.$SOURCE.truststore.jks -alias CARoot -import -file our_ca.crt -storepass $PASSWORD -keypass $PASSWORD -ext SAN=DNS:kafka -noprompt

# Create credential files in case they are needed for anything
echo "$PASSWORD" > ${SOURCE}_sslkey_creds
echo "$PASSWORD" > ${SOURCE}_keystore_creds
echo "$PASSWORD" > ${SOURCE}_truststore_creds