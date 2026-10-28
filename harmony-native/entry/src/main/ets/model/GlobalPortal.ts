import { ApiError, articleBlocks, safeArticleImage } from './Contracts';
import type { Article, ArticleBlock } from './Contracts';
import type { ArticleCategory } from './AccountPageContracts';
import type { ShopHome, ShopProduct, ShopCategory } from './ExperienceContracts';
import { careInvitationFallback } from './CareContracts';
import type { CareMember, CareInvitation, CareShareSettings, CareMetric, CareMetricSpec, CareRecord, CareField } from './CareContracts';
import { chinaDaySeconds } from './CareContracts';

export function portalObject(value: Object | undefined): Record<string, Object> {
  return value !== null && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, Object> : {};
}
export function portalText(value: Object | undefined, limit: number = 240): string {
  return typeof value === 'string' ? value.replace(/[\x00-\x1f\x7f]/g, '').trim().slice(0, limit) : '';
}
export function portalId(value: Object | undefined): string {
  if (typeof value !== 'string' || !/^[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}$/i.test(value)) throw new ApiError('信息已更新，请返回列表重新选择');
  return value.toLowerCase();
}
export function portalRows(value: Object | undefined): Object[] {
  const row = portalObject(value), values = Array.isArray(value) ? value : row['items'] ?? row['list'];
  if (!Array.isArray(values)) throw new ApiError('内容暂时无法读取，请稍后重试');
  return values as Object[];
}
export function portalModulePath(route: string, query: string = ''): string {
  return `/global/api/saydian-app/v2/${route}?product=say-ring&platform=harmonyos&locale=zh-Hans${query ? '&' + query : ''}`;
}
export function portalCategories(value: Object | undefined): ArticleCategory[] {
  const seen: Set<string> = new Set();
  return portalRows(value).map((raw: Object): ArticleCategory => {
    const row = portalObject(raw), id = portalId(row['id']), title = portalText(row['title'] ?? row['name'], 80);
    if (!title || seen.has(id)) throw new ApiError('健康分类暂时无法读取，请刷新重试');
    seen.add(id); return { id, title };
  });
}
export function portalArticle(value: Object | undefined, expectedId: string = ''): Article {
  const row = portalObject(value), id = portalId(row['id']), title = portalText(row['title']);
  if ((expectedId && id !== expectedId) || !title) throw new ApiError('内容已更新，请返回列表重新打开');
  return { id, title, description: portalText(row['description'] ?? row['summary'], 1000),
    content: typeof row['contentHtml'] === 'string' ? row['contentHtml'] as string : '' };
}
export function portalArticles(value: Object | undefined): Article[] {
  return portalRows(value).map((row: Object): Article => portalArticle(row));
}

export interface PortalRelationship { id: string; inviterId: string; recipientId: string; incoming: boolean;
  state: string; name: string; metrics: string[]; }
export function portalRelationships(value: Object | undefined, owner: string, now: number): PortalRelationship[] {
  const ownId = portalId(owner), seen: Set<string> = new Set();
  return portalRows(value).map((raw: Object): PortalRelationship => {
    const row = portalObject(raw), id = portalId(row['id']);
    const inviterId = portalId(row['inviterMemberId']), recipientId = portalId(row['recipientMemberId']);
    const incoming = recipientId === ownId;
    if (inviterId === recipientId || (!incoming && inviterId !== ownId) || seen.has(id) ||
      (row['direction'] !== undefined && row['direction'] !== (incoming ? 'received' : 'sent'))) throw new ApiError('关爱关系已变化，请刷新列表');
    seen.add(id);
    let state = portalText(row['status']);
    if (!['pending', 'active', 'rejected', 'revoked', 'expired'].includes(state)) throw new ApiError('关爱关系暂时无法读取');
    if (row['expiresAt'] !== null && row['expiresAt'] !== undefined) {
      const expiry = typeof row['expiresAt'] === 'string' ? Date.parse(row['expiresAt'] as string) : NaN;
      if (!Number.isFinite(expiry)) throw new ApiError('关爱关系暂时无法读取');
      if (expiry <= now) state = 'expired';
    }
    if (!Array.isArray(row['metrics'])) throw new ApiError('共享设置暂时无法读取');
    const metrics: string[] = [];
    (row['metrics'] as Object[]).forEach((metric: Object) => {
      if (typeof metric !== 'string' || !/^[a-z][a-z0-9_]{0,63}$/.test(metric) || metrics.includes(metric)) throw new ApiError('共享设置暂时无法读取');
      metrics.push(metric);
    });
    const person = portalObject(row[incoming ? 'inviter' : 'recipient']);
    const personId = person['id'];
    const name = personId === (incoming ? inviterId : recipientId) ? portalText(person['nickname'], 80) : '';
    return { id, inviterId, recipientId, incoming, state, metrics: metrics.sort(), name };
  });
}
export function portalCareMembers(relations: PortalRelationship[]): CareMember[] {
  return relations.filter((row: PortalRelationship) => !row.incoming && row.state === 'active').map((row: PortalRelationship): CareMember =>
    ({ relationId: row.id, memberId: row.recipientId, name: row.name || '关爱成员', mobile: '' }));
}
export function portalCareInvitations(relations: PortalRelationship[]): CareInvitation[] {
  return relations.filter((row: PortalRelationship) => row.incoming).map((row: PortalRelationship): CareInvitation =>
    ({ id: row.id, inviterId: row.inviterId, name: row.name || careInvitationFallback(row.inviterId), mobile: '',
      state: row.state === 'active' ? 'accepted' : row.state === 'pending' ? 'pending' : row.state === 'rejected' ? 'rejected' : 'other' }));
}
const SHARE_KEYS: string[][] = [['steps','steps'],['reliang','calories'],['juli','distance'],['sleep','sleep'],
  ['heartReat','heart_rate'],['bloodOxygen','blood_oxygen'],['bodyTemperature','temperature'],['HRV','hrv']];
export function portalShareSupported(key: string): boolean { return SHARE_KEYS.some((pair:string[])=>pair[0]===key); }
export function portalShareSettings(relation: PortalRelationship): CareShareSettings {
  const enabled: string[] = [], unknown: string[] = [];
  relation.metrics.forEach((metric: string) => {
    const known = SHARE_KEYS.find((pair: string[]) => pair[1] === metric);
    if (known) enabled.push(known[0]); else unknown.push(metric);
  });
  return { enabled: enabled.sort(), unknown: unknown.sort() };
}
export function portalShareBody(enabled: string[], unknown: string[]): string {
  const metrics = enabled.map((key: string): string => {
    const match = SHARE_KEYS.find((pair: string[]) => pair[0] === key);
    if (!match) throw new ApiError('当前项目暂不支持共享');
    return match[1];
  });
  if (unknown.some((key: string) => !/^[a-z][a-z0-9_]{0,63}$/.test(key))) throw new ApiError('共享设置已更新，请重新读取');
  return JSON.stringify({ metrics: Array.from(new Set([...metrics, ...unknown])).sort() });
}
export const PORTAL_CARE_METRICS: CareMetricSpec[] = [
  {key:'heart',title:'心率',endpoint:'',type:'heart_rate',unit:'次/分'},
  {key:'oxygen',title:'血氧',endpoint:'',type:'blood_oxygen',unit:'%'},
  {key:'temperature',title:'皮肤温度',endpoint:'',type:'temperature',unit:'℃'},
  {key:'hrv',title:'HRV',endpoint:'',type:'hrv',unit:'ms'},
  {key:'sleep',title:'睡眠',endpoint:'',type:'sleep',unit:'分钟'},
  {key:'steps',title:'步数',endpoint:'',type:'steps',unit:'步'},
  {key:'distance',title:'距离',endpoint:'',type:'distance',unit:''},
  {key:'calories',title:'热量',endpoint:'',type:'calories',unit:''}
];
export function portalCareWindow(day: string): string {
  const from = chinaDaySeconds(day) * 1000;
  return `from=${encodeURIComponent(new Date(from).toISOString())}&to=${encodeURIComponent(new Date(from + 86400000).toISOString())}`;
}
const RECORD_FIELDS: string[][] = [['bpm','心率'],['heartRate','心率'],['percent','血氧'],['spo2','血氧'],
  ['celsius','皮肤温度'],['temperature','皮肤温度'],['milliseconds','HRV'],['hrv','HRV'],
  ['totalMinutes','总睡眠'],['durationMinutes','总睡眠'],['steps','步数'],['distance','距离'],['calories','热量'],['value','记录值']];
const METRIC_FIELDS: Record<string,string[]> = {heart:['bpm','heartRate','value'],oxygen:['percent','spo2','value'],
  temperature:['celsius','temperature','value'],hrv:['milliseconds','hrv','value'],sleep:['totalMinutes','durationMinutes','value'],
  steps:['steps','value'],distance:['distance','value'],calories:['calories','value']};
export function portalCareMetric(spec: CareMetricSpec, value: Object | undefined): CareMetric {
  const records: CareRecord[] = [], seen: Set<string> = new Set();
  portalRows(value).forEach((raw: Object) => {
    const row = portalObject(raw), id = portalText(row['id'], 180), time = typeof row['observedAt'] === 'string' ? Date.parse(row['observedAt'] as string) : NaN;
    if (!id || seen.has(id) || row['metric'] !== spec.type || !Number.isFinite(time)) throw new ApiError('健康记录暂时无法读取，请刷新重试');
    seen.add(id);
    const values = portalObject(row['values']), fields: CareField[] = [];
    RECORD_FIELDS.forEach((pair: string[]) => {
      if(!METRIC_FIELDS[spec.key]?.includes(pair[0]))return;
      const number = values[pair[0]];
      if (typeof number === 'number' && Number.isFinite(number)) fields.push({label:pair[1],value:number,unit:portalText(row['unit'],32) || spec.unit});
    });
    if (!fields.length) throw new ApiError('健康记录暂时无法读取，请刷新重试');
    records.push({ id, time:new Date(time + 8*3600000).toISOString().slice(0,16).replace('T',' '), order:time, fields, samples:[], frequency:0 });
  });
  records.sort((a: CareRecord,b: CareRecord) => b.order-a.order);
  return { key:spec.key,title:spec.title,unit:spec.unit,state:records.length?'ready':'empty',message:records.length?'':'当日暂无记录',records };
}

export interface PortalProduct { id: string; name: string; price: string; covers: string[]; blocks: ArticleBlock[]; }
export function portalMoney(row: Record<string,Object>): string {
  const amount=row['priceMinor'] ?? row['priceCents'],currency=portalText(row['currency'],3),exponent=row['currencyExponent'];
  if (typeof amount!=='number'||!Number.isSafeInteger(amount)||amount<0||!/^[A-Z]{3}$/.test(currency)||
    typeof exponent!=='number'||!Number.isInteger(exponent)||exponent<0||exponent>4) return '价格待确认';
  return `${currency} ${(amount / Math.pow(10,exponent)).toFixed(exponent)}`;
}
export function portalProduct(value: Object | undefined, expectedId: string = ''): PortalProduct {
  const row=portalObject(value),id=portalId(row['id']),name=portalText(row['displayName'] ?? row['name'] ?? row['title'],160);
  if ((expectedId && expectedId!==id)||!name) throw new ApiError('商品已更新，请返回列表重新打开');
  const covers: string[]=[];
  const gallery=row['gallery'] ?? row['images'] ?? row['covers'];
  const images:Object[]=[row['coverImage'] ?? row['coverUrl'] ?? ''];
  if(Array.isArray(gallery))images.push(...gallery as Object[]);
  images.slice(0,30).forEach((image:Object)=>{
    const source=typeof image==='string'?image:portalObject(image)['url'];
    if(typeof source!=='string')return;
    const url=safeArticleImage(source);
    if(url&&!covers.includes(url)) covers.push(url);
  });
  const content=typeof row['detailHtml']==='string'?row['detailHtml'] as string:typeof row['descriptionHtml']==='string'?row['descriptionHtml'] as string:
    typeof row['contentHtml']==='string'?row['contentHtml'] as string:typeof row['description']==='string'?row['description'] as string:'';
  return {id,name,price:portalMoney(row),covers,blocks:articleBlocks(content)};
}
export function portalShopCategory(id: string, name: string, value: Object | undefined): ShopCategory {
  const row=portalObject(value),total=row['total'],page=row['page'];
  if(typeof total!=='number'||!Number.isSafeInteger(total)||total<0||typeof page!=='number'||!Number.isSafeInteger(page)||page<1) throw new ApiError('商品列表暂时无法读取');
  const seen:Set<string>=new Set();
  const products=portalRows(value).map((raw:Object):ShopProduct=>{
    const item=portalProduct(raw), stock=portalObject(raw)['stock'];
    if(seen.has(item.id))throw new ApiError('商品列表已更新，请刷新');
    seen.add(item.id);
    return {id:item.id,name:item.name,picture:item.covers[0]??'',price:item.price,
      stock:typeof stock==='number'&&Number.isSafeInteger(stock)&&stock>=0?stock:-1};
  });
  if(products.length>total)throw new ApiError('商品列表已更新，请刷新');
  return {id,name,products,total,page};
}
export function portalShopHome(value: Object | undefined, products: Object | undefined): ShopHome {
  const row=portalObject(value), groups=row['categories'];
  if(!Array.isArray(groups))throw new ApiError('商品分类暂时无法读取');
  const categories: ShopCategory[]=(groups as Object[]).map((group:Object):ShopCategory=>{
    const category=portalObject(group),id=portalId(category['id']),name=portalText(category['name'] ?? category['title'],80);
    if(!name)throw new ApiError('商品分类暂时无法读取');
    return {id,name,products:[],page:0,total:0};
  });
  return {bannerUrl:'',categories:[portalShopCategory('all','全部',products),...categories]};
}
