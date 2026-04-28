#!/usr/bin/env bash
# Curl tests for all chunky-api routes.
# Usage: ./tests/routes.sh [base_url]
# Default base_url: http://127.0.0.1:3001

BASE="${1:-http://127.0.0.1:3001}"

PASS=0
FAIL=0
ERRORS=()

# ── Helpers ───────────────────────────────────────────────────────────────────

green="\033[0;32m"
red="\033[0;31m"
yellow="\033[0;33m"
reset="\033[0m"

pass() { echo -e "  ${green}✓${reset} $1"; ((PASS++)); }
fail() { echo -e "  ${red}✗${reset} $1"; ((FAIL++)); ERRORS+=("$1"); }

# Check HTTP status code
check_status() {
  local label="$1" url="$2" expected="${3:-200}"
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  if [[ "$status" == "$expected" ]]; then
    pass "$label → HTTP $status"
  else
    fail "$label → expected HTTP $expected, got $status ($url)"
  fi
}

# Check HTTP status AND that response body contains a string
check_contains() {
  local label="$1" url="$2" needle="$3" expected_status="${4:-200}"
  local status body
  body=$(curl -s -w "\n%{http_code}" "$url")
  status=$(tail -1 <<< "$body")
  body=$(head -n -1 <<< "$body")
  if [[ "$status" != "$expected_status" ]]; then
    fail "$label → expected HTTP $expected_status, got $status"
    return
  fi
  if echo "$body" | grep -q "$needle"; then
    pass "$label → contains '$needle'"
  else
    fail "$label → '$needle' not found in response"
  fi
}

# Check a JSON field equals an expected value using node
check_json() {
  local label="$1" url="$2" jspath="$3" expected="$4"
  local actual
  actual=$(curl -s "$url" | node -e "
    const chunks=[]; process.stdin.on('data',d=>chunks.push(d));
    process.stdin.on('end',()=>{
      try { const j=JSON.parse(chunks.join('')); console.log($jspath); }
      catch(e){ console.log('PARSE_ERROR'); }
    });
  " 2>/dev/null)
  if [[ "$actual" == "$expected" ]]; then
    pass "$label → $jspath = '$expected'"
  else
    fail "$label → expected '$expected', got '$actual'"
  fi
}

# ── Test suites ───────────────────────────────────────────────────────────────

echo -e "\n${yellow}── Health ─────────────────────────────────────────${reset}"
check_contains "GET /health"                "$BASE/health"              '"status":"ok"'
check_json     "GET /health uptime > 0"     "$BASE/health"              "j.uptime > 0 ? 'yes' : 'no'" "yes"

echo -e "\n${yellow}── 404 handling ───────────────────────────────────${reset}"
check_status   "GET /nonexistent → 404"     "$BASE/nonexistent"          404
check_status   "GET /who/people/no-such-person → 404" \
                                            "$BASE/who/people/no-such-person" 404
check_status   "GET /fame/people/no-such-person → 404" \
                                            "$BASE/fame/people/no-such-person" 404

echo -e "\n${yellow}── WHO — categories ───────────────────────────────${reset}"
check_status   "GET /who/categories"        "$BASE/who/categories"
check_contains "WHO categories has actor"   "$BASE/who/categories"      '"actor"'
check_contains "WHO categories has count"   "$BASE/who/categories"      '"count"'

echo -e "\n${yellow}── WHO — people list ──────────────────────────────${reset}"
check_status   "GET /who/people"            "$BASE/who/people"
check_contains "WHO people has meta"        "$BASE/who/people"          '"meta"'
check_contains "WHO people has data"        "$BASE/who/people"          '"data"'
check_json     "WHO people default per_page=20" \
                                            "$BASE/who/people"          "j.data.length"  "20"
check_json     "WHO people per_page=5"      "$BASE/who/people?per_page=5" \
                                            "j.data.length"             "5"
check_json     "WHO people page 2 offset"  "$BASE/who/people?per_page=5&page=2" \
                                            "j.meta.page.toString()"   "2"

echo -e "\n${yellow}── WHO — people search ────────────────────────────${reset}"
check_contains "WHO search ?q=Tom Hanks"    "$BASE/who/people?q=Tom%20Hanks" '"tom-hanks"'
check_contains "WHO search ?q=De Niro"      "$BASE/who/people?q=De%20Niro"   '"robert-de-niro"'
check_json     "WHO search no results"      "$BASE/who/people?q=xyzzy999zzz" \
                                            "j.meta.total.toString()"  "0"

echo -e "\n${yellow}── WHO — category filter ──────────────────────────${reset}"
check_contains "WHO ?category=actor"        "$BASE/who/people?category=actor"    '"actor"'
check_contains "WHO ?category=musician"     "$BASE/who/people?category=musician" '"musician"'

echo -e "\n${yellow}── WHO — person detail ────────────────────────────${reset}"
check_status   "GET /who/people/tom-hanks"  "$BASE/who/people/tom-hanks"
check_contains "WHO tom-hanks name"         "$BASE/who/people/tom-hanks"  '"Tom Hanks"'
check_contains "WHO tom-hanks has platforms" "$BASE/who/people/tom-hanks" '"platforms"'
check_contains "WHO tom-hanks has tmdb"     "$BASE/who/people/tom-hanks"  '"tmdb"'
check_contains "WHO tom-hanks has imdb"     "$BASE/who/people/tom-hanks"  '"imdb"'
check_contains "WHO tom-hanks has works"    "$BASE/who/people/tom-hanks"  '"popular_works"'
check_contains "WHO tom-hanks has gallery"  "$BASE/who/people/tom-hanks"  '"gallery"'
check_contains "WHO tom-hanks has categories" "$BASE/who/people/tom-hanks" '"categories"'
check_json     "WHO tom-hanks birth_year"   "$BASE/who/people/tom-hanks"  \
                                            "j.birth_year.toString()"   "1956"

check_status   "GET /who/people/aaron-eckhart" "$BASE/who/people/aaron-eckhart"
check_contains "WHO aaron-eckhart name"     "$BASE/who/people/aaron-eckhart" '"Aaron Eckhart"'

echo -e "\n${yellow}── WHO — gallery ──────────────────────────────────${reset}"
check_status   "GET /who/people/tom-hanks/gallery" \
                                            "$BASE/who/people/tom-hanks/gallery"
check_status   "GET /who/people/no-one/gallery → 200 empty" \
                                            "$BASE/who/people/no-one/gallery"  200

echo -e "\n${yellow}── WHO — platform lookup ──────────────────────────${reset}"
check_contains "WHO /platforms/tmdb/31"     "$BASE/who/platforms/tmdb/31"     '"tom-hanks"'
check_contains "WHO /platforms/imdb/nm0000158" \
                                            "$BASE/who/platforms/imdb/nm0000158" '"tom-hanks"'
check_status   "WHO /platforms/tmdb/9999999999 → 404" \
                                            "$BASE/who/platforms/tmdb/9999999999" 404

echo -e "\n${yellow}── FAME — categories ──────────────────────────────${reset}"
check_status   "GET /fame/categories"       "$BASE/fame/categories"
check_contains "FAME categories has musician" "$BASE/fame/categories"   '"musician"'
check_contains "FAME categories has actor"  "$BASE/fame/categories"     '"actor"'

echo -e "\n${yellow}── FAME — people list ─────────────────────────────${reset}"
check_status   "GET /fame/people"           "$BASE/fame/people"
check_json     "FAME people default per_page=20" \
                                            "$BASE/fame/people"         "j.data.length"  "20"
check_json     "FAME people per_page=3"     "$BASE/fame/people?per_page=3" \
                                            "j.data.length"             "3"
check_json     "FAME people page 3"         "$BASE/fame/people?per_page=3&page=3" \
                                            "j.meta.page.toString()"   "3"

echo -e "\n${yellow}── FAME — people search ───────────────────────────${reset}"
check_contains "FAME search ?q=Beyonce"     "$BASE/fame/people?q=Beyonce" '"beyonce"'
check_contains "FAME search ?q=Selena"      "$BASE/fame/people?q=Selena"  '"selena-gomez"'
check_contains "FAME search accent Beyoncé" "$BASE/fame/people?q=Beyonc%C3%A9" '"beyonce"'
check_json     "FAME search no results"     "$BASE/fame/people?q=xyzzy999zzz" \
                                            "j.meta.total.toString()"  "0"

echo -e "\n${yellow}── FAME — category filter ─────────────────────────${reset}"
check_contains "FAME ?category=musician"   "$BASE/fame/people?category=musician"  '"musician"'
check_contains "FAME ?category=actor"      "$BASE/fame/people?category=actor"     '"actor"'
check_contains "FAME ?category=influencer" "$BASE/fame/people?category=influencer" '"influencer"'

echo -e "\n${yellow}── FAME — person detail ───────────────────────────${reset}"
check_status   "GET /fame/people/beyonce"   "$BASE/fame/people/beyonce"
check_contains "FAME beyonce name"          "$BASE/fame/people/beyonce"  'Beyonc'
check_contains "FAME beyonce has platforms" "$BASE/fame/people/beyonce"  '"platforms"'
check_contains "FAME beyonce has spotify"   "$BASE/fame/people/beyonce"  '"spotify"'
check_contains "FAME beyonce has musicbrainz" "$BASE/fame/people/beyonce" '"musicbrainz"'
check_contains "FAME beyonce has works"     "$BASE/fame/people/beyonce"  '"popular_works"'

check_status   "GET /fame/people/barbra-streisand" "$BASE/fame/people/barbra-streisand"
check_contains "FAME barbra-streisand name" "$BASE/fame/people/barbra-streisand" '"Barbra Streisand"'

echo -e "\n${yellow}── FAME — gallery ─────────────────────────────────${reset}"
check_status   "GET /fame/people/beyonce/gallery" \
                                            "$BASE/fame/people/beyonce/gallery"
check_contains "FAME beyonce gallery has attribution" \
                                            "$BASE/fame/people/beyonce/gallery" '"attribution"'
check_contains "FAME beyonce gallery has cloudfront_url" \
                                            "$BASE/fame/people/beyonce/gallery" '"cloudfront_url"'

echo -e "\n${yellow}── FAME — platforms endpoint ──────────────────────${reset}"
check_status   "GET /fame/people/beyonce/platforms" \
                                            "$BASE/fame/people/beyonce/platforms"
check_contains "FAME beyonce /platforms has spotify" \
                                            "$BASE/fame/people/beyonce/platforms" '"spotify"'

echo -e "\n${yellow}── FAME — platform lookup ─────────────────────────${reset}"
check_contains "FAME /platforms/tmdb/14386" "$BASE/fame/platforms/tmdb/14386"  '"beyonce"'
check_contains "FAME /platforms/spotify/6vWDO969PvNqNYHIOW5v0m" \
                                            "$BASE/fame/platforms/spotify/6vWDO969PvNqNYHIOW5v0m" '"beyonce"'
check_status   "FAME /platforms/tmdb/9999999999 → 404" \
                                            "$BASE/fame/platforms/tmdb/9999999999" 404

# ── Summary ───────────────────────────────────────────────────────────────────

TOTAL=$((PASS + FAIL))
echo -e "\n${yellow}── Results ────────────────────────────────────────${reset}"
echo -e "  ${green}Passed: $PASS${reset} / $TOTAL"
if [[ $FAIL -gt 0 ]]; then
  echo -e "  ${red}Failed: $FAIL${reset}"
  echo -e "\n  ${red}Failures:${reset}"
  for err in "${ERRORS[@]}"; do
    echo -e "    ${red}✗${reset} $err"
  done
  exit 1
else
  echo -e "  ${green}All tests passed.${reset}"
fi
