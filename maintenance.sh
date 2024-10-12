#!/bin/bash

docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ maintenance:repair --include-expensive"
docker compose run --rm -u 82 cloud sh -c "php /var/www/html/occ db:add-missing-indices"
