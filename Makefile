certs: clean-certs
	mkdir certs
	docker build -f certificate-creator/Dockerfile certificate-creator/ -t certificate-creator
	docker create -ti --name certificate-creator-run certificate-creator /bin/bash
	docker cp certificate-creator-run:/app/certs/ ./
	docker rm -f certificate-creator-run

kafka:
	docker compose -f docker-compose.yml up --quiet-pull -d kafka

docker-producer:
	docker compose -f docker-compose.yml up --quiet-pull producer

all: kafka docker-producer
	

producer:
	cd go-producer; go run . kafka:9092

down:
	docker compose down

clean-certs:
	-rm certs/*.*
	-rmdir certs