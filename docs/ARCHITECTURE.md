# Arquitectura

```
┌──────────────────────┐   HTTPS + X-Session-Token   ┌────────────────────────────────────────────┐
│ App Flutter          │ ──────────────────────────▶ │ flamenco: /hobbystore/api/v1/*  (PHP 8.2)  │
│ (Android / iOS)      │                             │  código en ~/hobbystore/<env>/              │
│  otp_auth ───────────┼──┐                          │  PDO ─▶ Postgres 18, BD gyros,              │
└──────────────────────┘  │                          │         schema hobbystore(_staging)         │
                          │ HTTPS                    │  media ─▶ /webs/quanticasoft/hobbystore/    │
                          ▼                          └───────────────┬────────────────────────────┘
               ┌────────────────────────────┐   valida token         │
               │ flamenco: /otp/*.php       │ ◀──────────────────────┘ (caché en auth_cache 10 min)
               └──────────────┬─────────────┘
                              │ túnel SSH inverso (127.0.0.1:4100)
                              ▼
               ┌────────────────────────────┐   ADB/USB   ┌──────────────────────┐
               │ Raspberry Pi nas-meteo     │ ──────────▶ │ Android smsbridge    │ ─▶ SMS al usuario
               │ gateway OTP (Node, PM2)    │             │ (SIM Entel)          │
               └────────────────────────────┘             └──────────────────────┘
```

## Entornos

| Entorno | Rama | API | Código | BD | OTP |
|---|---|---|---|---|---|
| dev | `feature/*` | `http://localhost:8080/v1` | repo local (Docker) | Postgres Docker `:5433`, schema `hobbystore` | `mock` (123456) |
| staging | `develop` | `https://www.quanticasoft.com/hobbystore/api-staging/v1` | `~/hobbystore/staging` | `gyros.hobbystore_staging` | real |
| prod | tag en `main` | `https://www.quanticasoft.com/hobbystore/api/v1` | `~/hobbystore/prod` | `gyros.hobbystore` | real |

## API PHP
- Front controller en `public/index.php`. `.htaccess` reescribe todo a él, con PATH_INFO como alternativa: `index.php/v1/health`.
- En flamenco, `public/app_root.php` lo genera `deploy.sh` y apunta al código fuera del docroot. En dev no existe y se usa `dirname(__DIR__)`.
- La configuración está en `config.php` (valores por defecto) + `config.local.php` (por entorno, fuera de git).
