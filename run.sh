#!/bin/bash
docker compose down -v && COMPOSE_BAKE=true docker compose up --build -d && docker compose logs backend -f
