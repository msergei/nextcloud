# Nextcloud Server

Nextcloud Server uses official Nextclod docker images, but additional it uses nginx for ssl.

### Support archs:
- amd64
- arm64 (aarch64)
- arm32 (armhf)

## How to install?

- You need to install docker and docker-compose. Please use official manuals.

- Download or clone repo:
```
git clone https://github.com/msergei/nextcloud.git
cd nextcloud
```

- Make certificates for https. You can use your own certificate or create it:
```
cd nginx/ssl
chmod +x make-cert.sh
bash make-cert.sh localhost
```
Or put your own certificate to ssl folder and rename it to localhost.

- Copy nextcloud.env.example to nextcloud.env and change credentials there:
```
cp nextcloud.env.example nextcloud.env
```

- You can add platform directive to docker-compose.override.yml:
```
version: '3.9'

services:
  db:
    platform: linux/arm64/v8

  redis:
    platform: linux/arm64/v8

  cloud:
    platform: linux/arm64/v8

  nginx:
    platform: linux/arm64/v8

  cron:
    platform: linux/arm64/v8

```

- Copy docker-compose.override.example to docker-compose.override.yml and change DOMAIN name:
```
cp docker-compose.override.example docker-compose.override.yml
```

- Start services in project root folder:
```
docker-compose up -d
```

## How to use?

- Nextcloud Server web page (the first start is about 3 minutes):
```
https://MACHINE_IP/
```

- Webdav address:
```
https://MACHINE_IP/remote.php/webdav/
```

- How to fix encoding file names problems?
```
convmv -f utf-8 -t utf-8 -r --notest --nfc ./
```