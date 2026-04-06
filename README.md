# Travel Hotel API Tests with Karate

Suite de pruebas API automatizadas con Karate sobre el motor de reservas de Travel Hotel.

El proyecto está construido con Gradle y organizado por dominio de negocio para mantener trazabilidad directa entre los casos de prueba.

## Alcance

Historias en alcance:

- HU2: disponibilidad
- HU3: hold de checkout
- HU5: idempotencia de pagos
- HU6: confirmación de reserva
- HU7: liberación por fallo de pago
- HU11: validación de fechas


## Fuera de alcance

Estos casos quedaron fuera de esta suite porque hoy no son verificables de forma confiable con el contrato observable o requieren capacidades no expuestas por la API actual.

| Caso | Estado | Motivo |
|---|---|---|
| TC-HU3-02 | No activo | La prueba de concurrencia no es estable de forma end-to-end con el contrato actual y puede depender de timing interno del backend. |
| TC-HU5-04 | No activo | El backend observado reutiliza el resultado cacheado y no rechaza la llave cross-hold como espera la matriz. |
| TC-HU7-02 | No activo | Requiere reprocesar eventos tardíos sobre una reserva ya confirmada con control explícito del flujo de eventos. |
| TC-HU8-01 a TC-HU8-04 | No activo | La API no expone endpoint, hook o control de tiempo para disparar y verificar el worker de expiración de forma automatizable desde Karate. |

## Estructura

- [build.gradle](build.gradle): configuración Gradle y dependencias Karate/JUnit 5
- [settings.gradle](settings.gradle): nombre del proyecto
- [src/test/java/karate-config.js](src/test/java/karate-config.js): configuración global de Karate
- [src/test/java/TestRunner.java](src/test/java/TestRunner.java): ejecuta todo lo no marcado con `@ignore`
- [src/test/java/common/api-helpers.feature](src/test/java/common/api-helpers.feature): helpers compartidos para endpoints
- [src/test/java/common/validators.js](src/test/java/common/validators.js): validadores reutilizables
- [src/test/java/availability/rooms-availability.feature](src/test/java/availability/rooms-availability.feature): HU2
- [src/test/java/holds/room-hold.feature](src/test/java/holds/room-hold.feature): HU3
- [src/test/java/payments/payment-idempotency.feature](src/test/java/payments/payment-idempotency.feature): HU5
- [src/test/java/reservations/reservation-lifecycle.feature](src/test/java/reservations/reservation-lifecycle.feature): HU6 y HU7
- [src/test/java/validation/date-validation.feature](src/test/java/validation/date-validation.feature): HU11

## Prerrequisitos

Para ejecutar la suite localmente necesitas:

1. Java 17 disponible en la máquina.
2. Gradle disponible en PATH.
3. La API de Travel Hotel levantada localmente en `http://localhost:5173`.
4. Seeder de datos ya ejecutado en el backend.

La suite asume el contrato observado en [api.md](api.md), no mocks.

## Documentacion de API

El repo incluye una referencia funcional de la API y archivos listos para Postman:

- [docs/API_REFERENCE.md](docs/API_REFERENCE.md): documentacion de endpoints, payloads, respuestas y flujo recomendado.
- [postman/Travel-Hotel-API.postman_collection.json](postman/Travel-Hotel-API.postman_collection.json): coleccion importable en Postman.
- [postman/Travel-Hotel-Local.postman_environment.json](postman/Travel-Hotel-Local.postman_environment.json): environment local con variables base.

Para probar la API manualmente en Postman:

1. Importa la coleccion y el environment.
2. Selecciona `Travel Hotel Local` como environment activo.
3. Ejecuta `List Available Rooms` para poblar `roomId` y `amount` automaticamente.
4. Ejecuta `Create Hold` para poblar `holdId`.
5. Ejecuta `Create Payment` y luego las consultas de reserva.

## Ejecución local

Ejecutar toda la suite activa:

```bash
gradle test
```

Ejecutar solo disponibilidad:

```bash
gradle test --tests availability.AvailabilityRunner
```

Ejecutar solo holds:

```bash
gradle test --tests holds.HoldsRunner
```

Ejecutar solo validación de fechas:

```bash
gradle test --tests validation.ValidationRunner
```

Ejecutar el paquete estable validado en local:

```bash
gradle test --tests availability.AvailabilityRunner --tests holds.HoldsRunner --tests validation.ValidationRunner
```

Ejecutar con ambiente Karate explícito:

```bash
gradle test -Dkarate.env=local
```

Si en el futuro el backend exige autenticación real, puedes inyectar token así:

```bash
gradle test -Dauth.token=tu_token -Dauth.enforced=true
```

## Reportes

Los reportes generados quedan en:

- [target/karate-reports](target/karate-reports): reporte HTML de Karate
- [target/surefire-reports](target/surefire-reports): XML tipo JUnit
- [target/gradle-test-report](target/gradle-test-report): reporte HTML de Gradle

## Casos automatizados

Casos activos en el suite por defecto, es decir, ejecutados por [src/test/java/TestRunner.java](src/test/java/TestRunner.java):

| HU | Casos automatizados |
|---|---|
| HU2 | TC-HU2-01, TC-HU2-02, TC-HU2-03, TC-HU2-05, TC-HU2-07 |
| HU3 | TC-HU3-01, TC-HU3-03 |
| HU5 | TC-HU5-01, TC-HU5-02 |
| HU6 | TC-HU6-01, TC-HU6-02 |
| HU7 | Sin casos activos en el suite por defecto |
| HU11 | TC-HU11-01, TC-HU11-02, TC-HU11-03, TC-HU11-04 |

Notas de implementación:

- Se aplicó DDT en negativos y edge cases donde sí reducía repetición, especialmente en HU2 y HU11.
- Se usan fechas dinámicas para evitar colisiones entre corridas porque los holds viven 10 minutos.
- La suite valida comportamiento real observado del backend, no el texto idealizado de la matriz cuando ambos difieren.

## Estado actual recomendado

Paquete estable y verificado localmente:

- HU2 parcial
- HU3 parcial
- HU11 completo

Cobertura implementada pero no validada completamente en esta pasada por depender de aleatoriedad o contratos incompletos:

- HU5 parcial
- HU6 parcial
- HU7 sin cobertura activa por divergencia de contrato

## Decisiones técnicas

- El runner global excluye todo lo marcado con `@ignore` desde [src/test/java/TestRunner.java](src/test/java/TestRunner.java#L9).
- Los helpers comunes abstraen llamadas a `rooms/available`, `rooms/{id}/hold`, `holds`, `payments` y `reservations` en [src/test/java/common/api-helpers.feature](src/test/java/common/api-helpers.feature).
- La configuración global usa `karate-config.js` y expone variables como `baseUrl`, `authToken`, `defaultHeaders`, `authEnforced` y `workerEnabled` en [src/test/java/karate-config.js](src/test/java/karate-config.js).

## Próximos pasos sugeridos

1. Definir un contrato determinista del simulador de pagos para cerrar HU5, HU6 y HU7 sin flakiness.