# DumbListener

This module is a collection of "dumb" listeners that can be used for testing and troubleshooting. Just start up a listener and point your application or troubleshooting to the listener. Once a request is sent to the listener it will print information about the request to the console and if required by the given service a very basic response back to the client will be sent by the listener.

## Listeners

Currently this module supports the following listeners.

- DumbHTTPListener - An HTTP listener that by default just responds to all requests with 200 OK. Supports certificate based SSL connections.

- DumbUDPListener - A UDP listener that simply dumps the request information onto the console. It's UDP so no response to the client is necessary.