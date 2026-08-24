import { defineConfig } from 'vite'

export default defineConfig({
  build: {
    outDir: 'public/dist',
    rollupOptions: {
      input: {
        main: 'public/js/main.js'
      },
      output: {
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
