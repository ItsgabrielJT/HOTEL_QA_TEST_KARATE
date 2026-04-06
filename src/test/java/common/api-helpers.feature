Feature: Shared API helpers

Background:
  * url baseUrl
  * def authContext = callonce read('classpath:auth/login.feature')
  * def baseHeaders = karate.merge(defaultHeaders, authContext.headers)
  * configure headers = baseHeaders

@listAvailableRooms
Scenario: List available rooms for a date range
  * def payload = __arg
  Given path 'rooms', 'available'
  And param checkin = payload.checkin
  And param checkout = payload.checkout
  When method get
  * def status = responseStatus

@createHold
Scenario: Create a room hold
  * def payload = __arg
  * def requestHeaders = payload.headers ? karate.merge(baseHeaders, payload.headers) : baseHeaders
  * configure headers = requestHeaders
  Given path 'rooms', payload.roomId, 'hold'
  And request { checkin: '#(payload.checkin)', checkout: '#(payload.checkout)' }
  When method post
  * def status = responseStatus

@getHold
Scenario: Get hold details
  * def payload = __arg
  Given path 'holds', payload.holdId
  When method get
  * def status = responseStatus

@payHold
Scenario: Pay an existing hold
  * def payload = __arg
  Given path 'payments'
  And request { hold_id: '#(payload.holdId)', amount: #(payload.amount), idempotency_key: '#(payload.idempotencyKey)' }
  When method post
  * def status = responseStatus

@getReservationById
Scenario: Retrieve reservation by identifier
  * def payload = __arg
  Given path 'reservations', payload.reservationId
  When method get
  * def status = responseStatus

@findReservationByCode
Scenario: Retrieve reservation by reservation code
  * def payload = __arg
  Given path 'reservations'
  And param reservation_code = payload.reservationCode
  When method get
  * def status = responseStatus
