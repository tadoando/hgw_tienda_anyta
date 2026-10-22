# Tienda Online de Anyta

Página web estática (catálogo HGW con pedidos por WhatsApp) servida con nginx en Docker.

```
site/              la página: index.html + img/
nginx.conf         configuración de nginx (incluye /healthz)
Dockerfile         imagen nginx:1.27-alpine con la página adentro
docker-compose.yml servicio "web" (puerto atado a la IP del ProBook, autoheal)
                   y "tunel" (Cloudflare Tunnel, opcional)
.env.example       IP, puerto y si se activa el túnel
```

Esta web no guarda datos, así que no necesita carpeta en `/mnt/datos/`.

## Cambiar contenido

- Número de WhatsApp: en `site/index.html`, la línea `const WHATSAPP = "";` (con indicativo y sin `+`, p. ej. `573001234567`).
- Productos y precios: lista `PRODUCTS` en `site/index.html`. Kits: lista `KITS`.
- Fotos: en `site/img/`, y el campo `img` del producto.

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

## Publicar en internet (Cloudflare Tunnel)

El contenedor `tunel` (cloudflared) sale desde el ProBook hacia Cloudflare y Cloudflare manda las visitas de `https://tudominio` al contenedor `web` por la red interna de Docker. No se abren puertos en el router, la IP de la casa no queda expuesta y Cloudflare pone el HTTPS gratis.

En estos pasos `tiendaanyta.com` es un ejemplo: cámbialo por tu dominio.

### 1. Dominio en Cloudflare

- **Si aún no tienes dominio:** crea una cuenta gratis en https://dash.cloudflare.com, ve a *Domain Registration → Register Domains*, busca el nombre y cómpralo ahí (Cloudflare lo vende a precio de costo, un `.com` ronda los 10 USD al año). Queda en Cloudflare de una vez; salta al paso 2.
- **Si ya tienes dominio en otro lado** (GoDaddy, Hostinger, etc.): en Cloudflare, *Add a domain* → escribe el dominio → plan **Free**. Cloudflare te da dos *nameservers* (algo como `xxx.ns.cloudflare.com`). Entra al sitio donde compraste el dominio y cambia los nameservers por esos dos. Tarda de minutos a unas horas; Cloudflare te avisa por correo cuando el dominio queda **Active**.

### 2. Crear el túnel y copiar el token

1. En Cloudflare: *Zero Trust* (menú izquierdo; la primera vez pide elegir un nombre de equipo y el plan **Free**, puede pedir tarjeta pero no cobra).
2. *Networks → Tunnels → Create a tunnel* → tipo **Cloudflared** → nombre `hgw_tienda_anyta` → *Save tunnel*.
3. En *Install and run connector* elige **Docker**. Sale un comando que termina en `--token eyJh...`. Copia **solo** el texto largo que va después de `--token` (empieza por `eyJ`). No ejecutes ese comando: el contenedor ya está en el `docker-compose.yml`.
4. *Next* → pestaña *Public Hostname*:
   - Subdomain: vacío (o `www`)
   - Domain: `tiendaanyta.com`
   - Type: `HTTP`
   - URL: `web:80`

   *Save tunnel*. Si quieres que funcione con y sin `www`, en el túnel → *Public Hostname* → *Add a public hostname* y repite con Subdomain `www`.

### 3. Guardar el token en el ProBook

Por SSH en el ProBook. Pega el token donde dice `PEGA_AQUI_EL_TOKEN` (todo en una línea, sin espacios ni comillas):

```
sudo mkdir -p /etc/hgw_tienda_anyta
echo 'TUNNEL_TOKEN=PEGA_AQUI_EL_TOKEN' | sudo tee /etc/hgw_tienda_anyta/hgw_tienda_anyta.env > /dev/null
sudo chown root:tado /etc/hgw_tienda_anyta/hgw_tienda_anyta.env
sudo chmod 640 /etc/hgw_tienda_anyta/hgw_tienda_anyta.env
```

Revisa que quedó bien (debe mostrar `TUNNEL_TOKEN=eyJ...` y `-rw-r----- root tado`):

```
cat /etc/hgw_tienda_anyta/hgw_tienda_anyta.env
ls -l /etc/hgw_tienda_anyta/hgw_tienda_anyta.env
```

El token es como una contraseña: no lo pegues en el repo, en chats ni en capturas.

### 4. Activar el túnel

```
cd /opt/hgw_tienda_anyta
git pull --ff-only
echo 'COMPOSE_PROFILES=tunel' >> .env
docker compose up -d
docker compose ps
```

Los dos contenedores, `hgw_tienda_anyta` y `hgw_tienda_anyta_tunel`, deben salir `(healthy)` (el túnel tarda unos 20 segundos). En Cloudflare el túnel pasa a **HEALTHY**. Prueba desde el celular con los datos móviles (sin wifi): `https://tiendaanyta.com`.

Desde ahí `./actualizar.sh` levanta los dos contenedores solo, porque lee `COMPOSE_PROFILES` del `.env`.

### Si algo falla

```
docker logs --tail 50 hgw_tienda_anyta_tunel
```

- `Provided Tunnel token is not valid` o `TUNNEL_TOKEN` vacío: el token quedó mal copiado; repite el paso 3 y luego `docker compose up -d --force-recreate tunel`.
- La página dice *Bad gateway* / error 502: en Cloudflare revisa que la URL del *Public Hostname* sea `web:80` con tipo `HTTP`.
- El dominio no abre nada: el dominio aún no está **Active** en Cloudflare (paso 1).

Para apagar la publicación sin tocar la web local: `docker compose stop tunel`. Para quitarla del todo, borra la línea `COMPOSE_PROFILES=tunel` del `.env` y ejecuta `docker compose up -d --remove-orphans`.
