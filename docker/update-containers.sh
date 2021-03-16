#!/bin/bash

for file in `find . -name *.yml -not -path "./.*" -not -name "traefik.yml" 2>/dev/null
`
do
	docker-compose -f $file pull && docker-compose -f $file up -d
done
