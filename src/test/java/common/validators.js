(function() {
  function findRoomByNumber(rooms, roomNumber, hotelId) {
    return rooms.find(function(room) {
      return room.room_number === roomNumber && (!hotelId || room.hotel_id === hotelId);
    }) || null;
  }

  function containsRoom(rooms, roomNumber, hotelId) {
    return findRoomByNumber(rooms, roomNumber, hotelId) !== null;
  }

  function firstRoom(rooms) {
    return rooms && rooms.length ? rooms[0] : null;
  }

  function expiresWithin(createdAt, expiresAt, ttlSeconds, toleranceSeconds) {
    var Instant = Java.type('java.time.Instant');
    var Duration = Java.type('java.time.Duration');
    var created = Instant.parse(createdAt);
    var expires = Instant.parse(expiresAt);
    var delta = Duration.between(created, expires).getSeconds();
    return Math.abs(delta - ttlSeconds) <= toleranceSeconds;
  }

  function arrayContains(value, expected) {
    return value && value.indexOf(expected) > -1;
  }

  function moneyToNumber(value) {
    return Number(value);
  }

  return {
    findRoomByNumber: findRoomByNumber,
    containsRoom: containsRoom,
    firstRoom: firstRoom,
    expiresWithin: expiresWithin,
    arrayContains: arrayContains,
    moneyToNumber: moneyToNumber
  };
})()
