import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

// GitHub Pages 배포: 저장소명이 'levain-calc'가 아니면 base를 함께 수정할 것 (README 참고)
export default defineConfig({
  base: '/levain-calc/',
  plugins: [react()],
  test: {
    environment: 'node',
  },
});
