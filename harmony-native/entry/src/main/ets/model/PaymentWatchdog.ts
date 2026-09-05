export const PAYMENT_CLIENT_TIMEOUT_MS: number = 30000;
export const PAYMENT_TIMEOUT_MESSAGE: string = '支付客户端响应超时，已停止等待';

export function withPaymentTimeout<T>(operation: Promise<T>,
  milliseconds: number = PAYMENT_CLIENT_TIMEOUT_MS): Promise<T> {
  return new Promise<T>((resolve: (value: T) => void, reject: (reason?: Error) => void) => {
    const timer = setTimeout(() => reject(new Error(PAYMENT_TIMEOUT_MESSAGE)), milliseconds);
    operation.then((value: T) => {
      clearTimeout(timer);
      resolve(value);
    }).catch((error: Error) => {
      clearTimeout(timer);
      reject(error);
    });
  });
}

export function isPaymentTimeout(error: Error): boolean {
  return error.message === PAYMENT_TIMEOUT_MESSAGE;
}
