#!/bin/bash

docker-compose run nextcoud sh -c "apk update && apk add sudo && sudo -u www-data php /var/www/html/occ files:scan --all"