import { configDefaults, defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

// GitHub Pages 배포: 저장소명이 'doughmetry'가 아니면 base를 함께 수정할 것 (README 참고)
export default defineConfig({
  base: '/doughmetry/',
  plugins: [react()],
  test: {
    environment: 'node',
    // .claude/worktrees의 다른 작업 트리(git에 안 보임)까지 돌지 않게
    exclude: [...configDefaults.exclude, '.claude/**'],
  },
});
