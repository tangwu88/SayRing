import { readUiSource } from './support/localized-ui-source.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readUiSource(new URL('../entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
const input = source.slice(source.indexOf('  ProfileInput('), source.indexOf('  ProfileEditorContent('));
const page = source.slice(source.indexOf('  ProfileEditorContent('), source.indexOf('  UnitSettingsContent('));

// Source contracts complement (not replace) the populated form's on-device rendering check.
test('profile inputs retain a visible field label independently of the entered value', () => {
  assert.match(input, /Text\(label\)/);
  assert.match(input, /TextInput\(\{ text: value/);
  assert.match(input, /onChange\(change\)/);
  assert.match(input, /accessibilityText\(label\)/);
  for (const [label, model, id, numeric] of [
    ['昵称', 'editNickname', 'profile_nickname', false],
    ['身高（cm）', 'editHeight', 'profile_height', true],
    ['体重（kg）', 'editWeight', 'profile_weight', true],
  ]) {
    assert.ok(page.includes(`this.ProfileInput('${label}', this.${model}, '${id}', ${numeric}, (value: string) => this.${model} = value)`));
  }
});

test('birthday stays labelled after selection and numeric keyboard and large text behavior remain available', () => {
  assert.match(page, /Text\('出生日期'\)/);
  assert.match(page, /Text\(this.editBirthday \|\| '请选择出生日期'\)/);
  assert.match(input, /numeric \? InputType.NUMBER_DECIMAL : InputType.Normal/);
  assert.match(input, /height\(this.controlHeight\(48\)\)/);
  assert.match(input, /enabled\(!this.formBusy\)/);
  assert.match(page, /onClick\(\(\) => this.chooseBirthday\(\)\)/);
});
