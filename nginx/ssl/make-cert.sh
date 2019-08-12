#!/bin/bash
DOMAIN=$1
# Create a 2048 bit private key If the ssl directory doesn't exist, please create it first
openssl genrsa -out $DOMAIN".key" 2048
#The code above has examples in the fields which you should fill for your certificate.
echo "Please set the Common Name/FQDN to the url you're running GitLab." echo "If you run your GitLab instance on 
git.yourdomain.com, please your git.yourdomain.com as FQDN!"
# This command generates the certificate signing request
openssl req -new -key $DOMAIN".key" -out $DOMAIN".csr"
#Now you can finish this up and create the signed certificate
openssl x509 -req -days 3650 -in $DOMAIN".csr" -signkey $DOMAIN".key" -out $DOMAIN".crt"
