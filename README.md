# Quiz app built with Elm

This is a simple clone of [kahoot.it](https://kahoot.it/) built using Elm and websockets. It concists of 3 applications:

- The host app - Run this on your computer and share your screen to all players.
- The player app - Each player joins with their phone using this app.
- The server app - Run a node server that everyone connects to.

## Dependencies

- The [elm compiler](https://guide.elm-lang.org/install/elm.html)
- [node](https://nodejs.org) and [npm](https://www.npmjs.com)

## To build and run the app
```
npm install
make
node build/server.js
```
