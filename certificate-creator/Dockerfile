FROM confluentinc/cp-kafka:latest

WORKDIR /app

USER root

COPY ./create-certs.sh /app
COPY ./ssl.conf /app
RUN openssl req -new -x509 -keyout our_ca.key -out our_ca.crt -days 365 -subj "/C=ES/ST=State/L=Location/O=Organisation" -addext "subjectAltName=DNS:whatever" -passin pass:very_secure -passout pass:very_secure
RUN ./create-certs.sh producer
RUN ./create-certs.sh broker
RUN mkdir certs
RUN cp *.jks certs/; cp *creds* certs/;cp *.csr certs/;cp *.pem certs/
RUN cp *.crt certs/; cp *.key certs/;cp *.pub certs/ &

ENTRYPOINT /bin/bash