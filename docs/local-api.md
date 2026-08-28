# API local

Disponible únicamente en Linux y Windows. Está desactivada por defecto y no
acepta conexiones remotas.

## Activación

1. Abre `Settings > Local API`.
2. Activa `Enable local API`.
3. Define, si quieres, puerto y límite de solicitudes por minuto.
4. Abre `Integration details` y copia la `secret key` y los `account IDs`.

La API escucha solo en `127.0.0.1`. El puerto predeterminado es `47865`. Si
está ocupado, prueba puertos alternativos automáticamente. Los puertos de
desarrollo conocidos se evitan durante esa selección automática. El puerto
configurado puede ser cualquier valor entre `1024` y `65535`.

La llave se almacena en las credenciales seguras del sistema operativo. No se
guarda en los ajustes de Hive ni se imprime en logs. Regenerarla invalida la
llave anterior.

## Autenticación

Todas las solicitudes requieren:

```http
Authorization: Bearer TU_SECRET_KEY
```

No envíes la llave en query strings. La API no habilita CORS y no expone
cookies, tokens, HTML, respuestas crudas ni errores internos.

## Endpoints

Base URL: `http://127.0.0.1:PUERTO`

```text
GET /v1/health
GET /v1/accounts
GET /v1/usage
GET /v1/accounts/{account_id}/usage
```

Ejemplo:

```bash
curl http://127.0.0.1:47865/v1/usage \
  -H "Authorization: Bearer TU_SECRET_KEY"
```

Los porcentajes provienen del último refresh de la app. La API no fuerza un
refresh ni envía mensajes a los proveedores. `status` puede ser `pending`,
`available`, `unavailable` o `session_expired`.

Respuesta resumida:

```json
{
  "data": [
    {
      "accountId": "uuid-generado-por-la-app",
      "label": "Personal",
      "provider": "claude",
      "status": "available",
      "fetchedAt": "2026-08-28T12:00:00.000Z",
      "fiveHour": {"usedPercent": 21, "resetAt": "2026-08-28T15:00:00.000Z"},
      "weekly": {"usedPercent": 42, "resetAt": null},
      "monthly": {"usedPercent": null, "resetAt": null}
    }
  ]
}
```

## Rate limit

El límite configurado se aplica globalmente a todas las solicitudes de la API
local. El rango es de `1` a `600` solicitudes por minuto. Al superarlo,
responde `429` con `Retry-After`.

## Compatibilidad con cuentas existentes

Cada cuenta recibe un `apiAccountId` nuevo. El identificador interno existente
no cambia: continúa siendo el perfil de WebView y el namespace de cookies.
Activar la API no borra cookies, no modifica sesiones y no provoca logout.

## Límites intencionales

La API es local y de solo lectura. No tiene acceso remoto, endpoint para enviar
mensajes, endpoint para iniciar cuotas ni endpoint para devolver sesiones. Un
refresh programado de la app puede actualizar los datos, pero consultar esta
API no inicia una ventana de cuota.
