# Nextcloud Server

Nextcloud Server uses official Nextclod docker images, but additional it uses nginx for ssl.

### Arch
- arm64v8 (or arm64 or aarch64)

## How to install?

- You need install docker and docker-compose. Please use official manuals.

- Download or clone repo:
```
git clone https://github.com/msergei/nextcloud.git
cd nextcloud
```

- Make certificates for https. You can use your own certificate or create it:
```
cd nginx/ssl
chmod +x make-sert.sh
bash make-sert.sh localhost
```
Or put your own certificate to ssl folder and rename it to localhost.

- If you want you can change mariadb user credential in file 'db.env'

- Start services in project root folder:
```
cd ../../
docker-compose up -d
```

## How to use?

- Nextcloud Server web page:
```
https://MACHINE_IP/
```

- Webdav address:
```
https://MACHINE_IP/remote.php/webdav/
```