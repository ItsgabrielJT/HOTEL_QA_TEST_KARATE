Feature: Payment API coverage for HU5

Background:
  * def data = read('payment-data.json')
  * def UUID = Java.type('java.util.UUID')
  * def LocalDate = Java.type('java.time.LocalDate')
  * def System = Java.type('java.lang.System')
  * def runSalt = System.currentTimeMillis() % 365
  * def obtainDesiredPayment =
  """
  function(desiredStatus) {
    for (var i = 0; i < data.maxAttempts; i++) {
      var checkin = LocalDate.now().plusDays(200 + runSalt + i).toString();
      var checkout = LocalDate.now().plusDays(201 + runSalt + i).toString();
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

@smoke @alto @happy-path @TC-HU5-01
Scenario: Replay a successful payment with the same idempotency key and get the cached transaction
  * def chain = obtainDesiredPayment('SUCCESS')
  * match chain.payment.status == 200
  * def replay = call read('classpath:common/api-helpers.feature@payHold') { holdId: '#(chain.hold.response.id)', amount: #(Number(chain.room.price_per_night)), idempotencyKey: '#(chain.payment.response.idempotency_key)' }
  * match replay.status == 200
  * match replay.response.id == chain.payment.response.id
  * match replay.response.status == 'SUCCESS'
  * match replay.response._cached == true

@alto @error-path @TC-HU5-02
Scenario: Replay a declined payment with the same idempotency key and preserve the original rejection
  * def chain = obtainDesiredPayment('DECLINED')
  * assert chain.payment.status == 402 || chain.payment.status == 200
  * def replay = call read('classpath:common/api-helpers.feature@payHold') { holdId: '#(chain.hold.response.id)', amount: #(Number(chain.room.price_per_night)), idempotencyKey: '#(chain.payment.response.idempotency_key)' }
  * match replay.response.id == chain.payment.response.id
  * match replay.response.status == 'DECLINED'
