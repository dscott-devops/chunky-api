const { Router } = require('express');
const { whoPool } = require('../db');
const { paginate } = require('../middleware/pagination');
const { listPeople, getPerson, getGallery, getCategories, getByPlatform } = require('../db/queries');

const router = Router();
const pool   = whoPool;
const isFame = false;

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

module.exports = router;
