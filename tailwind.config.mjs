/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      colors: {
        void: '#0a0a0a',
        shadow: '#111111',
        obsidian: '#1a1a1a',
        ash: '#2a2a2a',
        crimson: {
          deep: '#8b0000',
          bright: '#cc0000',
          glow: '#ff1a1a',
        },
        iron: '#888888',
        bone: '#cccccc',
      },
      fontFamily: {
        heading: ['Cinzel', 'serif'],
        body: ['Inter', 'sans-serif'],
      },
      boxShadow: {
        'crimson': '0 0 20px rgba(204, 0, 0, 0.4)',
        'crimson-lg': '0 0 40px rgba(204, 0, 0, 0.5)',
        'crimson-sm': '0 0 10px rgba(204, 0, 0, 0.3)',
      },
      animation: {
        'pulse-crimson': 'pulseCrimson 3s ease-in-out infinite',
      },
      keyframes: {
        pulseCrimson: {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.6' },
        },
      },
    },
  },
  plugins: [],
};
