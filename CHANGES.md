# CHANGES

This repository is a modified version of OWASP NodeGoat (Apache License 2.0).
Upstream base: https://github.com/OWASP/NodeGoat at commit
c5cb68a7084e4ae7dcc60e6a98768720a81841e8 (2023-06-21). Commits after that one
were made for the RexLearn course "DevSecOps Nền tảng" (RexCorp is fictional).

## Summary of modifications

- Renamed to `rexcorp-legacy` / "RexCorp Benefits" (package metadata, page titles, login page text).
- Removed the built-in tutorial (`/tutorial` route, views and its end-to-end tests): the course
  teaches with its own lessons and needs a no-hints mode.
- Removed `app.json` and `Procfile` (one-click Heroku deployment of a deliberately vulnerable app),
  `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md` (upstream project processes), and the OWASP logo.
- `docker-compose.yml`: the app port is published on 127.0.0.1 only.
- Replaced `README.md`; added `NOTICE` and this file.
- `config/env/all.js`: simulated incident history. A fake payroll API key was committed
  (2023-11-20) and later replaced by an environment variable (2024-03-05). The key is fake
  and is intentionally still present in git history.
- Unchanged on purpose (course material): application code and its vulnerabilities,
  dependencies, `Dockerfile`, `.travis.yml`, `.github/workflows/`.

## Files changed relative to upstream

Status codes: A added, M modified, D deleted.

```text
D	CODE_OF_CONDUCT.md
D	CONTRIBUTING.md
A	NOTICE
D	Procfile
M	README.md
D	app.json
D	app/assets/images/owasplogo.png
M	app/routes/index.js
D	app/routes/tutorial.js
M	app/views/layout.html
M	app/views/login.html
M	app/views/signup.html
D	app/views/tutorial/a1.html
D	app/views/tutorial/a10.html
D	app/views/tutorial/a2.html
D	app/views/tutorial/a3.html
D	app/views/tutorial/a4.html
D	app/views/tutorial/a5.html
D	app/views/tutorial/a6.html
D	app/views/tutorial/a7.html
D	app/views/tutorial/a8.html
D	app/views/tutorial/a9.html
D	app/views/tutorial/layout.html
D	app/views/tutorial/redos.html
D	app/views/tutorial/ssrf.html
M	config/env/all.js
M	docker-compose.yml
M	nodemon.json
M	package.json
M	test/e2e/integration/login_spec.js
D	test/e2e/integration/tutorial_spec.js
A	CHANGES.md
```
