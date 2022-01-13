import asyncdispatch, asyncnet
import parsecfg
import strutils
import os

import  std/[terminal]


type
    Client = ref object
      socket: AsyncSocket
      netAddress: string
      id: int
      isConnected: bool

    Server = ref object
      socket: AsyncSocket
      clients: seq[Client]

proc newServer(): Server = Server(socket: newAsyncSocket(), clients: @[])

proc processIncomingMessages(server: Server, client: Client): Future[void] {.async.} =
  while true:
    let message: string = await client.socket.recvLine

    if message.len == 0:
      writeLine(stdout, "Client from address ", client.netAddress, ", disconnected")
      client.isConnected = false
      client.socket.close()
      return

    writeLine(stdout, client.netAddress, ": ", message)
    for connectedClient in server.clients:
      if connectedClient.id != client.id and client.isConnected:
        await connectedClient.socket.send(message & "\c\l")


proc activateServerAndListenForConnections(server: Server): Future[void] {.async.} =
    let configDetails = loadConfig(getCurrentDir() & "/config/client_server_app.cfg")
    let serversPort: string = configDetails.getSectionValue("Server", "port")
    let hostName: string = configDetails.getSectionValue("Server", "hostName")
    var port: int = parseInt(serversPort)
    server.socket.setSockOpt(OptReuseAddr, true)
    server.socket.bindAddr(port.Port, hostName)
    server.socket.listen()
    styledWriteLine(stdout, fgGreen, "[Server started. Listening for connections]")

    while true:
      let (address, clientSocket) = await server.socket.acceptAddr()
      write(stdout, "Successfully accepted connection from ")
      styledWriteLine(stdout, fgYellow, address)
      let client: Client = Client(
        socket: clientSocket,
        id: server.clients.len,
        netAddress: address,
        isConnected: true,
      )
      server.clients.add(client)
      asyncCheck processIncomingMessages(server, client)

let server: Server = newServer()

waitFor activateServerAndListenForConnections(server)
