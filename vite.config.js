import { defineConfig } from 'vite'

export default defineConfig({
  // Assets already live in Sinatra's public root. Never recursively copy
  // that root into its own child directory or delete tracked static assets.
  publicDir: false,
  build: {
    emptyOutDir: false,
    outDir: 'public/dist',
    rollupOptions: {
      input: {
        main: 'public/js/main.js'
      },
      output: {
        format: 'iife',
        entryFileNames: 'bundle.js',
        chunkFileNames: '[name].js',  
        assetFileNames: '[name].[ext]'
      }
    },
    minify: 'esbuild',
    target: 'es2015',
    sourcemap: false
  },
  server: {
    port: 5173
  }
})
