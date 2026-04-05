Feature: Hold API coverage for HU3

Background:
  * def validators = read('classpath:common/validators.js')
  * def data = read('hold-data.json')
  * def ParallelHoldRequester = Java.type('common.ParallelHoldRequester')
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

@smoke @alto @happy-path @TC-HU3-01
Scenario: Create a hold with pending status and a ten minute expiration window
  * def createRange = futureRange(160, 2)
  * def hold = call read('classpath:common/api-helpers.feature@createHold') { roomId: '#(data.primaryRoom.id)', checkin: '#(createRange.checkin)', checkout: '#(createRange.checkout)' }
  * match hold.status == 201
  * match hold.response contains { room_id: '#(data.primaryRoom.id)', status: 'PENDING', payment_id: null, reservation_id: null }
  * assert validators.expiresWithin(hold.response.created_at, hold.response.expires_at, holdTtlSeconds, data.ttlToleranceSeconds)

@ignore @alto @concurrencia @TC-HU3-02
Scenario: Accept only one of two concurrent hold requests for the same room and range
  * def concurrentRange = futureRange(170, 2)
  * def responses = ParallelHoldRequester.createHolds(baseUrl, data.fallbackRoom.id, concurrentRange.checkin, concurrentRange.checkout, null)
  * def created = responses.filter(function(item){ return item.status === 201 })
  * def rejected = responses.filter(function(item){ return item.status === 409 || item.status === 400 })
  * match created.length == 1
  * match rejected.length == 1

@alto @error-path @TC-HU3-03
Scenario: Reject a second hold request when the room is already pending for the same dates
  * def duplicateRange = futureRange(180, 2)
  * def firstHold = call read('classpath:common/api-helpers.feature@createHold') { roomId: '#(data.primaryRoom.id)', checkin: '#(duplicateRange.checkin)', checkout: '#(duplicateRange.checkout)' }
  * match firstHold.status == 201
  * def secondHold = call read('classpath:common/api-helpers.feature@createHold') { roomId: '#(data.primaryRoom.id)', checkin: '#(duplicateRange.checkin)', checkout: '#(duplicateRange.checkout)' }
  * assert secondHold.status == 400 || secondHold.status == 409
  * match secondHold.response.message contains 'no disponible'

@ignore @seguridad @TC-HU3-04
Scenario: Reject unauthenticated hold creation when auth is enforced by the runtime
  * if (!authEnforced) karate.abort()
  * def authRange = futureRange(190, 2)
  * def hold = call read('classpath:common/api-helpers.feature@createHold') { roomId: '#(data.primaryRoom.id)', checkin: '#(authRange.checkin)', checkout: '#(authRange.checkout)', headers: {} }
  * match hold.status == 401
