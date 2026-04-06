Feature: Reservation lifecycle coverage for HU6 and HU7

Background:
  * def validators = read('classpath:common/validators.js')
  * def data = read('reservation-data.json')
  * def UUID = Java.type('java.util.UUID')
  * def LocalDate = Java.type('java.time.LocalDate')
  * def System = Java.type('java.lang.System')
  * def runSalt = System.currentTimeMillis() % 365
  * def obtainDesiredPayment =
  """
  function(desiredStatus) {
    for (var i = 0; i < data.maxAttempts; i++) {
      var checkin = LocalDate.now().plusDays(220 + runSalt + i).toString();
      var checkout = LocalDate.now().plusDays(221 + runSalt + i).toString();
      var available = karate.call('classpath:common/api-helpers.feature@listAvailableRooms', { checkin: checkin, checkout: checkout });
      if (!available.response || !available.response.length) {
        continue;
      }
      var room = available.response[0];
      var hold = karate.call('classpath:common/api-helpers.feature@createHold', { roomId: room.id, checkin: checkin, checkout: checkout });
      if (hold.status !== 201) {
        continue;
      }
      var payment = karate.call('classpath:common/api-helpers.feature@payHold', {
        holdId: hold.response.id,
        amount: Number(room.price_per_night),
        idempotencyKey: UUID.randomUUID() + ''
      });
      if (payment.response.status === desiredStatus) {
        var holdState = karate.call('classpath:common/api-helpers.feature@getHold', { holdId: hold.response.id });
        return { room: room, hold: hold, payment: payment, holdState: holdState, checkin: checkin, checkout: checkout };
      }
    }
    karate.fail('No se pudo obtener un pago con estado ' + desiredStatus + ' en ' + data.maxAttempts + ' intentos');
  }
  """

@smoke @alto @happy-path @TC-HU6-01
Scenario: Confirm a reservation after a successful payment and remove the room from availability
  * def chain = obtainDesiredPayment('SUCCESS')
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
  * def chain = obtainDesiredPayment('DECLINED')
  * match chain.holdState.status == 200
  * match chain.holdState.response.status == 'PENDING'
  * match chain.holdState.response.reservation_id == null
  * match chain.holdState.response.payment_id == null

@ignore @alto @edge-case @TC-HU7-03
Scenario: Ignore duplicate declined events for a hold that is already released
  * karate.abort()
