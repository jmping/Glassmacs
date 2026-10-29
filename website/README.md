# Glassmacs website

Source for **glassmacs.joshpasek.com**. This is a static Astro site served by Cloudflare Workers static assets.

## Local development

Requires Node.js 20.19+ or 22.12+ (compatible with Astro 5).

```sh
cd website
npm install
npm run dev
npm run build
```

The output is `website/dist/`. No server runtime or secrets are required.

## Cloudflare deployment

1. In Cloudflare **Workers & Pages**, create a Worker by importing the GitHub repository `jmping/Glassmacs`.
2. Set the **root directory** to `website` and production branch to `main`.
3. Use build command `npm run build` and deploy command `npx wrangler deploy`. The checked-in `wrangler.jsonc` points to `./dist`.
4. After the first deployment, under **Settings → Domains & Routes**, add custom domain `glassmacs.joshpasek.com`. Cloudflare-managed DNS should provision the necessary record and TLS.
5. Configure build watch paths for `website/**` if supported. Keep application CI independent.

If the Cloudflare interface offers a Pages-specific workflow instead, use root `website`, build command `npm run build`, output directory `dist`, and configure the custom domain on that project; do **not** mix Pages and Workers deployment commands.

## Editorial policy

- Do not describe experimental features as verified on a signed or notarized macOS build.
- Do not invent screenshots, binaries, release dates, or download links.
- The Download button leads to GitHub Releases, where availability can be checked.
- Maintain a clear distinction between Aquamacs inspiration and any official affiliation.
- No third-party analytics or external font dependencies.
