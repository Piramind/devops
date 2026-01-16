#!/bin/bash

# Найти все запущенные контейнеры, имя которых начинается с "name-"
containers=$(docker ps --filter "name=^/name-" --format "{{.ID}}")

if [ -z "$containers" ]; then
  echo "Контейнеры с префиксом name- не найдены."
else
  echo "Останавливаю контейнеры:"
  docker stop $containers
fi
