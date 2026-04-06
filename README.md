# Pruebas API con Karate - Travel Hotel: Motor de Reservas

**Proyecto:** Travel Hotel - Motor de Reservas  
**Version:** 1.0.0  
**Fecha:** 2026-04-05  
**Autor:** Joel Tates (QA)  
**HUs en Alcance:** HU2, HU3, HU5, HU6, HU7, HU11  
**Total de Casos:** 24 identificados (14 activos, 3 ignorados, 7 fuera de alcance)

## Contexto

Este repositorio contiene un harness externo de QA para validar el contrato observable de la API de Travel Hotel sin mezclar la suite dentro del backend objetivo.

La automatizacion esta construida con Gradle, Karate y JUnit 5, y se organiza por dominio de negocio para mantener trazabilidad directa entre historias de usuario, casos de prueba y artefactos de ejecucion.

## Objetivo

- Validar los flujos criticos del motor de reservas expuestos por la API.
- Ejecutar pruebas funcionales end-to-end sobre disponibilidad, holds, pagos, reservas y validacion de fechas.
- Permitir corrida local contra una API ya levantada y corrida CI contra un checkout remoto del sistema bajo prueba.
- Generar artefactos consumibles para diagnostico, trazabilidad y publicacion de reportes.
- Complementar la validacion funcional con una pasada automatizada de OWASP ZAP en CI.

## Alcance

Historias actualmente cubiertas por la suite:

- HU2: disponibilidad de habitaciones
- HU3: hold temporal para checkout
- HU5: idempotencia de pagos
- HU6: confirmacion de reserva
- HU7: liberacion por fallo de pago
- HU11: validacion de fechas

Cobertura activa en la suite por defecto:

- HU2: TC-HU2-01, TC-HU2-02, TC-HU2-03, TC-HU2-05, TC-HU2-07
- HU3: TC-HU3-01, TC-HU3-03
- HU5: TC-HU5-01
- HU6: TC-HU6-01, TC-HU6-02
- HU7: sin caso activo en la suite por defecto
- HU11: TC-HU11-01, TC-HU11-02, TC-HU11-03, TC-HU11-04

## Fuera del alcance

Estos casos no estan activos porque hoy no son verificables de forma confiable con el contrato expuesto o requieren capacidades que la API actual no publica.

| Caso | Estado | Motivo |
|---|---|---|
| TC-HU3-02 | No implementado | La concurrencia end-to-end no es estable con el contrato observable actual. |
| TC-HU5-04 | No implementado | El backend observado reutiliza el resultado cacheado y no rechaza la llave cross-hold como espera la matriz. |
| TC-HU7-02 | No implementado | Requiere reprocesar eventos tardios sobre una reserva ya confirmada con control explicito del flujo de eventos. |
| TC-HU8-01 | No implementado | La API no expone endpoint, hook o control de tiempo para disparar el worker de expiracion. |
| TC-HU8-02 | No implementado | La API no expone endpoint, hook o control de tiempo para disparar el worker de expiracion. |
| TC-HU8-03 | No implementado | La API no expone endpoint, hook o control de tiempo para disparar el worker de expiracion. |
| TC-HU8-04 | No implementado | La API no expone endpoint, hook o control de tiempo para disparar el worker de expiracion. |

## Casos de prueba generados y sus estados

Estado de cobertura del repositorio:

| TC-ID | HU | Estado | Implementacion | Observacion |
|---|---|---|---|---|
| TC-HU2-01 | HU2 | Activo | Implementado | Caso happy path de disponibilidad sembrada. |
| TC-HU2-02 | HU2 | Activo | Implementado | Valida que un hold no solapado no afecte disponibilidad. |
| TC-HU2-03 | HU2 | Activo | Implementado | Solapamiento exacto via DDT. |
| TC-HU2-04 | HU2 | Ignorado | Implementado con `@ignore` | Depende de una reserva confirmada seed consistente. |
| TC-HU2-05 | HU2 | Activo | Implementado | Solapamiento parcial via DDT. |
| TC-HU2-06 | HU2 | Ignorado | Implementado con `@ignore` | Requiere esperar expiracion del hold y hoy no se ejecuta en suite por defecto. |
| TC-HU2-07 | HU2 | Activo | Implementado | Bloqueo masivo de habitaciones disponibles para retorno vacio. |
| TC-HU3-01 | HU3 | Activo | Implementado | Crea hold pendiente y valida TTL de 10 minutos. |
| TC-HU3-02 | HU3 | No implementado | Sin feature dedicado | Caso fuera de alcance actual por estabilidad de concurrencia. |
| TC-HU3-03 | HU3 | Activo | Implementado | Rechazo de segundo hold para mismas fechas. |
| TC-HU5-01 | HU5 | Activo | Implementado | Reintento exitoso con misma idempotency key y respuesta cacheada. |
| TC-HU5-02 | HU5 | Ignorado | Implementado con `@ignore` | Se mantiene como gap de contrato observado. |
| TC-HU5-04 | HU5 | No implementado | Sin feature dedicado | El backend no rechaza hoy la llave cross-hold como exige la matriz. |
| TC-HU6-01 | HU6 | Activo | Implementado | Confirmacion de reserva tras pago exitoso. |
| TC-HU6-02 | HU6 | Activo | Implementado | No confirma reserva ante pago rechazado. |
| TC-HU7-02 | HU7 | No implementado | Sin feature dedicado | Requiere manejo de eventos tardios no observable por API. |
| TC-HU8-01 | HU8 | No implementado | Sin feature dedicado | Worker de expiracion no automatizable desde Karate hoy. |
| TC-HU8-02 | HU8 | No implementado | Sin feature dedicado | Worker de expiracion no automatizable desde Karate hoy. |
| TC-HU8-03 | HU8 | No implementado | Sin feature dedicado | Worker de expiracion no automatizable desde Karate hoy. |
| TC-HU8-04 | HU8 | No implementado | Sin feature dedicado | Worker de expiracion no automatizable desde Karate hoy. |
| TC-HU11-01 | HU11 | Activo | Implementado | Checkout anterior al checkin. |
| TC-HU11-02 | HU11 | Activo | Implementado | Checkout igual al checkin. |
| TC-HU11-03 | HU11 | Activo | Implementado | Checkin en el pasado. |
| TC-HU11-04 | HU11 | Activo | Implementado | Rango valido y continuidad al hold. |

Notas sobre estado observable:

- Los tags `@ignore` quedan excluidos por el runner global.
- Los artefactos presentes en `target` muestran corridas parciales y corridas historicas; por eso esta tabla documenta el estado del codigo fuente, no solo una unica corrida cacheada.
- En los artefactos actuales existe evidencia de una corrida parcial de disponibilidad con 6 escenarios pasados.

## CI

El workflow principal esta en `.github/workflows/karate-qa.yml` y cubre tres modos de disparo:

- Manual con `workflow_dispatch`.
- Programado cada 6 horas.
- Automatico en `push` y `pull_request` hacia `main` cuando cambian archivos relevantes de la suite.

El pipeline se divide en tres jobs:

1. `lint`
   - Ejecuta `bash -n` y `shellcheck` sobre `scripts/run_karate_qa.sh`.
2. `api-service-qa`
   - Configura Java 17, Gradle y Node.js 20.
   - Clona el repositorio objetivo y la rama objetivo.
   - Levanta Docker Compose desde el checkout remoto.
   - Arranca el backend bajo prueba.
   - Ejecuta Karate y OWASP ZAP.
   - Publica `qa-artifacts/latest` como artefacto de GitHub Actions.
   - Puede crear o actualizar un issue automatico cuando falla la suite.
   - Si una corrida posterior recupera el estado, comenta y cierra el issue automaticamente.
3. `publish-karate-report`
   - Corre fuera de `pull_request`.
   - Descarga artefactos y publica el sitio en GitHub Pages.
   - Si no existe el reporte esperado, publica una pagina de estado del run actual en lugar de dejar un reporte viejo.

La corrida manual acepta inputs, pero esos inputs solo funcionan como override de las variables configuradas en el repositorio.

## Variables del repositorio

Variables de GitHub Actions consumidas por CI:

- `DB_QA_TARGET_REPO_URL`
- `DB_QA_TARGET_REPO_BRANCH`
- `DB_QA_DB_PORT`
- `DB_QA_API_PORT`
- `DB_QA_FAILURE_ISSUES_ENABLED`

Para configurar esas variables automaticamente con GitHub CLI:

```bash
bash scripts/configure_github_repo.sh
```

## Ejecucion local

Hay dos formas de correr esta automatizacion localmente.

### Modo 1: suite Karate contra una API ya levantada

Prerrequisitos:

1. Java 17 disponible en la maquina.
2. Gradle disponible en PATH.
3. La API de Travel Hotel levantada localmente en `http://localhost:5173`.
4. Seeder de datos ya ejecutado en el backend.

Comandos utiles:

```bash
gradle testClasses
```

```bash
gradle test --tests availability.AvailabilityRunner
```

```bash
gradle test --tests holds.HoldsRunner
```

```bash
gradle test --tests payments.PaymentsRunner
```

```bash
gradle test --tests reservations.ReservationsRunner
```

```bash
gradle test --tests validation.ValidationRunner
```

```bash
gradle test --tests availability.AvailabilityRunner --tests holds.HoldsRunner --tests validation.ValidationRunner
```

```bash
gradle test -Dkarate.env=local
```

```bash
gradle test -Dauth.token=tu_token -Dauth.enforced=true
```

Variables relevantes en este modo:

- `karate.env`
- `base.url` o `baseUrl`
- `auth.token`
- `auth.enforced`
- `worker.enabled`
- `karate.timeout`

### Modo 2: harness completo contra un checkout remoto

Prerrequisitos adicionales:

1. Docker y Docker Compose disponibles.
2. Git disponible.
3. Node.js disponible para arrancar el backend objetivo.

Ejecucion:

```bash
bash scripts/run_karate_qa.sh
```

Variables soportadas por el script:

- `TARGET_REPO_URL`
- `TARGET_REPO_BRANCH`
- `QA_DB_PORT`
- `QA_API_PORT`
- `QA_ARTIFACTS_DIR`
- `TARGET_CLONE_DIR`
- `DB_USER`
- `DB_PASSWORD`
- `DB_NAME`
- `HOLD_DURATION_MINUTES`
- `PAYMENT_SIMULATOR_DECLINE_RATE`

Defaults relevantes del harness:

- `TARGET_REPO_URL=https://github.com/EGgames/HOTEL-MVP.git`
- `TARGET_REPO_BRANCH=dev`
- `QA_DB_PORT=5540`
- `QA_API_PORT=3100`

## Estructura del proyecto

- `build.gradle`: dependencias, task `test`, reportes y propagacion de propiedades Karate.
- `settings.gradle`: nombre del proyecto.
- `src/test/java/karate-config.js`: configuracion global de ambientes y timeouts.
- `src/test/java/TestRunner.java`: runner global que excluye `@ignore` y ejecuta en paralelo.
- `src/test/java/availability/`: cobertura HU2.
- `src/test/java/holds/`: cobertura HU3.
- `src/test/java/payments/`: cobertura HU5.
- `src/test/java/reservations/`: cobertura HU6 y comportamiento asociado a HU7.
- `src/test/java/validation/`: cobertura HU11.
- `src/test/java/common/api-helpers.feature`: llamadas reutilizables a endpoints.
- `src/test/java/common/workflows.js`: workflows compartidos para rangos, seleccion de habitaciones y cadenas de pago.
- `src/test/java/common/validators.js`: validadores reutilizables.
- `docs/API_REFERENCE.md`: referencia funcional de endpoints y payloads.
- `postman/`: coleccion y environment listos para pruebas manuales.
- `qa/zap/openapi.yaml`: insumo OpenAPI para el escaneo de ZAP.
- `scripts/run_karate_qa.sh`: orquestacion completa para CI y ejecucion externa.
- `scripts/configure_github_repo.sh`: configuracion automatica de variables de repositorio.

## Reportes

Reportes de la corrida Gradle/Karate:

- `target/karate-reports/karate-reports`: HTML, timeline, tags y JSON de Karate.
- `target/surefire-reports`: XML tipo JUnit.
- `target/gradle-test-report`: reporte HTML de Gradle.

Artefactos del harness completo:

- `qa-artifacts/latest/logs`: logs de clonacion, backend, Gradle y ZAP.
- `qa-artifacts/latest/reports/karate-report`: copia del reporte HTML de Karate.
- `qa-artifacts/latest/reports/gradle-report`: copia del reporte HTML de Gradle.
- `qa-artifacts/latest/reports/surefire-reports`: XML JUnit.
- `qa-artifacts/latest/reports/karate-pages`: contenido preparado para GitHub Pages.
- `qa-artifacts/latest/pipeline/execution-summary.json`: resumen estructurado de salida.

## Notas

- Se aplica DDT donde reduce repeticion, especialmente en HU2 y HU11.
- Se usan fechas dinamicas para evitar colisiones entre corridas, porque los holds expiran a los 10 minutos.
- La suite valida comportamiento real observado del backend, no una expectativa idealizada cuando ambos difieren.
- La referencia funcional de API y los archivos Postman se mantienen en el mismo repositorio para facilitar analisis manual y automatizado.
- Los casos ignorados no se borran: quedan documentados en codigo para reactivarlos cuando el backend exponga un contrato mas estable.

## Decisiones tecnicas

- El task `test` usa JUnit Platform y publica sus salidas en `target/karate-reports`, `target/surefire-reports` y `target/gradle-test-report`.
- `sourceSets.test.resources` toma `src/test/java` como fuente de recursos Karate y excluye `*.java`.
- `TestRunner` ejecuta todo lo no marcado con `@ignore` y corre con paralelismo de 5 hilos.
- `karate-config.js` soporta los ambientes `local`, `dev`, `ci`, `staging` y `prod`, y expone `baseUrl`, `authToken`, `authEnforced`, `workerEnabled`, `holdTtlSeconds` y `defaultHeaders`.
- El harness externo usa el `docker-compose` del checkout remoto en lugar de imponer uno propio, para validar el sistema objetivo mas cerca de su forma real de despliegue.
- CI combina validacion funcional y validacion de seguridad basica con OWASP ZAP en un mismo flujo.

## Conclusiones

Este repositorio ya funciona como una suite de QA externa orientada a contrato para el motor de reservas de Travel Hotel, con foco real en los flujos mas sensibles del checkout.

La cobertura activa prioriza disponibilidad, holds, pagos idempotentes, confirmacion de reserva y validacion temprana de fechas. Los gaps actuales no estan ocultos: quedan explicitados como casos ignorados o fuera de alcance hasta que el backend exponga senales mas estables para automatizarlos sin generar falsos positivos.
