import json

type
    Message* = object
      sender*: string
      message*: string

proc decodeMessage*(message: string): Message =
    let messageData: JsonNode = parseJson(message)
    result.sender = messageData["sender"].getStr()
    result.message = messageData["message"].getStr()


proc encodeMessage*(message: Message): string =
    return $(%{"sender": %message.sender, "message": %message.message}) & "\c\l"


# when isMainModule:
#     block:
#         let someMessage: Message = Message(sender: "Katrina", message: "Hello")
#         let expectedOutput: string = """{"sender":"Katrina","message":"Hello"}""" & "\c\l"
#         doAssert(encodeMessage(someMessage) == expectedOutput)