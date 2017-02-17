SSLEngine On
SSLProtocol all -SSLv2 -SSLv3
SSLCipherSuite ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:+LOW
SSLCertificateFile "/Users/dtwist/Sites/ssl/selfsigned.crt"
SSLCertificateKeyFile "/Users/dtwist/Sites/ssl/private.key"
