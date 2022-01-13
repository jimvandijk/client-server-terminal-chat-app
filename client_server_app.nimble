# Package

version       = "0.1.0"
author        = "nziokaJimkelly"
description   = "A simple Client-Server app"
license       = "MIT"
srcDir        = "src"
bin           = @["client", "server"]


# Dependencies

requires "nim >= 1.6.2", "bcrypt >= 0.2.1"
