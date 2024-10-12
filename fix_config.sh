#!/bin/bash

docker compose run --rm -u 82 cloud sh -c "runuser -u www-data -- php occ upgrade && runuser -u www-data -- php occ maintenance:repair"
