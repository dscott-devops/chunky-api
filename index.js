const app = require('./src/app');

const PORT = process.env.PORT || 3001;

app.listen(PORT, '127.0.0.1', () => {
  console.log(`chunky-api listening on 127.0.0.1:${PORT}`);
});
