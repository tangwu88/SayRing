import { ApiError } from './Contracts';

export interface AddressDraft {
  id: string; name: string; mobile: string; details: string; isDefault: boolean;
  province: string; city: string; area: string;
}
export interface RegionChoice { code: string; name: string; }
export interface RegionCatalog {
  provinces: Record<string, string>; cities: Record<string, string>; areas: Record<string, string>;
}
export function emptyAddressDraft(): AddressDraft {
  return { id: '', name: '', mobile: '', details: '', isDefault: true, province: '', city: '', area: '' };
}
export function copyAddressDraft(draft: AddressDraft): AddressDraft { return { ...draft }; }
export function emptyRegions(): RegionCatalog { return { provinces: {}, cities: {}, areas: {} }; }
function regionMap(raw: Object | undefined): Record<string, string> {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new ApiError('地区暂时无法读取');
  const input = raw as Record<string, Object>; const result: Record<string, string> = {};
  Object.keys(input).forEach((code: string) => {
    const name = input[code];
    if (!/^(?:\d{6}|\d{9})$/.test(code) || typeof name !== 'string' || !name.trim()) throw new ApiError('地区信息不完整');
    result[code] = name;
  });
  return result;
}
export function parseRegions(text: string): RegionCatalog {
  let input: Record<string, Object>;
  try { input = JSON.parse(text) as Record<string, Object>; }
  catch { throw new ApiError('地区暂时无法读取'); }
  if (!input || Array.isArray(input)) throw new ApiError('地区信息不完整');
  return { provinces: regionMap(input['provinces']), cities: regionMap(input['cities']), areas: regionMap(input['areas']) };
}
export function addressRegionChoices(regions: RegionCatalog, draft: AddressDraft, level: number): RegionChoice[] {
  const values = level === 0 ? regions.provinces : level === 1 ? regions.cities : regions.areas;
  const prefix = level === 0 ? '' : level === 1 ? draft.province.slice(0, 2) : draft.city.slice(0, 4);
  if (level > 0 && !prefix) return [];
  return Object.keys(values).filter((code: string) => code.startsWith(prefix))
    .map((code: string): RegionChoice => { return { code, name: values[code] }; });
}
export function selectAddressRegion(draft: AddressDraft, level: number, code: string): AddressDraft {
  if (level === 0) return { ...draft, province: code, city: '', area: '' };
  if (level === 1) return { ...draft, city: code, area: '' };
  return { ...draft, area: code };
}
export function addressValidation(draft: AddressDraft, regions: RegionCatalog): string {
  if (draft.id && (!/^\d+$/.test(draft.id) || Number(draft.id) <= 0)) return '地址编号无效';
  if (!draft.name.trim() || draft.name.trim().length > 60) return '请填写收货人（不超过 60 字）';
  if (!/^1\d{10}$/.test(draft.mobile.trim())) return '请输入正确的手机号';
  if (![0, 1, 2].every((level: number) => addressRegionChoices(regions, draft, level)
    .some((item: RegionChoice) => item.code === (level === 0 ? draft.province : level === 1 ? draft.city : draft.area)))) {
    return '请选择完整省、市、区县';
  }
  if (!draft.details.trim() || draft.details.trim().length > 300) return '请填写详细地址（不超过 300 字）';
  return '';
}
export function addressBody(draft: AddressDraft, regions: RegionCatalog): string {
  const error = addressValidation(draft, regions); if (error) throw new ApiError(error);
  return JSON.stringify({ realname: draft.name.trim(), mobile: draft.mobile.trim(),
    address_details: draft.details.trim(), is_default: draft.isDefault ? 1 : 0,
    region: [regions.provinces[draft.province], regions.cities[draft.city], regions.areas[draft.area]].join(' '),
    province_id: Number(draft.province), city_id: Number(draft.city), area_id: Number(draft.area) });
}
