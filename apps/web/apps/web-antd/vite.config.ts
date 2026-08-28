import process from 'node:process';

import { defineConfig } from '@vben/vite-config';

import { loadEnv } from 'vite';

export default defineConfig(async (config) => {
  const env = loadEnv(config?.mode ?? 'development', process.cwd());
  const proxyTarget = env.VITE_BASE_URL || 'http://127.0.0.1:8080';

  return {
    application: {},
    vite: {
      server: {
        allowedHosts: true,
        proxy: {
          '/api': {
            changeOrigin: true,
            rewrite: (path) => path.replace(/^\/api/, ''),
            target: proxyTarget,
            ws: true,
          },
        },
      },
    },
  };
});
