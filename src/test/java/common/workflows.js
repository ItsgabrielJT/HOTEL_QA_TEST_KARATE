(function() {
  var LocalDate = Java.type('java.time.LocalDate');
  var Instant = Java.type('java.time.Instant');
  var Thread = Java.type('java.lang.Thread');
  var UUID = Java.type('java.util.UUID');

  function apiHelpersPath(options) {
    return options && options.apiHelpersPath ? options.apiHelpersPath : 'classpath:common/api-helpers.feature';
  }

  function callApi(tag, payload, options) {
    return karate.call(apiHelpersPath(options) + '@' + tag, payload);
  }

  function ensureStatus(result, expectedStatus, message) {
    if (!result || result.status !== expectedStatus) {
      karate.fail(message || ('Se esperaba status ' + expectedStatus));
    }
    return result;
  }

  function rangeFromOffsets(checkinOffset, checkoutOffset, runSalt) {
    return {
      checkin: LocalDate.now().plusDays(checkinOffset + runSalt).toString(),
      checkout: LocalDate.now().plusDays(checkoutOffset + runSalt).toString()
    };
  }

  function futureRange(offsetDays, nights, runSalt) {
    return rangeFromOffsets(offsetDays, offsetDays + nights, runSalt);
  }

  function availability(range, options) {
    return ensureStatus(
      callApi('listAvailableRooms', range, options),
      200,
      'No se pudo consultar disponibilidad para ' + range.checkin + ' / ' + range.checkout
    );
  }

  function findSharedRoom(primaryRooms, secondaryRooms) {
    for (var i = 0; i < primaryRooms.length; i++) {
      var room = primaryRooms[i];
      for (var j = 0; j < secondaryRooms.length; j++) {
        var candidate = secondaryRooms[j];
        if (candidate.room_number === room.room_number && candidate.hotel_id === room.hotel_id) {
          return room;
        }
      }
    }
    return null;
  }

  function sharedAvailability(firstRange, secondRange, failureMessage, options) {
    var first = availability(firstRange, options);
    var second = availability(secondRange, options);
    var room = findSharedRoom(first.response || [], second.response || []);
    if (!room) {
      karate.fail(failureMessage || 'No hay habitaciones compatibles entre los rangos indicados');
    }
    return { first: first, second: second, room: room };
  }

  function firstAvailableRoom(range, failureMessage, options) {
    var result = availability(range, options);
    var room = result.response && result.response.length ? result.response[0] : null;
    if (!room) {
      karate.fail(failureMessage || 'No hay habitaciones disponibles para el rango solicitado');
    }
    return { availability: result, room: room };
  }

  function createHoldForRoom(room, range, options) {
    return ensureStatus(
      callApi('createHold', { roomId: room.id, checkin: range.checkin, checkout: range.checkout }, options),
      201,
      'No se pudo bloquear la habitacion ' + room.room_number
    );
  }

  function blockAllAvailableRooms(range, options) {
    var before = availability(range, options);
    if (!before.response || !before.response.length) {
      return before;
    }

    karate.forEach(before.response, function(room) {
      createHoldForRoom(room, range, options);
    });

    return availability(range, options);
  }

  function waitForRoomToReturn(holdResponse, range, room, validators, options) {
    var extraWaitSeconds = options && options.extraWaitSeconds ? options.extraWaitSeconds : 20;
    var sleepMillis = options && options.sleepMillis ? options.sleepMillis : 5000;
    var deadline = Instant.parse(holdResponse.expires_at).plusSeconds(extraWaitSeconds);

    while (Instant.now().isBefore(deadline)) {
      var current = availability(range, options);
      if (validators.containsRoom(current.response, room.room_number, room.hotel_id)) {
        return current;
      }
      Thread.sleep(sleepMillis);
    }

    return availability(range, options);
  }

  function obtainDesiredPayment(desiredStatus, options) {
    var maxAttempts = options && options.maxAttempts ? options.maxAttempts : 8;
    var startOffset = options && options.startOffset ? options.startOffset : 200;
    var nights = options && options.nights ? options.nights : 1;
    var runSalt = options && options.runSalt ? options.runSalt : 0;

    for (var i = 0; i < maxAttempts; i++) {
      var range = futureRange(startOffset + i, nights, runSalt);
      var available = availability(range, options);
      if (!available.response || !available.response.length) {
        continue;
      }

      var room = available.response[0];
      var hold = callApi('createHold', { roomId: room.id, checkin: range.checkin, checkout: range.checkout }, options);
      if (hold.status !== 201) {
        continue;
      }

      var paymentRequest = {
        holdId: hold.response.id,
        amount: Number(room.price_per_night),
        idempotencyKey: UUID.randomUUID() + ''
      };
      var payment = callApi('payHold', paymentRequest, options);

      if (payment.response && payment.response.status === desiredStatus) {
        var holdState = callApi('getHold', { holdId: hold.response.id }, options);
        return {
          room: room,
          hold: hold,
          payment: payment,
          paymentRequest: paymentRequest,
          holdState: holdState,
          checkin: range.checkin,
          checkout: range.checkout
        };
      }
    }

    karate.fail('No se pudo obtener un pago con estado ' + desiredStatus + ' en ' + maxAttempts + ' intentos');
  }

  return {
    rangeFromOffsets: rangeFromOffsets,
    futureRange: futureRange,
    availability: availability,
    sharedAvailability: sharedAvailability,
    firstAvailableRoom: firstAvailableRoom,
    createHoldForRoom: createHoldForRoom,
    blockAllAvailableRooms: blockAllAvailableRooms,
    waitForRoomToReturn: waitForRoomToReturn,
    obtainDesiredPayment: obtainDesiredPayment
  };
})()