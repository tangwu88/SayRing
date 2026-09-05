let callbackExpected: boolean = false;

export function setPaymentCallbackExpected(value: boolean): void {
  callbackExpected = value;
}

export function isPaymentCallbackExpected(): boolean {
  return callbackExpected;
}
