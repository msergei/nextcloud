#!/bin/bash

docker compose exec -u 33 cloud sh -c "php /var/www/html/occ files:scan --all"
