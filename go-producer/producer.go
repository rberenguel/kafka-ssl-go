package main

import (
	"crypto/tls"
	"crypto/x509"
	"net"
	"os"
	"time"

	"github.com/Shopify/sarama"
	"github.com/sirupsen/logrus"
)

func newConfig() (*sarama.Config, error) {
	c := sarama.NewConfig()

	tlsConfig, err := newTLSConfig(
		"../certs/producer.cer.pem",
		"../certs/producer.key.pem",
		"../certs/our_ca.crt",
	)
	if err != nil {
		return nil, err
	}

	c.Net.TLS.Config = tlsConfig
	c.Net.TLS.Enable = true

	c.Producer.Compression = sarama.CompressionSnappy
	c.Producer.Return.Successes = true
	c.Version = sarama.V2_7_0_0 // Match our AWS MSK version.

	return c, nil
}

func newTLSConfig(clientCertFile, clientKeyFile, caCertFile string) (*tls.Config, error) {
	tlsConfig := tls.Config{
		MinVersion: tls.VersionTLS12,
		ServerName: "kafka",
	}

	// Load client cert
	cert, err := tls.LoadX509KeyPair(clientCertFile, clientKeyFile)
	if err != nil {
		return &tlsConfig, err
	}
	tlsConfig.Certificates = []tls.Certificate{cert}

	// Load CA cert
	caCert, err := os.ReadFile(caCertFile)
	if err != nil {
		return &tlsConfig, err
	}
	caCertPool := x509.NewCertPool()
	caCertPool.AppendCertsFromPEM(caCert)

	tlsConfig.RootCAs = caCertPool

	return &tlsConfig, err
}

func newProducer(broker string) (sarama.SyncProducer, error) {
	config, _ := newConfig()
	brokers := []string{broker}
	handshakeTrick(broker, *config.Net.TLS.Config.Clone())
	producer, err := sarama.NewSyncProducer(brokers, config)

	return producer, err
}

func prepareMessage(topic, message string) *sarama.ProducerMessage {
	msg := &sarama.ProducerMessage{
		Topic:     topic,
		Partition: -1,
		Value:     sarama.StringEncoder(message),
	}

	return msg
}

func handshakeTrick(hostWithPort string, tlsConfig tls.Config) {
	dialer := &net.Dialer{
		Timeout: 60 * time.Second,
	}
	rawConn, err := dialer.Dial("tcp", hostWithPort)
	conn := tls.Client(rawConn, &tlsConfig)

	if err != nil {
		logrus.Error("Unable to connect _at all_ with Kafka. Is Docker up?")
		os.Exit(1)
	}
	logrus.Warn("Resolved address ", conn.RemoteAddr())
	err = conn.Handshake()
	logrus.Warn("Handshake error ", err)
	logrus.Warn("Verified hostname error ", conn.VerifyHostname("kafka"))
}

func main() {
	logrus.Info("Started")
	var broker = "kafka:9093"
	if len(os.Args) > 1 {
		broker = os.Args[1]
	}
	producer, err := newProducer(broker)
	if err != nil {
		panic(err)
	}
	partition, offset, err := producer.SendMessage(prepareMessage("foo", "Hello"))
	logrus.WithFields(logrus.Fields{"Partition": partition, "Offset": offset, "Error": err}).Info("Produce result")
}
