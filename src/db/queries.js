// ── People list / search ──────────────────────────────────────────────────────

// chunkyfame has a single `category` column; chunkywho uses person_categories join table.
// Each route file passes the right WHERE clause fragment and join.

async function listPeople(pool, { q, category, page, perPage, offset, isFame }) {
  const params = [];
  const conditions = [];

  if (q) {
    params.push(q);
    conditions.push(`unaccent(p.full_name) ILIKE '%' || unaccent($${params.length}) || '%'`);
  }

  let categoryJoin = '';
  if (isFame) {
    if (category) {
      params.push(category);
      conditions.push(`p.category = $${params.length}`);
    }
  } else {
    categoryJoin = 'JOIN person_categories pc ON pc.person_id = p.id';
    if (category) {
      params.push(category);
      conditions.push(`pc.category = $${params.length}`);
    }
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

  const countResult = await pool.query(
    `SELECT COUNT(DISTINCT p.id) AS total
     FROM people p ${categoryJoin} ${where}`,
    params
  );
  const total = parseInt(countResult.rows[0].total);

  params.push(perPage, offset);
  const rows = await pool.query(
    `SELECT DISTINCT
       p.id, p.slug, p.full_name, p.display_name,
       ${isFame ? 'p.category' : 'MIN(pc.category) AS category'},
       p.subcategory, p.image_url, p.birth_year, p.death_year,
       p.country, p.has_official_site, p.data_quality
     FROM people p ${categoryJoin}
     ${where}
     GROUP BY p.id
     ORDER BY p.data_quality DESC, p.full_name
     LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params
  );

  return {
    data: rows.rows,
    meta: { total, page, per_page: perPage, pages: Math.ceil(total / perPage) },
  };
}


// ── Single person ─────────────────────────────────────────────────────────────

async function getPerson(pool, slug, isFame) {
  const personResult = await pool.query(
    `SELECT p.*,
       ${isFame ? 'p.category AS categories' : 'NULL AS categories'}
     FROM people p WHERE p.slug = $1`,
    [slug]
  );
  if (!personResult.rows.length) return null;
  const person = personResult.rows[0];

  // Categories (chunkywho only)
  if (!isFame) {
    const cats = await pool.query(
      'SELECT category FROM person_categories WHERE person_id = $1',
      [person.id]
    );
    person.categories = cats.rows.map(r => r.category);
  } else {
    person.categories = [person.category];
  }

  // Platform identifiers
  const pi = await pool.query(
    `SELECT platform, platform_id, platform_url, verified
     FROM platform_identifiers WHERE person_id = $1 ORDER BY platform`,
    [person.id]
  );
  person.platforms = pi.rows;

  // Social links
  const sl = await pool.query(
    'SELECT platform, url, handle FROM social_links WHERE person_id = $1',
    [person.id]
  );
  person.social_links = sl.rows;

  // Popular works
  const pw = await pool.query(
    `SELECT rank, work_type, title, url, thumbnail_url, published_at, source
     FROM popular_works WHERE person_id = $1 ORDER BY rank`,
    [person.id]
  );
  person.popular_works = pw.rows;

  // Gallery (first 6)
  const gal = await pool.query(
    `SELECT cloudfront_url, commons_file, attribution, license_short,
            license_url, width, height, description, date_taken,
            sort_order, is_primary
     FROM person_gallery WHERE person_id = $1 ORDER BY sort_order LIMIT 6`,
    [person.id]
  );
  person.gallery = gal.rows;

  return person;
}


// ── Gallery ───────────────────────────────────────────────────────────────────

async function getGallery(pool, slug) {
  const result = await pool.query(
    `SELECT pg.cloudfront_url, pg.commons_file, pg.attribution,
            pg.license, pg.license_short, pg.license_url,
            pg.width, pg.height, pg.description, pg.date_taken,
            pg.sort_order, pg.is_primary
     FROM person_gallery pg
     JOIN people p ON p.id = pg.person_id
     WHERE p.slug = $1
     ORDER BY pg.sort_order`,
    [slug]
  );
  return result.rows;
}


// ── Categories summary ────────────────────────────────────────────────────────

async function getCategories(pool, isFame) {
  if (isFame) {
    const result = await pool.query(
      `SELECT category, COUNT(*) AS count FROM people GROUP BY category ORDER BY count DESC`
    );
    return result.rows;
  }
  const result = await pool.query(
    `SELECT category, COUNT(*) AS count FROM person_categories GROUP BY category ORDER BY count DESC`
  );
  return result.rows;
}


// ── Platform search ───────────────────────────────────────────────────────────

async function getByPlatform(pool, platform, platformId) {
  const result = await pool.query(
    `SELECT p.id, p.slug, p.full_name, p.image_url
     FROM platform_identifiers pi
     JOIN people p ON p.id = pi.person_id
     WHERE pi.platform = $1 AND pi.platform_id = $2
     LIMIT 1`,
    [platform, platformId]
  );
  return result.rows[0] || null;
}


module.exports = { listPeople, getPerson, getGallery, getCategories, getByPlatform };
