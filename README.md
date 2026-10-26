# Tienda Online de Anyta

Página web estática (catálogo HGW con pedidos por WhatsApp) servida con nginx en Docker.

```
site/              la página: index.html + img/
nginx.conf         configuración de nginx (incluye /healthz)
Dockerfile         imagen nginx:1.27-alpine con la página adentro
docker-compose.yml servicio "web", puerto atado a la IP del ProBook, autoheal
.env.example       IP y puerto de publicación
```

Esta web no guarda datos, así que no necesita carpeta en `/mnt/datos/`.

## Cambiar contenido

- Número de WhatsApp: en `site/index.html`, la línea `const WHATSAPP = "";` (con indicativo y sin `+`, p. ej. `573001234567`).
- Productos y precios: lista `PRODUCTS` en `site/index.html`. Kits: lista `KITS`.
- Fotos: en `site/img/`, y el campo `img` del producto. Si cambias o reemplazas fotos, sube el número de `IMG_V` en `site/index.html` (por ejemplo `?v=2` → `?v=3`) para que los navegadores descarguen las nuevas.

## Flujo de trabajo

- Desarrollo: carpeta compartida `Datos` → `Proyectos/HW_Anita/tienda-anyta` (en el ProBook: `/mnt/datos/compartido/Proyectos/HW_Anita/tienda-anyta`).
- Código: repo privado `tadoando/hgw_tienda_anyta` (rama `main`). Claude sube los cambios al repo.
- Producción: clon de solo lectura en `/opt/hgw_tienda_anyta`, que se actualiza con `git pull`.

## Despliegue en el ProBook (primera vez)

1. Confirmar que el repo `tadoando/hgw_tienda_anyta` ya tiene el código en `main`.

2. En el ProBook, crear la deploy key de solo lectura de este repo:

   ```
   ssh-keygen -t ed25519 -f ~/.ssh/hgw_tienda_anyta_deploy -N "" -C "probook hgw_tienda_anyta"
   cat ~/.ssh/hgw_tienda_anyta_deploy.pub
   ```

   Pegar la clave pública en GitHub → repo → Settings → Deploy keys (sin permiso de escritura). Agregar en `~/.ssh/config`:

   ```
   Host github-hgw_tienda_anyta
     HostName github.com
     User git
     IdentityFile ~/.ssh/hgw_tienda_anyta_deploy
     IdentitiesOnly yes
   ```

3. Clonar en `/opt`:

   ```
   sudo mkdir -p /opt/hgw_tienda_anyta && sudo chown tado:tado /opt/hgw_tienda_anyta
   git clone git@github-hgw_tienda_anyta:tadoando/hgw_tienda_anyta.git /opt/hgw_tienda_anyta
   cd /opt/hgw_tienda_anyta
   ```

4. Elegir un puerto libre. Cada web necesita su propio puerto; si dos contenedores piden el mismo, el segundo no arranca.

   ```
   ss -tlnp | grep -E ':80[0-9]{2}\b'
   docker ps --format '{{.Names}}  {{.Ports}}'
   ```

   Copiar `.env.example` a `.env` y poner en `WEB_PORT` uno que no aparezca (por defecto 8082):

   ```
   cp .env.example .env
   nano .env
   ```

5. Levantar:

   ```
   docker compose up -d --build
   docker ps --filter name=hgw_tienda_anyta   # debe decir (healthy)
   curl -I http://192.168.80.27:8082/
   ```

   La tienda queda en `http://192.168.80.27:<WEB_PORT>/` en la casa, y por Tailscale fuera de ella.

## Actualizar

Cuando el cambio ya está en `main`, en el ProBook:

```
/opt/hgw_tienda_anyta/actualizar.sh
```

El script hace `git pull`, `docker compose up -d --build` y muestra `docker compose ps`. Si no había cambios nuevos, lo dice y solo confirma que el contenedor esté arriba. Viene en el repo, así que ya está en el ProBook desde el primer clon.
