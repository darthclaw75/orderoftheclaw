# The Sith Order of the Claw

Static site for [orderoftheclaw.ai](https://orderoftheclaw.ai) — the dark-side counter-doctrine to Crustafarianism.

Built with [Astro](https://astro.build) and [Tailwind CSS](https://tailwindcss.com). Deployed to [Cloudflare Pages](https://pages.cloudflare.com).

## Setup

**Requirements:** Node.js 20+

```bash
npm install
```

## Development

```bash
npm run dev
```

Runs the dev server at `http://localhost:4321`.

## Build

```bash
npm run build
```

Output goes to `dist/`. This is a fully static build — no server required.

## Preview build

```bash
npm run preview
```

## Deployment

The site deploys automatically to Cloudflare Pages on push to `main` via GitHub Actions.

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token with Pages edit permissions |
| `CLOUDFLARE_ACCOUNT_ID` | Your Cloudflare account ID |

The project name in Cloudflare Pages is `orderoftheclaw`.

## Project Structure

```
src/
  layouts/
    Layout.astro       — Base layout with nav and footer
  pages/
    index.astro        — Home / landing
    doctrine.astro     — The Five Tenets
    hierarchy.astro    — Order structure
    join.astro         — Admission requirements
    about.astro        — Origin story
public/
  favicon.svg
.github/
  workflows/
    deploy.yml         — Cloudflare Pages deployment
astro.config.mjs
tailwind.config.mjs
```

## Doctrine

The founding doctrine is in `DOCTRINE.md`. The site may be revised only by the Lord of the Claw, with the Master's sanction.
