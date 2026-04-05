Feature: Rooms availability API coverage for HU2

Background:
  * def validators = read('classpath:common/validators.js')
  * def data = read('availability-data.json')
  * def LocalDate = Java.type('java.time.LocalDate')
  * def System = Java.type('java.lang.System')
  * def runSalt = System.currentTimeMillis() % 365
  * def futureRange =
  """
  function(offsetDays, nights) {
    var checkin = LocalDate.now().plusDays(offsetDays + runSalt).toString();
    var checkout = LocalDate.now().plusDays(offsetDays + runSalt + nights).toString();
    return { checkin: checkin, checkout: checkout };
  }
  """
  * def baselineRange = futureRange(120, 2)
  * def ddtSearchRange = futureRange(130, 2)
  * def nonOverlapHoldRange = futureRange(140, 2)
  * def fullBlockRange = futureRange(150, 1)

@smoke @alto @happy-path @TC-HU2-01
Scenario: Return a seeded single room when no active block exists
  * def result = call read('classpath:common/api-helpers.feature@listAvailableRooms') baselineRange
  * match result.status == 200
  * match each result.response contains { id: '#string', room_number: '#string', hotel_id: '#string', type: '#string', price_per_night: '#string', capacity: '#number', amenities: '#[]', created_at: '#string', updated_at: '#string' }
  * def availableSingles = result.response.filter(function(room){ return room.type == data.knownAvailableRoom.type && room.capacity == data.knownAvailableRoom.capacity })
  * assert availableSingles.length > 0

@alto @happy-path @TC-HU2-02
Scenario: Keep a room visible when its hold does not overlap the search range
  * def before = call read('classpath:common/api-helpers.feature@listAvailableRooms') baselineRange
  * def nonOverlapBefore = call read('classpath:common/api-helpers.feature@listAvailableRooms') nonOverlapHoldRange
  * match before.status == 200
  * match nonOverlapBefore.status == 200
  * def sharedCandidate =
  """
  function() {
    for (var i = 0; i < before.response.length; i++) {
      var room = before.response[i];
      if (validators.containsRoom(nonOverlapBefore.response, room.room_number, room.hotel_id)) {
        return room;
      }
    }
    return null;
  }
  """
  * def candidate = sharedCandidate()
  * if (!candidate) karate.fail('No hay habitaciones que estén disponibles en ambos rangos para validar HU2-02')
  * def hold = call read('classpath:common/api-helpers.feature@createHold') { roomId: '#(candidate.id)', checkin: '#(nonOverlapHoldRange.checkin)', checkout: '#(nonOverlapHoldRange.checkout)' }
  * match hold.status == 201
  * def after = call read('classpath:common/api-helpers.feature@listAvailableRooms') baselineRange
  * match after.status == 200
  * assert validators.containsRoom(after.response, candidate.room_number, candidate.hotel_id)

@alto @error-path @edge-case @ddt @TC-HU2-03 @TC-HU2-05
Scenario Outline: Remove a room from availability when an active hold overlaps the requested dates
  * def before = call read('classpath:common/api-helpers.feature@listAvailableRooms') ddtSearchRange
  * match before.status == 200
  * def holdRange = overlapKind == 'exact' ? { checkin: ddtSearchRange.checkin, checkout: ddtSearchRange.checkout } : { checkin: LocalDate.now().plusDays(131 + runSalt).toString(), checkout: LocalDate.now().plusDays(134 + runSalt).toString() }
  * def holdRangeAvailability = call read('classpath:common/api-helpers.feature@listAvailableRooms') holdRange
  * match holdRangeAvailability.status == 200
  * def sharedCandidate =
  """
  function() {
    for (var i = 0; i < before.response.length; i++) {
      var room = before.response[i];
      if (validators.containsRoom(holdRangeAvailability.response, room.room_number, room.hotel_id)) {
        return room;
      }
    }
    return null;
  }
  """
  * def candidate = sharedCandidate()
  * if (!candidate) karate.fail('No hay habitaciones compatibles entre el rango buscado y el rango del hold para <tcId>')
  * def hold = call read('classpath:common/api-helpers.feature@createHold') { roomId: '#(candidate.id)', checkin: '#(holdRange.checkin)', checkout: '#(holdRange.checkout)' }
  * match hold.status == 201
  * def after = call read('classpath:common/api-helpers.feature@listAvailableRooms') ddtSearchRange
  * match after.status == 200
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
Scenario: Keep a room visible when only expired holds exist in the seed data
  * def result = call read('classpath:common/api-helpers.feature@listAvailableRooms') baselineRange
  * match result.status == 200
  * assert validators.containsRoom(result.response, data.expiredHoldAssumptionRoom.roomNumber, data.expiredHoldAssumptionRoom.hotelId)

@alto @edge-case @TC-HU2-07
Scenario: Return an empty list when every currently available room is blocked for the range
  * def before = call read('classpath:common/api-helpers.feature@listAvailableRooms') fullBlockRange
  * match before.status == 200
  * def blockAll =
  """
  function(room) {
    var hold = karate.call('classpath:common/api-helpers.feature@createHold', {
      roomId: room.id,
      checkin: fullBlockRange.checkin,
      checkout: fullBlockRange.checkout
    });
    if (hold.status !== 201) {
      karate.fail('No se pudo bloquear la habitación ' + room.room_number + ' para HU2-07');
    }
  }
  """
  * def ensureNoAvailability =
  """
  function() {
    if (!before.response.length) {
      return before;
    }
    karate.forEach(before.response, blockAll);
    return karate.call('classpath:common/api-helpers.feature@listAvailableRooms', fullBlockRange);
  }
  """
  * def after = ensureNoAvailability()
  * match after.status == 200
  * match after.response == []
