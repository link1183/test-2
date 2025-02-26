#!/bin/bash
docker compose down -v && docker compose up --build -d && docker compose logs backend frontend -f
