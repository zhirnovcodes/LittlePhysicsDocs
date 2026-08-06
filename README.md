# My Physics Package Docs

Jekyll documentation site using the [Just the Docs](https://github.com/just-the-docs/just-the-docs) theme, built for a Unity Asset Store package and deployed with GitHub Pages via GitHub Actions.

Pinned theme version: **just-the-docs 0.12.0** (see `Gemfile`). Workflow versions follow the [official Just the Docs template](https://github.com/just-the-docs/just-the-docs-template).

## Prerequisites

- [Ruby](https://www.ruby-lang.org/) 3.1+ (3.3 recommended; matches CI)
- Bundler (`gem install bundler`)

### Windows

Install Ruby via [RubyInstaller](https://rubyinstaller.org/) (with MSYS2), then open a new terminal so `ruby` and `gem` are on your `PATH`.

## Local preview

```bash
bundle install
bundle exec jekyll serve
```

Open [http://127.0.0.1:4000/REPO-NAME/](http://127.0.0.1:4000/REPO-NAME/) — the path after the host must match `baseurl` in `_config.yml`.

To ignore `baseurl` while iterating locally:

```bash
bundle exec jekyll serve --baseurl ""
```

Then open [http://127.0.0.1:4000/](http://127.0.0.1:4000/).

## Deploy to GitHub Pages

1. Push this repo to GitHub (default branch: `main`).
2. In the repo: **Settings → Pages → Build and deployment → Source → GitHub Actions**.
3. Push to `main` (or run the **Deploy Jekyll site to Pages** workflow manually under **Actions**).
4. After the first successful deploy, the site URL appears under **Settings → Pages** and in the workflow summary.

### Why this workflow (not `actions/jekyll-build-pages`)

`actions/jekyll-build-pages` builds with the restricted **github-pages** gemset and cannot install gem-based **just-the-docs** from this `Gemfile`. This project uses the same pattern as the official Just the Docs template:

- `ruby/setup-ruby` + `bundle exec jekyll build`
- `actions/upload-pages-artifact`
- `actions/deploy-pages`

That is still the official GitHub Pages + Actions deploy path; it is not the legacy “Jekyll on Pages” branch builder. See `.github/workflows/pages.yml`.

## Placeholders to update

| What | Where |
|------|--------|
| Site title (`My Physics Package Docs`) | `_config.yml` → `title`; also homepage copy in `index.md` |
| `url` / `baseurl` | `_config.yml` — for `https://USERNAME.github.io/REPO-NAME/`, set `url: "https://USERNAME.github.io"` and `baseurl: "/REPO-NAME"` |
| Asset Store link | `_config.yml` → `aux_links` → `Asset Store`; also `docs/getting-started.md` |
| GitHub repo link | `_config.yml` → `aux_links` → `GitHub` |
| Unity version / install paths | `docs/getting-started.md` |

Search the repo for `PLACEHOLDER`, `USERNAME`, and `REPO-NAME` to catch remaining stubs.

## Tags

Add tags in page front matter:

```yaml
tags: [components, physics, rigidbody]
```

Just the Docs search indexes page content and front matter, so tagged terms are findable through the site search box. There is **no separate tag index page** in this project; ask if you want one added later.

## Useful paths

| Path | Purpose |
|------|---------|
| `_includes/youtube.html` | Responsive YouTube embed — `{% include youtube.html id="VIDEO_ID" %}` |
| `assets/images/` | Screenshots (see that folder’s README) |
| `docs/` | Documentation pages |
| `.github/workflows/pages.yml` | CI build + Pages deploy |
