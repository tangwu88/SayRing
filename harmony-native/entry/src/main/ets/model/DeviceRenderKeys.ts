import type { WearableDevice, WearableDial } from './WearableContracts';

// ArkUI ForEach retains a rendered child while its key is unchanged. SDK
// snapshots are immutable DTOs, not @Observed objects: include visible state.
export function dialRenderKey(dial: WearableDial, position: number): string {
  return JSON.stringify([dial.key, dial.selected, position]);
}
export function deviceRenderKey(device: WearableDevice): string {
  return JSON.stringify([device.key, device.name, device.provider, device.mac, device.rssi, device.connectable]);
}
