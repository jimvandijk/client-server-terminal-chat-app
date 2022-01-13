proc getchar*(): cint {.importc, header: "stdio.h"}
proc printf*(format: cstring): cint {.importc, varargs, header: "stdio.h"}