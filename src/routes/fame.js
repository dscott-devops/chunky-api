const { Router } = require('express');
const { famePool } = require('../db');
const { paginate } = require('../middleware/pagination');
const { listPeople, getPerson, getGallery, getCategories, getByPlatform } = require('../db/queries');

const router = Router();
const pool   = famePool;
const isFame = true;

router.get('/categories', async (req, res, next) => {
  try {
    res.json(await getCategories(pool, isFame));
  } catch (e) { next(e); }
});

router.get('/people', paginate, async (req, res, next) => {
  try {
    const { q, category } = req.query;
    const { page, perPage, offset } = req.pagination;
    res.json(await listPeople(pool, { q, category, page, perPage, offset, isFame }));
  } catch (e) { next(e); }
});

router.get('/people/:slug', async (req, res, next) => {
  try {
    const person = await getPerson(pool, req.params.slug, isFame);
    if (!person) return res.status(404).json({ error: 'Not found' });
    res.json(person);
  } catch (e) { next(e); }
});

router.get('/people/:slug/gallery', async (req, res, next) => {
  try {
    res.json(await getGallery(pool, req.params.slug));
  } catch (e) { next(e); }
});

router.get('/platforms/:platform/:id', async (req, res, next) => {
  try {
    const person = await getByPlatform(pool, req.params.platform, req.params.id);
    if (!person) return res.status(404).json({ error: 'Not found' });
    res.json(person);
  } catch (e) { next(e); }
});

// Fame-only: platform stats summary per person
router.get('/people/:slug/platforms', async (req, res, next) => {
  try {
    const r = await pool.query(
      `SELECT pi.platform, pi.platform_id, pi.platform_url, pi.verified
       FROM platform_identifiers pi
       JOIN people p ON p.id = pi.person_id
       WHERE p.slug = $1 ORDER BY pi.platform`,
      [req.params.slug]
    );
    res.json(r.rows);
  } catch (e) { next(e); }
});

module.exports = router;
