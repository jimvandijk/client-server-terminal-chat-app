import os
import asyncdispatch, asyncnet
import threadpool
import parsecfg
import strutils

import std/[re, db_sqlite, terminal]
import protocal, ../services/manage_clients

from std/rdstdin import nil


proc promptText(): void =
  writeLine(stdout, "What would you like to do?\n")
  writeLine(stdout, "1) Login")
  writeLine(stdout, "2) Create Account")
  writeLine(stdout, "3) Quit\n\n")


proc choiceTitle(choice: string) =
  case choice
  of "1":
    styledWriteLine(stdout, fgWhite, bgGreen, "-----")
    styledWriteLine(stdout, fgWhite, bgGreen, "LOGIN")
    styledWriteLine(stdout, fgWhite, bgGreen, "-----")
  of "2":
    styledWriteLine(stdout, fgWhite, bgBlue, "--------------")
    styledWriteLine(stdout, fgWhite, bgBlue, "CREATE ACCOUNT")
    styledWriteLine(stdout, fgWhite, bgBlue, "--------------")
  else:
    writeLine(stdout, "-------")
    writeLine(stdout, "QUIT")
    writeLine(stdout, "-------")


proc enquireWhatUserWantsToDo(): string = 
  promptText()
  var choice: string = rdstdin.readLineFromStdin("Choice: ")
  while choice != "1" and choice != "2" and choice != "3":
    writeLine(stdout, "\nPlease respond with either (1), (2) or (3)")
    writeLine(stdout, "------------------------------------------\n")
    promptText()
    choice = rdstdin.readLineFromStdin("Choice: ")
  
  return choice


proc attemptCreatingNewClient(database: DbConn): (User, bool, string) = 
  styledWriteLine(stdout, fgWhite, bgBlue, "Enter the following details to create your account")
  writeLine(stdout, "\n")

  let nameRegExp = re"\b([A-ZÀ-ÿ][-,a-z. ']+[ ]*)+"
  var name: string = rdstdin.readLineFromStdin("What's your name? ").strip
  while not match(name, nameRegExp):
    styledWriteLine(stderr, fgRed, "\nThe name you have provided is not valid")
    name = rdstdin.readLineFromStdin("Please re-enter your name: ")

  let emailRegExp = re"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$"
  var emailAddress: string = rdstdin.readLineFromStdin("What's your email address? ").strip
  while not match(emailAddress, emailRegExp):
    styledWriteLine(stderr, fgWhite, "\nPlease enter a valid email address. ", fgCyan, "Example [johndoe@domain.com]")
    emailAddress = rdstdin.readLineFromStdin("Email: ")

  var password: string = readPasswordFromStdin("What's your password? ")
  while len(password) == 0:
    styledWriteLine(stderr, fgRed, "\nPassword cannot be empty")
    password = readPasswordFromStdin("Please re-enter your password: ")

  var confirmPassword: string = readPasswordFromStdin("Confirm Password: ")
  while len(password) == 0:
    styledWriteLine(stderr, fgRed, "\nPassword cannot be empty")
    password = readPasswordFromStdin("Please re-enter your confirmation password: ")

  if confirmPassword != password:
    styledWriteLine(stdout, fgRed, "\nPasswords do not match")
    quit()

  let (_, userExists) = checkIfUserExists(database, emailAddress)
  if userExists:
    return (nil, false, "error-user-already-exists")
  let (clientsID, accountWasSuccessfullyCreated) = createUser(database, name, emailAddress, "", password)
  if not accountWasSuccessfullyCreated:
    return (nil, false, "Failed to create account")
  let (user, _)  = getUser(database, clientsID)
  if user == nil:
    return (nil, false, "error-fetching-user-details")

  styledWriteLine(stdout, fgWhite, bgBlue, "\nSuccessfully created your account")
  writeLine(stdout, "\n")
  return (user, true, "")
    

proc attemptLoggingClientIn(database: DbConn): (User, bool, string) = 
  writeLine(stdout, "Please enter your login details")
  writeLine(stdout, "-------------------------------\n\n")

  let emailRegExp = re"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$"
  var emailAddress: string = rdstdin.readLineFromStdin("What's your email address? ")
  while not match(emailAddress, emailRegExp):
    writeLine(stderr, "\nPlease enter a valid email address. Example [johndoe@domain.com]")
    writeLine(stderr, "----------------------------------------------------------------")
    emailAddress = rdstdin.readLineFromStdin("Email: ")

  var password: string = readPasswordFromStdin("What's your password? ")
  while len(password) == 0:
    writeLine(stdout, "\nPlease enter your password")
    writeLine(stdout, "--------------------------")
    password = readPasswordFromStdin("Password: ")
  
  let (id, userExists) = checkIfUserExists(database, emailAddress)
  if not userExists:
    return (nil, false, "error-user-does-not-exist")
  var (ok, message) = checkIfPasswordIsCorrectAndLoginClient(database, password, emailAddress)
  var numberOfAttempts: int = 5
  while message == "error-password-incorrect" and numberOfAttempts > 0:
    numberOfAttempts.dec
    styledWriteLine(stdout, fgRed, "Password was incorrect. Please re-enter password (", $numberOfAttempts, ") ", (if numberOfAttempts == 1: "attempt" else: "attempts"), " remaining")
    styledWriteLine(stdout, fgRed, "------------------------------------------------------------------------")
    password = readPasswordFromStdin("Password: ")
    (ok, message) = checkIfPasswordIsCorrectAndLoginClient(database, password, emailAddress)

  if not ok:
    return (nil, false, message)
  let (user, _)  = getUser(database, id)
  if user == nil:
    return (nil, false, "error-fetching-user-details")
  return (user, true, "")

proc initializeSqliteDatabase(): (DbConn, bool) =
  let pathToClientsDatabaseDir: string = getCurrentDir() & "/databases/sqlite/"
  if not dirExists(pathToClientsDatabaseDir):
    try:
      createDir(pathToClientsDatabaseDir)
    except OsError:
      writeLine(stderr, "Failed to create the file ", pathToClientsDatabaseDir)
      quit()

  try:
    let fileName: string = pathToClientsDatabaseDir & "/clients.db"
    if not fileExists(fileName):
      var file = open(fileName, FileMode.fmWrite)
      file.close()
    let database: DbConn = open(fileName, "", "", "")
    let databaseIsOkay = prepareDatabase(database)
    styledWriteLine(stdout, (if databaseIsOkay: fgGreen else: fgRed),  (if databaseIsOkay: "Database is okay" else : "Database is not okay"))
    if not databaseIsOkay:
      return (nil, false)
    return (database, true)
  except DbError:
    writeLine(stderr, getCurrentExceptionMsg())
    return (nil, false)


proc attemptConnectingToServer(socket: AsyncSocket, serverAddress: string, portNumber: int): Future[void] {.async.} =
  writeLine(stdout, "Initializing connection to ", serverAddress, "...")
  await socket.connect(serverAddress, portNumber.Port)
  styledWriteLine(stdout, fgWhite, "\nConnection to server was successful 🚀")
  writeLine(stdout, "\nType your message, then press [ENTER]\n")

  #Listen for any incoming messages relayed by the server from other connected clients
  while true:
    let message: string = await socket.recvLine
    let messageData = decodeMessage(message)
    writeLine(stdout, messageData.sender, ": ", messageData.message)



let configDetails = loadConfig(getCurrentDir() & "/config/client_server_app.cfg")

if paramCount() == 0:
  writeLine(stderr, "Please specify the URL of the server to connect to")
  echo "Example usage: .", paramStr(0), " localhost"
  quit(-1)

writeLine(stdout, "Starting client...")
let args: seq[string] = commandLineParams()
let serverAddress: string = args[0]

var socket: AsyncSocket = newAsyncSocket()
let serversPort: string = configDetails.getSectionValue("Server", "port")
var portNumber: int
try:
  portNumber = parseInt(serversPort)
except ValueError:
  writeLine(stderr, "Failed to get the port number to connect to")
  writeLine(stdout, "Please check your ", getCurrentDir() & "/config/client_server_app.cfg", " file")
  quit()

let (database, ok) = initializeSqliteDatabase()
if not ok:
  quit("Failed to establish connection to database")

let choice: string = enquireWhatUserWantsToDo()
choiceTitle(choice)
var loggedInUser: User

if choice == "1":
 let (user, loginWasSuccessful, errorMessage) = attemptLoggingClientIn(database)
 if not loginWasSuccessful:
   case errorMessage
   of  "error-user-does-not-exist":
     styledWriteLine(stdout, fgRed, "Couldn't find an account associated with the email address you've provided")
   of "error-fetching-user-details":
     styledWriteLine(stdout, fgRed, "Failed to fetch your details from the database")
   else:
     discard
   quit()
 loggedInUser = user
elif choice == "2":
  let (user, creationWasSuccessful, errorMessage) = attemptCreatingNewClient(database)
  if not creationWasSuccessful:
    quit(errorMessage)
  loggedInUser = user
else:
  quit("Program terminated")

asyncCheck attemptConnectingToServer(socket, serverAddress, portNumber)

var message: FlowVar[string] = spawn readLine(stdin)

while true:
  if (message.isReady):
    let messageToSend: Message = Message(sender: loggedInUser.name, message: ^message)
    let parsedMessage = encodeMessage(messageToSend)

    asyncCheck socket.send(parsedMessage)
    message = spawn readLine(stdin)

  asyncDispatch.poll()



