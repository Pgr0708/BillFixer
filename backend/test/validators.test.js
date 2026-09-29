import { test } from 'node:test';
import assert from 'node:assert/strict';
import { submitBill, isoDate, password, register, newEmail, createLetter, analyzeBody } from '../src/validators/index.js';

test('bill: money strings are normalised, unknown fields rejected', () => {
  const ok = submitBill.parse({ providerName: 'Riverside', totalCharges: '$2,250.00', lineItems: [
    { code: '71046', description: 'Chest X-Ray', totalAmount: 420, quantity: 1 },
  ] });
  assert.equal(ok.totalCharges, '2250.00');
  assert.equal(ok.lineItems[0].totalAmount, '420.00');
  assert.equal(ok.lineItems[0].quantity, '1');
  assert.throws(() => submitBill.parse({ providerName: 'X', patientName: 'Jane Doe' }));
});

test('bill: service dates must be ordered', () => {
  assert.throws(() => submitBill.parse({ providerName: 'X', serviceDateStart: '2026-03-16', serviceDateEnd: '2026-03-15' }));
});

test('dates: impossible calendar dates are rejected', () => {
  assert.equal(isoDate.safeParse('2026-02-30').success, false);
  assert.equal(isoDate.safeParse('2026-02-28').success, true);
});

test('password policy', () => {
  assert.equal(password.safeParse('short1').success, false);
  assert.equal(password.safeParse('longenoughbutnodigits').success, false);
  assert.equal(password.safeParse('BillFixer2026').success, true);
  assert.equal(password.safeParse('Password123').success, false);   // common
  assert.equal(password.safeParse(' BillFixer2026').success, false); // edge space
  assert.equal(password.safeParse('aaaa1234xyz').success, false);   // repeats
});

test('new email rules', () => {
  const ok = (e) => newEmail.safeParse(e).success;
  assert.equal(newEmail.parse('  Jane.Doe+bills@Example.COM '), 'jane.doe+bills@example.com');
  for (const bad of ['jane', 'jane@', '@x.com', 'jane@x', 'jane@x.c', 'jane..doe@x.com', '.jane@x.com', 'jane.@x.com',
    'jane@-x.com', 'jane doe@x.com', 'jane@gmial.com', `${'a'.repeat(65)}@x.com`]) assert.equal(ok(bad), false, bad);
  assert.equal(ok('j.o-e_1@mail.co.uk'), true);
});

test('register: password may not contain the email name', () => {
  const r = register.safeParse({ email: 'johnsmith@x.com', password: 'johnsmith99' });
  assert.equal(r.success, false);
  assert.deepEqual(r.error.issues[0].path, ['password']);
  assert.equal(register.safeParse({ email: 'johnsmith@x.com', password: 'BillFixer2026' }).success, true);
});

test('letters need a type or a finding', () => {
  assert.equal(createLetter.safeParse({}).success, false);
  assert.equal(createLetter.safeParse({ type: 'duplicate_dispute' }).success, true);
});

test('analysis context: income is money, state is 2 letters', () => {
  assert.equal(analyzeBody.parse({ context: { annualIncome: '48000', state: 'tx' } }).context.state, 'TX');
  assert.equal(analyzeBody.safeParse({ context: { householdSize: 0 } }).success, false);
});
