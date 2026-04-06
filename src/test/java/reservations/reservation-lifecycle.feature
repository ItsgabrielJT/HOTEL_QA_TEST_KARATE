Feature: Confirm reservations from payment outcomes

Background:
  * def validators = read('classpath:common/validators.js')
  * def workflows = read('classpath:common/workflows.js')
  * def data = read('reservation-data.json')
  * def System = Java.type('java.lang.System')
  * def runSalt = System.currentTimeMillis() % 365

@smoke @alto @happy-path @TC-HU6-01
Scenario: Confirm a reservation after a successful payment and remove the room from availability
  * def chain = workflows.obtainDesiredPayment('SUCCESS', { maxAttempts: data.maxAttempts, startOffset: 220, runSalt: runSalt })
  * match chain.holdState.status == 200
  * match chain.holdState.response.status == 'CONFIRMED'
  * match chain.holdState.response.reservation_id == '#string'
  * match chain.holdState.response.payment_id == chain.payment.response.id
  * def reservation = call read('classpath:common/api-helpers.feature@getReservationById') { reservationId: '#(chain.holdState.response.reservation_id)' }
  * match reservation.status == 200
  * match reservation.response contains { id: '#(chain.holdState.response.reservation_id)', room_id: '#(chain.room.id)', status: 'CONFIRMED' }
  * def available = call read('classpath:common/api-helpers.feature@listAvailableRooms') { checkin: '#(chain.checkin)', checkout: '#(chain.checkout)' }
  * match available.status == 200
  * assert !validators.containsRoom(available.response, chain.room.room_number, chain.room.hotel_id)

@alto @error-path @TC-HU6-02
Scenario: Do not confirm a reservation when the payment gateway returns DECLINED
  * def chain = workflows.obtainDesiredPayment('DECLINED', { maxAttempts: data.maxAttempts, startOffset: 220, runSalt: runSalt })
  * match chain.holdState.status == 200
  * match chain.holdState.response.status == 'PENDING'
  * match chain.holdState.response.reservation_id == null
  * match chain.holdState.response.payment_id == null

