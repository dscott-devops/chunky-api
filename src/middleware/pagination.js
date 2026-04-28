function paginate(req, _res, next) {
  const page    = Math.max(1, parseInt(req.query.page)     || 1);
  const perPage = Math.min(100, Math.max(1, parseInt(req.query.per_page) || 20));
  req.pagination = { page, perPage, offset: (page - 1) * perPage };
  next();
}

module.exports = { paginate };
