import { ApiError } from './Contracts';

export type RingModule = 'health_library' | 'mall';
export interface ModuleAccess {
  readonly generation: number;
  allows(module: RingModule): boolean;
  require(module: RingModule, generation?: number): void;
}
export interface RingModuleFlags { health_library: boolean; mall: boolean; }
export interface RingModuleConfig { modules: RingModuleFlags; validity: number; }
export function ringModuleForPath(path: string): RingModule | undefined {
  if (path.startsWith('/global/api/saydian-app/v2/commerce/') || path.startsWith('/api/inv-shop/') ||
    path === '/api/v1/pages?code=SHOP_HOME') return 'mall';
  if (/^\/global\/api\/saydian-app\/v2\/content\/(articles|categories)([/?]|$)/.test(path) ||
    path.startsWith('/api/rf-article/article/') || path.startsWith('/api/rf-article/article-cate/')) return 'health_library';
  return undefined;
}
export async function withModuleVisibility<T>(path: string, access: ModuleAccess, read: () => Promise<T>): Promise<T> {
  const module = ringModuleForPath(path), generation = access.generation;
  if (module) access.require(module);
  const result = await read();
  if (module) access.require(module, generation);
  return result;
}
export function parseRingModules(raw: Object | undefined): RingModuleConfig {
  const value = raw as Record<string, Object>;
  const config = value?.['moduleVisibility'] as Record<string, Object>;
  const flags = config?.['modules'] as Record<string, Object>;
  const seconds = config?.['validForSeconds'];
  if (!value || value['product'] !== 'say-ring' || value['platform'] !== 'harmonyos' ||
    !config || config['schemaVersion'] !== 1 || !flags || Object.keys(flags).length !== 2 ||
    typeof flags['health_library'] !== 'boolean' || typeof flags['mall'] !== 'boolean' ||
    typeof seconds !== 'number' || !Number.isInteger(seconds) || seconds < 1 || seconds > 300) {
    throw new ApiError('页面配置暂时无法读取');
  }
  return { modules: { health_library: flags['health_library'] as boolean, mall: flags['mall'] as boolean }, validity: seconds * 1000 };
}
export class ModuleDisplayState implements ModuleAccess {
  private flags: RingModuleFlags = { health_library: false, mall: false };
  private revision: number = 0;
  private expiry: number = -1;
  private poll: number = -1;
  private pending: Promise<void> | undefined = undefined;
  private foreground: boolean = false;
  private expiresAt: number = 0;
  private now: () => number;
  private listeners: Set<() => void> = new Set();
  private readRemote: () => Promise<Object | undefined>;
  constructor(readRemote: () => Promise<Object | undefined>, now: () => number = () => Date.now()) { this.readRemote = readRemote; this.now = now; }
  get generation(): number { return this.revision; }
  allows(module: RingModule): boolean { return this.now() < this.expiresAt && this.flags[module]; }
  require(module: RingModule, generation?: number): void {
    if (!this.allows(module) || (generation !== undefined && generation !== this.revision)) throw new ApiError('此功能暂未开放', 404);
  }
  observe(listener: () => void): () => void { this.listeners.add(listener); listener(); return () => { this.listeners.delete(listener); }; }
  private apply(flags: RingModuleFlags): void {
    if (flags.health_library === this.flags.health_library && flags.mall === this.flags.mall) return;
    this.flags = flags; ++this.revision;
    this.listeners.forEach(listener => { try { listener(); } catch {} });
  }
  close(): void {
    this.expiresAt = 0;
    clearTimeout(this.expiry); this.expiry = -1;
    this.apply({ health_library: false, mall: false });
  }
  refresh(): Promise<void> {
    if (this.pending) return this.pending;
    this.pending = this.read().finally(() => { this.pending = undefined; });
    return this.pending;
  }
  private async read(): Promise<void> {
    const started = this.now();
    try {
      const config = parseRingModules(await this.readRemote());
      const remaining = config.validity - Math.max(0, this.now() - started);
      if (remaining <= 0) { this.close(); return; }
      clearTimeout(this.expiry);
      this.expiresAt = this.now() + remaining;
      this.apply(config.modules);
      this.expiry = setTimeout(() => this.close(), remaining);
    } catch { this.close(); }
    finally {
      clearTimeout(this.poll);
      if (this.foreground) this.poll = setTimeout(() => { this.refresh(); }, 30000);
    }
  }
  setForeground(value: boolean): void {
    this.foreground = value; clearTimeout(this.poll); this.poll = -1;
    if (value && this.now() >= this.expiresAt) this.close();
    if (value) this.refresh();
  }
}
