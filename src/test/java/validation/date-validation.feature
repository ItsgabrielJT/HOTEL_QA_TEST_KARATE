Feature: Validate stay dates before checkout

Background:
  * def data = read('date-validation-data.json')
  * def workflows = read('classpath:common/workflows.js')
  * def System = Java.type('java.lang.System')
  * def runSalt = System.currentTimeMillis() % 365
  * def validRange = workflows.futureRange(250, 5, runSalt)

@smoke @medio @error-path @ddt @TC-HU11-01 @TC-HU11-02 @TC-HU11-03
Scenario Outline: Reject invalid date combinations before creating a hold
  * def hold = call read('classpath:common/api-helpers.feature@createHold') { roomId: '#(data.roomId)', checkin: '<checkin>', checkout: '<checkout>' }
  * match hold.status == 400
  * match hold.response.statusCode == 400
  * match hold.response.error == 'Bad Request'
  * match hold.response.message[0] contains '<expectedFragment>'

Examples:
  | tcId         | checkin      | checkout     | expectedFragment             |
  | TC-HU11-01   | 2026-10-20   | 2026-10-18   | posterior a checkin          |
  | TC-HU11-02   | 2026-10-20   | 2026-10-20   | posterior a checkin          |
  | TC-HU11-03   | 2025-01-01   | 2025-01-03   | checkin debe ser hoy o posterior |

@medio @happy-path @TC-HU11-04
Scenario: Accept a valid date range and continue with hold creation
  * def roomSelection = workflows.firstAvailableRoom(validRange, 'No hay habitaciones disponibles para validar HU11-04')
  * def candidate = roomSelection.room
  * def hold = call read('classpath:common/api-helpers.feature@createHold') { roomId: '#(candidate.id)', checkin: '#(validRange.checkin)', checkout: '#(validRange.checkout)' }
  * match hold.status == 201
  * match hold.response.status == 'PENDING'
