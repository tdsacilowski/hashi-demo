var express = require('express'),
    http = require('http'),
    redis = require('redis'),
    app = express(),
    client = redis.createClient('6379', 'redis.service.consul');

app.get('/', function(req, res, next) {
  client.incr('counter', function(err, counter) {
    if(err) return next(err);

    res.send('This page has been viewed ' + counter + ' times!');
  });
});

http.createServer(app).listen(process.env.NOMAD_PORT_http || 8080, function() {
  console.log('Listening on port ' + (process.env.NOMAD_PORT_http || 8080));
});
