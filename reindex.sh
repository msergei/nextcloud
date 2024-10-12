#!/bin/bash

docker compose exec -u 82 cloud sh -c "php /var/www/html/occ files:scan --all"
