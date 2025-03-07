#!/bin/bash
docker compose down && COMPOSE_BAKE=true docker compose up --build -d && docker compose logs backend frontend -f
