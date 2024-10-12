#!/bin/bash

docker compose exec -u 82 cloud sh -c "php /var/www/html/occ db:add-missing-indices"
