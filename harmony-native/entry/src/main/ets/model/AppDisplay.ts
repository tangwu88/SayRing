import { ApiError } from './Contracts';

export interface AppDisplayCache {
  read(): Promise<boolean | undefined>;
  write(hideAi: boolean): Promise<void>;
}

export interface AiDisplayAccess {
  readonly hideAi: boolean;
  readonly generation: number;
  requireVisible(generation?: number): void;
}

export function parseSayRingAppDisplay(data: Object | undefined): boolean {
  const value = data as Record<string, Object>;
  if (!value || value['product'] !== 'say-ring' || typeof value['hideAi'] !== 'boolean') {
    throw new ApiError('serviceUnavailable', 503);
  }
  return value['hideAi'] as boolean;
}

export class AppDisplayState implements AiDisplayAccess {
  private hidden: boolean = true;
  private revision: number = 0;
  private cacheLoaded: boolean = false;
  private pending: Promise<void> | undefined = undefined;
  private listeners: Set<(hideAi: boolean) => void> = new Set();
  private readRemote: () => Promise<Object | undefined>;
  private cache: AppDisplayCache;

  constructor(readRemote: () => Promise<Object | undefined>, cache: AppDisplayCache) {
    this.readRemote = readRemote;
    this.cache = cache;
  }

  get hideAi(): boolean { return this.hidden; }
  get generation(): number { return this.revision; }

  requireVisible(generation?: number): void {
    if (this.hidden || (generation !== undefined && generation !== this.revision)) {
      throw new ApiError('serviceUnavailable', 503);
    }
  }

  observe(listener: (hideAi: boolean) => void): () => void {
    this.listeners.add(listener);
    listener(this.hidden);
    return () => { this.listeners.delete(listener); };
  }

  refresh(): Promise<void> {
    if (this.pending) return this.pending;
    const operation = this.refreshValue();
    this.pending = operation;
    return operation.finally(() => { this.pending = undefined; });
  }

  private apply(hideAi: boolean): void {
    if (this.hidden === hideAi) return;
    this.hidden = hideAi;
    ++this.revision;
    this.listeners.forEach(listener => { try { listener(hideAi); } catch {} });
  }

  private async refreshValue(): Promise<void> {
    if (!this.cacheLoaded) {
      this.cacheLoaded = true;
      try {
        const cached = await this.cache.read();
        if (typeof cached === 'boolean') this.apply(cached);
      } catch { /* First launch remains hidden; a cache failure never enables AI. */ }
    }
    try {
      const hidden = parseSayRingAppDisplay(await this.readRemote());
      this.apply(hidden);
      try { await this.cache.write(hidden); } catch { /* Keep the accepted server value. */ }
    } catch { /* Keep the last accepted value on 404, network or malformed data. */ }
  }
}
