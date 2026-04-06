Feature: Consult room availability for a stay

Background:
  * def validators = read('classpath:common/validators.js')
  * def workflows = read('classpath:common/workflows.js')
  * def data = read('availability-data.json')
  * def System = Java.type('java.lang.System')
  * def runSalt = System.currentTimeMillis() % 365
  * def baselineRange = workflows.futureRange(120, 2, runSalt)
  * def ddtSearchRange = workflows.futureRange(130, 2, runSalt)
  * def nonOverlapHoldRange = workflows.futureRange(140, 2, runSalt)
  * def fullBlockRange = workflows.futureRange(150, 1, runSalt)

@smoke @alto @happy-path @TC-HU2-01
Scenario: Return a seeded single room when no active block exists
  * def result = call read('classpath:common/api-helpers.feature@listAvailableRooms') baselineRange
  * match result.status == 200
  * match each result.response contains { id: '#string', room_number: '#string', hotel_id: '#string', type: '#string', price_per_night: '#string', capacity: '#number', amenities: '#[]', created_at: '#string', updated_at: '#string' }
  * def availableSingles = result.response.filter(function(room){ return room.type == data.knownAvailableRoom.type && room.capacity == data.knownAvailableRoom.capacity })
  * assert availableSingles.length > 0

@alto @happy-path @TC-HU2-02
Scenario: Keep a room visible when its hold does not overlap the search range
  * def sharedAvailability = workflows.sharedAvailability(baselineRange, nonOverlapHoldRange, 'No hay habitaciones que esten disponibles en ambos rangos para validar HU2-02')
  * def candidate = sharedAvailability.room
  * def hold = call read('classpath:common/api-helpers.feature@createHold') { roomId: '#(candidate.id)', checkin: '#(nonOverlapHoldRange.checkin)', checkout: '#(nonOverlapHoldRange.checkout)' }
  * match hold.status == 201
  * def after = workflows.availability(baselineRange)
  * assert validators.containsRoom(after.response, candidate.room_number, candidate.hotel_id)

@alto @error-path @edge-case @ddt @TC-HU2-03 @TC-HU2-05
Scenario Outline: Remove a room from availability when an active hold overlaps the requested dates
  * def holdRange = overlapKind == 'exact' ? ddtSearchRange : workflows.rangeFromOffsets(131, 134, runSalt)
  * def sharedAvailability = workflows.sharedAvailability(ddtSearchRange, holdRange, 'No hay habitaciones compatibles entre el rango buscado y el rango del hold para <tcId>')
  * def candidate = sharedAvailability.room
  * def hold = call read('classpath:common/api-helpers.feature@createHold') { roomId: '#(candidate.id)', checkin: '#(holdRange.checkin)', checkout: '#(holdRange.checkout)' }
  * match hold.status == 201
  * def after = workflows.availability(ddtSearchRange)
  * assert !validators.containsRoom(after.response, candidate.room_number, candidate.hotel_id)

Examples:
  | tcId         | overlapKind |
  | TC-HU2-03    | exact       |
  | TC-HU2-05    | partial     |

@ignore @alto @error-path @TC-HU2-04
Scenario: Hide a confirmed reservation from availability results
  * def result = call read('classpath:common/api-helpers.feature@listAvailableRooms') data.seedConfirmedRange
  * match result.status == 200
  * assert !validators.containsRoom(result.response, data.seedConfirmedReservation.roomNumber, data.seedConfirmedReservation.hotelId)

@ignore @alto @edge-case @TC-HU2-06
Scenario: Hide a room while a hold is active and show it again once the hold ends
  * def before = workflows.availability(baselineRange)
  * def candidate = validators.firstRoom(before.response)
  * if (!candidate) karate.fail('No hay habitaciones disponibles para validar HU2-06')
  * def hold = call read('classpath:common/api-helpers.feature@createHold') { roomId: '#(candidate.id)', checkin: '#(baselineRange.checkin)', checkout: '#(baselineRange.checkout)' }
  * match hold.status == 201
  * def whilePending = workflows.availability(baselineRange)
  * assert !validators.containsRoom(whilePending.response, candidate.room_number, candidate.hotel_id)
  * def afterHoldEnds = workflows.waitForRoomToReturn(hold.response, baselineRange, candidate, validators)
  * assert validators.containsRoom(afterHoldEnds.response, candidate.room_number, candidate.hotel_id)

@alto @edge-case @TC-HU2-07
Scenario: Return an empty list when every currently available room is blocked for the range
  * def after = workflows.blockAllAvailableRooms(fullBlockRange)
  * match after.response == []

@negativo @contract
Scenario: Reject availability searches when checkin is in the past
  * def pastRange = { checkin: '2026-04-03', checkout: '2026-04-04' }
  * def result = call read('classpath:common/api-helpers.feature@listAvailableRooms') pastRange
  * match result.status == 400
  * match result.response.error == 'Bad Request'
  * match result.response.statusCode == 400
  * match result.response.message[0] contains 'checkin debe ser hoy o posterior'
