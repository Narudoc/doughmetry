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

/** 수분을 포함한 액체 재료 (우유, 계란 등). waterRatio는 소수 (0.88 = 88%) */
export interface Liquid {
  id: string;
  name: string;
  grams: number;
  waterRatio: number;
}

export type YeastType = 'fresh' | 'instant';

/** 이스트 — grams는 선택한 타입 기준의 실제 투입량. 0 = 사용 안 함 */
export interface Yeast {
  type: YeastType;
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
  schemaVersion: 2;
  name: string;
  note?: string;
  tags?: string[];
  createdAt: string; // ISO
  updatedAt: string;
  flours: Flour[]; // 본반죽 첨가 밀가루
  water: number; // 본반죽 물(g)
  bassinage: number; // 바시나주 물(g)
  salt: number; // g
  levain: Levain;
  liquids: Liquid[]; // 수분율이 반영되는 액체 재료
  yeast: Yeast;
  extras: Extra[]; // 수분 계산에서 제외되는 기타 재료
  targetDoughWeight?: number;
  pieces?: number;
}

/** % 표기 기준 — 계산은 항상 총 밀가루 기준이고, 재료 옆 % 표시만 전환한다 */
export type PctBasis = 'total' | 'added';

export interface Settings {
  /** 표시 자릿수: 0.1g 또는 1g */
  precision: 0.1 | 1;
  /** total: 총 밀가루 기준(프랑스식, 기본) / added: 첨가 밀가루 = 100% (베이커스 퍼센트) */
  pctBasis: PctBasis;
}
