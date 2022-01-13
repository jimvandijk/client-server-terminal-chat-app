import bcrypt
import random
import math
import os

import std/[sha1]

randomize()

var urandom: File
let randomNumberGenerator = urandom.open("/dev/urandom")

proc generateSalt*(): string =
    if randomNumberGenerator:
        var randomBytes: array[0..127, char]
        discard urandom.readBuffer(addr(randomBytes), 128)
        for ch in randomBytes:
            if ord(ch) in {32 .. 126}:
                result.add(ch)
    
    else:
        for i in 0 .. 127:
            result.add(chr(rand(94) + 32))


proc generatePassword*(password, salt: string, comparingTo = ""): string =
    let bcryptSalt = (if comparingTo != "": comparingTo else: genSalt(8))

    result = hash($secureHash(salt & $secureHash(password)), bcryptSalt)


