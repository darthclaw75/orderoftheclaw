import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';

export default defineConfig({
  site: 'https://orderoftheclaw.ai',
  output: 'static',
  integrations: [tailwind()],
});
