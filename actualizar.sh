#!/usr/bin/env bash
# Actualiza la tienda en el ProBook: trae lo último de main y reconstruye el contenedor.
# Uso: ./actualizar.sh   (desde cualquier carpeta)
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

echo "== Trayendo cambios de GitHub"
antes=$(git rev-parse HEAD)
git pull --ff-only
despues=$(git rev-parse HEAD)

if [ "$antes" = "$despues" ]; then
  echo "== No había cambios nuevos. Igual reviso que el contenedor esté arriba."
else
  echo "== Cambios aplicados:"
  git log --oneline "$antes..$despues"
fi

echo "== Reconstruyendo y levantando"
docker compose up -d --build

echo "== Estado"
docker compose ps
