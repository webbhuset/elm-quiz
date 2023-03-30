
const Elm = require('./Server.elm.js');
const crypto = require("crypto");
const WebSocket = require("ws");
const express = require("express");
const path = require("path")
const app = express()

const elmApp = Elm.Build.Server.init({});

const serverPort = 8080;


app.get('/', function(req, res){
  res.sendFile(path.join(__dirname, 'host.html'));
});

app.get('/join/:id', function(req, res){
  res.sendFile(path.join(__dirname, 'player.html'));
});

app.use("/build", express.static(path.resolve(__dirname)));

const webServer = app.listen(serverPort);
const playerServer = new WebSocket.Server({ noServer: true });
const hostServer = new WebSocket.Server({ noServer: true });
console.log('Server listening on http://127.0.0.1:' + serverPort);

var players = {};

for (let name in elmApp.ports) {
    let port = elmApp.ports[name];

    if (name.match(/^send_/)) {
        let targetName = name.replace(/send_/, '');

        if (targetName.match(/^Player/)) {
            port.subscribe(sendToPlayer(targetName));
        } else {
            port.subscribe(sendToHost(targetName));
        }
    }
}

function sendToPlayer(targetName) {
    return function(data) {
        let payload = {
            tag: targetName,
            msg: data.msg
        };

        let toPlayer = players[data.id];

        if (toPlayer && toPlayer.readyState === WebSocket.OPEN) {
            toPlayer.send(JSON.stringify(payload));
        }
    }
}

function sendToHost(targetName) {
    return function(data) {
        let payload = JSON.stringify({
            tag: targetName,
            msg: data,
        });

        for (let toHost of hostServer.clients) {
            if (toHost.readyState === WebSocket.OPEN) {
                toHost.send(payload);
            }
        }
    }
}

playerServer.on("connection", function(connection, request) {
    console.log('player', connection.id, 'open');

    connection.on("error", function(data) {
        console.log('player', connection.id, 'error');
        elmApp.ports.server_PlayerLeft.send(connection.id);
        delete players[connection.id];
    });
    connection.on("close", function(data) {
        delete players[connection.id];
        elmApp.ports.server_PlayerLeft.send(connection.id);
        console.log('player', connection.id, 'close');
    });
    connection.on("message", function(data) {
        let payload = JSON.parse(data.toString());
        let portName = payload.tag;
        let port = elmApp.ports['recv_' + portName];

        port.send({
            id: connection.id,
            msg: payload.msg,
        });
    })
})


hostServer.on("connection", function(connection, request) {
    console.log('host', 'open');
    connection.on("error", function(data) {
        console.log('host', 'error', data);
    });
    connection.on("close", function(data) {
        console.log('host', 'close');
        for (let player of playerServer.clients) {
            player.close();
        }
    });
    connection.on("message", function(data) {
        let payload = JSON.parse(data.toString());
        let portName = payload.tag;
        let port = elmApp.ports['recv_' + portName];

        port.send(payload.msg);
    })
})


webServer.on('upgrade', async function upgrade(request, socket, head) {
    let parts = request.url.split('/');
    switch (parts[1]) {
        case 'join':
            const gameId = parts[2];
            const id = crypto.randomBytes(8).toString('hex');
            playerServer.handleUpgrade(request, socket, head, function done(connection) {
                players[id] = connection;
                connection.id = id;
                playerServer.emit('connection', connection, request);
            });
            break;

        case 'host':
            hostServer.handleUpgrade(request, socket, head, function done(connection) {
                hostServer.emit('connection', connection, request);
            });
            break;
    }
});

