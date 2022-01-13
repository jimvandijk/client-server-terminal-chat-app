from db_sqlite as sqlite import nil
import strutils
import sequtils
import sugar

import time_service
import ../utils/password_utilities

type
    User* = ref object
      id*:                     int
      name*:                   string
      country*:                string
      isConnected*:            bool
      emailAddress*:           string
      dateTimeAccountCreated*: int64


proc checkIfUserExists*(database: sqlite.DbConn, emailAddress: string): (int, bool)=
  let query: sqlite.SqlQuery = sqlite.sql"""SELECT * FROM clients WHERE emailAddress = ?"""
  let rows: sqlite.Row = sqlite.getRow(database, query, toLower(emailAddress))

  if len(rows) == 0 or rows.all((value) -> bool => len(value) == 0):
    return (-1, false)
  let id: int = parseInt(rows[0])
  return (id, true)

proc checkIfPasswordIsCorrectAndLoginClient*(database: sqlite.DbConn, password, emailAddress: string): (bool, string) =
  let query: sqlite.SqlQuery = sqlite.sql"""SELECT id, emailAddress, password, salt FROM clients WHERE emailAddress = ?"""
  for row in sqlite.fastRows(database, query, emailAddress.toLower()):
    let storedPassword: string = row[2]
    let hash: string = row[3]

    if storedPassword == generatePassword(password, hash, storedPassword):
      if not sqlite.tryExec(database, sqlite.sql"""UPDATE clients SET isConnected=1 WHERE emailAddress = ?""", toLower(emailAddress)):
        return (false, "error-failed-to-change-user-status-to-online")
      writeLine(stdout, "Login was successful")
      return (true, "")
    return (false, "error-password-incorrect")


proc prepareDatabase*(database: sqlite.DbConn): bool = 
  try:
    sqlite.exec(database, sqlite.sql"""CREATE TABLE IF NOT EXISTS clients(
        id                                 INTEGER PRIMARY KEY,
        name                               TEXT NOT NULL DEFAULT '',
        emailAddress                       TEXT NOT NULL DEFAULT '' COLLATE NOCASE,
        country                            TEXT NOT NULL DEFAULT '' COLLATE NOCASE,
        isConnected                        BOOL NOT NULL DEFAULT false,
        dateTimeAccountCreated             INTEGER NOT NULL DEFAULT -1,
        dateTimeAccountCreatedAsTimestamp  timestamp NOT NULL DEFAULT (STRFTIME('%s', 'now')),
        password                           TEXT NOT NULL DEFAULT '',
        salt                               VARBIN(128) NOT NULL,
        UNIQUE(emailAddress));
        """)
    return true
  except sqlite.DbError:
    writeLine(stderr, getCurrentExceptionMsg())
    return false

proc createUser*(database: sqlite.DbConn, name, emailAddress: string, country = "", password = ""): (int64, bool) =
    if not prepareDatabase(database):
            writeLine(stderr, "Something went wrong while attempting to create the clients table")
            return (-1.int64, false)
    let salt = generateSalt()
    let generatedPassword: string = generatePassword(password, salt)

    let id = sqlite.tryInsertID(database, sqlite.sql"""INSERT INTO clients
     (name, emailAddress, country, isConnected, dateTimeAccountCreated, password, salt) VALUES
     (?, ?, ?, ?, ?, ?, ?)""", name, emailAddress.toLower(), country, true, getCurrentDateTimeAsMillisecondsSinceEpoch(),
      generatedPassword, salt)
    if id == -1:
        writeLine(stderr, "Failed to add client to the Clients table")
        return (-1.int64 ,false)
    return (id, true)


proc checkIfEmailIsAlreadyInUse*(database: sqlite.DbConn, emailAddress: string): bool =
  let value = sqlite.getValue(database, sqlite.sql"SELECT emailAddress FROM clients WHERE emailAddress = ?", emailAddress)
  if len(value) == 0:
      return false
  return true

proc getUser*(database: sqlite.DbConn, id: int64): (User, bool) =
    let userData: sqlite.Row = sqlite.getRow(database, sqlite.sql"""SELECT 
      id, name, emailAddress, country, dateTimeAccountCreated, isConnected
      FROM clients 
      WHERE id = ?""", id)

    if len(userData) == 0 or all(userData, (value) -> bool => len(value) == 0):
      return (nil, false)

    let dateTimeAsString: string = userData[4]
    let parsedDateTime: int = parseInt(dateTimeAsString)
    let isConnected: bool = (if userData[5] == "1": true else: false)

    let id = parseInt(userData[0])
    let name = userData[1]
    let emailAddress = userData[2]
    let country = userData[3]
    let dateTimeAccountCreated = parsedDateTime

    (User(id: id, name: name, emailAddress: emailAddress, country: country, dateTimeAccountCreated: dateTimeAccountCreated, isConnected: isConnected), true)
    