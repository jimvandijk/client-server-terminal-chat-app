from times as time import nil

proc getCurrentDateTimeAsMillisecondsSinceEpoch*(): int64 =
    return time.toUnix(time.toTime(time.now()))