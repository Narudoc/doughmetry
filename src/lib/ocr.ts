/**
 * 사진 → 텍스트 (tesseract.js).
 * 라이브러리는 사용 시점에만 동적 import — 초기 번들에 포함되지 않는다.
 * 언어 데이터(kor+eng+fra, iOS Vision의 ko/en/fr와 동일)는 첫 사용 시 CDN에서 받아
 * 브라우저 캐시(IndexedDB)에 저장된다.
 */

/** 실패 원인 구분 — iOS ImportError(unreadableImage 등)와 대응 */
export class OcrError extends Error {
  constructor(
    public kind: 'module-load' | 'unreadable-image',
    message: string,
  ) {
    super(message);
    this.name = 'OcrError';
  }
}

/**
 * 'download' = 인식 엔진(worker·core) 받기 — importScripts라 바이트 진행률이 없다,
 * 'loading' = 언어 데이터 준비(첫 사용 시 내려받기), 'recognizing' = 글자 인식
 */
export type OcrPhase = 'download' | 'loading' | 'recognizing';

/** 첫 사용 때 CDN에서 받는 인식 엔진 + 언어 데이터(kor·eng·fra)의 대략적인 크기 */
export const OCR_FIRST_DOWNLOAD_MB = 9;

export async function recognizeImage(
  file: File,
  onProgress?: (progress: number, phase: OcrPhase) => void,
): Promise<string> {
  let worker;
  try {
    const { createWorker } = await import('tesseract.js');
    worker = await createWorker(['kor', 'eng', 'fra'], 1, {
      logger: (m: { status: string; progress: number }) => {
        if (m.status === 'recognizing text') onProgress?.(m.progress, 'recognizing');
        // 언어 데이터는 파일 단위로만 진행률을 알려 준다 (바이트 단위 아님)
        else if (m.status === 'loading language traineddata') onProgress?.(m.progress, 'loading');
        else if (m.status === 'loading tesseract core' || m.status === 'initializing tesseract') {
          onProgress?.(m.progress, 'download');
        }
      },
    });
  } catch (e) {
    throw new OcrError('module-load', e instanceof Error ? e.message : String(e));
  }
  try {
    const { data } = await worker.recognize(file);
    return data.text;
  } catch (e) {
    throw new OcrError('unreadable-image', e instanceof Error ? e.message : String(e));
  } finally {
    await worker.terminate();
  }
}
