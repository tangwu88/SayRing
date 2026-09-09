import test from 'node:test';
import assert from 'node:assert/strict';
import { articleBlocks, safeArticleImage } from '../entry/src/main/ets/model/Contracts.ts';

test('public article images keep their original order between text blocks', () => {
  const blocks = articleBlocks('<p>Before</p><img src="/attachment/images/fixture.png" alt="示意"><p>After</p>');
  assert.deepEqual(blocks.map(item => item.kind), ['text', 'image', 'text']);
  assert.equal(blocks[1].url, 'https://app.saydian.cn/attachment/images/fixture.png');
  assert.equal(blocks[1].text, '示意');
  assert.equal(blocks[0].text, 'Before');
  assert.equal(blocks[2].text, 'After');
});
test('images cannot target unrelated, insecure or credential-bearing origins', () => {
  for (const value of ['http://example.org/x', 'https://app.saydian.cn.evil.example/x',
    'https://user@app.saidian.cc/x', '//evil.example/x', 'data:image/svg+xml,bad',
    'javascript:bad', '/api/v1/member/member/my', '/attachment/../api/member',
    '/attachment/%2e%2e/api/member', '/attachment/a?token=synthetic', '/attachment/a\\evil']) {
    assert.equal(safeArticleImage(value), '', value);
  }
  assert.equal(safeArticleImage('https://app.saydian.cn/attachment/images/fixture.png'), 'https://app.saydian.cn/attachment/images/fixture.png');
});
test('image-only articles remain readable, invalid images have explicit fallback', () => {
  assert.equal(articleBlocks('<img src="/attachment/images/fixture.png">')[0].kind, 'image');
  assert.equal(articleBlocks('<img src="javascript:bad">')[0].kind, 'unavailable');
  assert.deepEqual(articleBlocks(''), []);
});
test('scripts and styles are not parsed as visible text or images', () => {
  const blocks = articleBlocks('<script><img src="/attachment/hidden.png"></script><style>bad</style><p>safe</p>');
  assert.deepEqual(blocks.map(item => item.text), ['safe']);
});
