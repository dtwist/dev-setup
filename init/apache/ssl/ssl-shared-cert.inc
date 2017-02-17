SSLEngine On
SSLProtocol all -SSLv2 -SSLv3
SSLCipherSuite ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:+LOW
SSLCertificateFile "/usr/local/etc/apache2/2.4/server.crt"
SSLCertificateKeyFile "/usr/local/etc/apache2/2.4/server.key"
