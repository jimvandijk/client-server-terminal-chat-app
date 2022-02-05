proc getchar*(): cint {.importc, header: "stdio.h"}
proc printf*(format: cstring): cint {.importc, varargs, header: "stdio.h"}
proc malloc*(size: cint): ptr {.importc, header: "stdlib.h"}
proc free*(`ptr`: ptr): cint {.importc, header: "stdlib.h"}
proc static_assert*(test: bool, errMsg: cstring): cint {.importc, header: "assert.h"}