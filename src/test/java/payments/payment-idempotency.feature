Feature: Preserve payment idempotency during checkout

Background:
  * def workflows = read('classpath:common/workflows.js')
  * def data = read('payment-data.json')
  * def System = Java.type('java.lang.System')
  * def runSalt = System.currentTimeMillis() % 365

@smoke @alto @happy-path @TC-HU5-01
Scenario: Replay a successful payment with the same idempotency key and get the cached transaction
  * def chain = workflows.obtainDesiredPayment('SUCCESS', { maxAttempts: data.maxAttempts, startOffset: 200, runSalt: runSalt })
  * match chain.payment.status == 200
  * def replay = call read('classpath:common/api-helpers.feature@payHold') { holdId: '#(chain.hold.response.id)', amount: #(Number(chain.room.price_per_night)), idempotencyKey: '#(chain.paymentRequest.idempotencyKey)' }
  * match replay.status == 200
  * match replay.response.id == chain.payment.response.id
  * match replay.response.status == 'SUCCESS'
  * match replay.response._cached == true

@ignore @alto @error-path @contract-gap @TC-HU5-02
Scenario: Preserve the original decline when the same payment is replayed
  * karate.abort()
