#!/bin/bash

docker-compose exec cloud sh -c "apk update && apk add sudo && sudo -u www-data php /var/www/html/occ db:add-missing-indices"
