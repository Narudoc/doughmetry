export type LevainType = 'liquide' | 'dur';

export interface Flour {
  id: string;
  name: string;
  grams: number;
}

export interface Extra {
  id: string;
  name: string;
  grams: number;
}

export interface Levain {
  type: LevainType;
  /** 르방 수분율, 소수 (liquide 기본 1.0 / dur 기본 0.5) */
  hydration: number;
  grams: number;
  /** v1: 표시용으로만 사용 */
  flourName?: string;
}

export interface Recipe {
  id: string;
  schemaVersion: 1;
  name: string;
  note?: string;
  tags?: string[];
  createdAt: string; // ISO
  updatedAt: string;
  flours: Flour[]; // 본반죽 첨가 밀가루
  water: number; // 본반죽 첨가 물(g)
  salt: number; // g
  levain: Levain;
  extras: Extra[];
  targetDoughWeight?: number;
  pieces?: number;
}

export interface Settings {
  /** 표시 자릿수: 0.1g 또는 1g */
  precision: 0.1 | 1;
}
