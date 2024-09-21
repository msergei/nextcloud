#!/bin/bash

docker compose exec -u 33 cloud sh -c "php /var/www/html/occ db:add-missing-indices"
