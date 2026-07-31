import type { Config } from 'tailwindcss';

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        paper: '#F5F2EA',
        ink: '#22271F',
        bottle: {
          DEFAULT: '#1E4034',
          deep: '#142E25',
        },
        brass: '#9A6B32',
        line: '#D9D3C4',
        danger: '#9E3B2F',
      },
      fontFamily: {
        body: ['"Pretendard Variable"', 'Pretendard', '-apple-system', 'system-ui', 'sans-serif'],
        display: ['"Archivo Variable"', 'Archivo', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
} satisfies Config;
