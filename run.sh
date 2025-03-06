#!/bin/bash
docker compose down && docker compose up --build -d && docker compose logs backend frontend -f
