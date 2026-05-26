export class AppError extends Error {
  constructor(
    public code: number,
    message: string,
    public status = 400,
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export const ErrorCodes = {
  INVALID_PARAM: 40001,
  NOT_FOUND: 40004,
  BUSINESS_VALIDATION: 40009,
  UNAUTHORIZED: 40101,
  RATE_LIMITED: 42901,
  INTERNAL: 50000,
  OCR_FAILED: 50021,
  AI_FAILED: 50031,
} as const;
