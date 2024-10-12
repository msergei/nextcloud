#!/bin/bash

docker compose exec cloud --rm -u 82 cloud sh -c "php /var/www/html/occ maintenance:repair --include-expensive"
