# Termi website

A minimal dark Vite site. Inter is bundled locally. No runtime frameworks or analytics.

```sh
npm ci
npm run dev
npm run build
```

The output is `dist/`. To deploy on Vercel, import the GitHub repository with the Root Directory set to the repository root (`.`). The root `vercel.json` supplies the install command, build command, and `website/dist` output path. No environment variables are required.

The download button points directly to the latest GitHub Release's `Termi-mac-arm64.dmg` asset. The installer is never stored in this website or uploaded to Vercel. See the root README for packaging and release instructions.
