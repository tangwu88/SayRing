export interface NotificationPayload {
  eventId: string;
  eventType: string;
  entityId: string;
  route: string;
}

function asRecord(value: Object | undefined): Record<string, Object> {
  let decoded = value;
  for (let i = 0; i < 3 && typeof decoded === 'string'; i++) {
    if (decoded.length > 16384) return {};
    try { decoded = JSON.parse(decoded) as Object; } catch { return {}; }
  }
  return decoded && typeof decoded === 'object' && !Array.isArray(decoded)
    ? decoded as Record<string, Object> : {};
}

function findPayload(value: Object | undefined, depth: number = 0): Record<string, Object> {
  if (depth > 4) return {};
  const row = asRecord(value);
  if (row['event_type'] !== undefined || row['event_id'] !== undefined ||
    row['eventId'] !== undefined || row['schema_version'] !== undefined) return row;
  const keys = Object.keys(row).filter((key: string) =>
    key === 'extras' || key === 'extra' || key.toLowerCase().endsWith('.extra'));
  for (const key of keys) {
    const nested = findPayload(row[key], depth + 1);
    if (Object.keys(nested).length > 0) return nested;
  }
  return row;
}

function alias(row: Record<string, Object>, a: string, b: string): Object | undefined {
  const first = row[a];
  const second = row[b];
  if (first !== undefined && first !== null && second !== undefined && second !== null &&
    String(first) !== String(second)) throw new Error('conflicting notification fields');
  return first ?? second;
}

function identifier(value: Object | undefined): string {
  if (value === undefined || value === null) return '';
  if (typeof value !== 'string' && (typeof value !== 'number' || !Number.isSafeInteger(value))) {
    throw new Error('invalid notification identifier');
  }
  const result = String(value).trim();
  if (!/^[A-Za-z0-9._:-]{1,160}$/.test(result)) throw new Error('invalid notification identifier');
  return result;
}

export function normalizeNotificationPayload(value: Object | undefined): NotificationPayload | undefined {
  try {
    const row = findPayload(value);
    if (String(alias(row, 'schema_version', 'schemaVersion') ?? 1) !== '1') return undefined;
    const rawType = alias(row, 'event_type', 'type');
    let eventType = typeof rawType === 'string' ? rawType.trim().toLowerCase() : '';
    if (eventType === 'care_invitation_created') eventType = 'care_invitation';
    if (eventType === 'health_alert') eventType = 'health_warning';
    let entityId = identifier(alias(row, 'entity_id', 'entityId'));
    const rawRoute = alias(row, 'route', 'deepLink');
    if (rawRoute !== undefined && rawRoute !== null) {
      if (typeof rawRoute !== 'string') return undefined;
      const route = rawRoute.trim();
      const match = /^\/(care\/invitations|health\/alerts|health\/warnings)(?:\/([A-Za-z0-9._:-]{1,160}))?$/.exec(route);
      let routeType = '';
      if (route === 'care-invitations' || route === 'care_invitation_review') routeType = 'care_invitation';
      else if (route === 'health-alerts' || route === 'health_warning_history') routeType = 'health_warning';
      else if (route === 'notification_inbox' || route === '/notifications' || route === '/messages') routeType = 'system';
      else if (match) routeType = match[1] === 'care/invitations' ? 'care_invitation' : 'health_warning';
      if (!routeType || (eventType && eventType !== routeType)) return undefined;
      eventType = routeType;
      const routeEntity = match && match[2] ? match[2] : '';
      if (entityId && routeEntity && entityId !== routeEntity) return undefined;
      entityId = entityId || routeEntity;
    }
    if (!['care_invitation', 'health_warning', 'system'].includes(eventType)) return undefined;
    return {
      eventId: identifier(alias(row, 'event_id', 'eventId')),
      eventType: eventType,
      entityId: entityId,
      route: eventType === 'care_invitation' ? 'care-invitations' :
        eventType === 'health_warning' ? 'health-alerts' : 'messages'
    };
  } catch { return undefined; }
}
