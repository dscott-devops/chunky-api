const express = require('express');
const { notFound, errorHandler } = require('./middleware/errors');
const whoRouter  = require('./routes/who');
const fameRouter = require('./routes/fame');

const app = express();

app.use(express.json());

// CORS — allow internal network + localhost (nginx handles external restrictions)
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

app.use('/who', whoRouter);
app.use('/fame', fameRouter);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
