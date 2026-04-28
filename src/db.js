const { Pool } = require('pg');

if (!process.env.CHUNKYWHO_URL || !process.env.CHUNKYFAME_URL) {
  console.error('Missing required env vars: CHUNKYWHO_URL, CHUNKYFAME_URL');
  process.exit(1);
}

const whoPool = new Pool({
  connectionString: process.env.CHUNKYWHO_URL,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

const famePool = new Pool({
  connectionString: process.env.CHUNKYFAME_URL,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

whoPool.on('error', (err) => console.error('chunkywho pool error', err));
famePool.on('error', (err) => console.error('chunkyfame pool error', err));

module.exports = { whoPool, famePool };
