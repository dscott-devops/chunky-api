const app = require('./src/app');

const PORT = process.env.PORT || 3001;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`chunky-api listening on 0.0.0.0:${PORT}`);
});
