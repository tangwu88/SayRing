const baseUrl = process.env.SAYDIAN_API_BASE_URL ?? 'https://app.saydian.cn';
// Deliberately invalid sentinels: this probe must never authenticate or return
// a real access token. Do not replace them with a real QA account.
const invalidUsername = 'qa-invalid-account-never-use';
const invalidPassword = 'invalid-password';

const checks = [
  ['商城首页', '/api/v1/pages?code=SHOP_HOME'],
  ['健康百科', '/api/rf-article/article/index'],
  ['用户协议', '/api/rf-article/article-single/view?id=2'],
  ['匿名订单异常', '/api/inv-shop/v1/member/order/index?page=1'],
  ['匿名地址异常', '/api/v1/member/address?page=1'],
];

const results = [];

for (const [name, path] of checks) {
  results.push(await request(name, path));
}

results.push(
  await request('错误登录异常', '/api/v1/site/login', {
    method: 'POST',
    headers: {'content-type': 'application/x-www-form-urlencoded'},
    body: new URLSearchParams({
      username: invalidUsername,
      password: invalidPassword,
      group: 'app',
    }),
  }),
);

console.table(results);

if (results.some((result) => result.transportError)) {
  process.exitCode = 1;
}

async function request(name, path, options) {
  const startedAt = Date.now();
  try {
    const response = await fetch(new URL(path, baseUrl), {
      ...options,
      signal: AbortSignal.timeout(30_000),
    });
    const text = await response.text();
    let payload;
    try {
      payload = JSON.parse(text);
    } catch {
      payload = null;
    }
    return {
      name,
      http: response.status,
      code: payload?.code ?? '',
      message: payload?.message ?? '',
      dataType: Array.isArray(payload?.data)
        ? 'array'
        : payload?.data === null || payload?.data === undefined
          ? 'null'
          : typeof payload.data,
      durationMs: Date.now() - startedAt,
      transportError: '',
    };
  } catch (error) {
    return {
      name,
      http: '',
      code: '',
      message: '',
      dataType: '',
      durationMs: Date.now() - startedAt,
      transportError: error instanceof Error ? error.message : String(error),
    };
  }
}
