#!/bin/bash

docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ maintenance:repair --include-expensive"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ db:add-missing-indices"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:set trusted_proxies 0 --value='10.20.0.0/16"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:set forwarded_for_headers --value='[\"HTTP_X_FORWARDED_FOR\"]'"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:set forwarded_for_headers 0 --value='HTTP_X_FORWARDED_PROTO'"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ config:system:set overwriteprotocol --value='https'"
