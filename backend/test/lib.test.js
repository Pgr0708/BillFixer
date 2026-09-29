import { test } from 'node:test';
import assert from 'node:assert/strict';
import { toCents, fromCents, formatUsd, toMillis, medianCents } from '../src/lib/money.js';
import { findProhibited, amountsGrounded, validateGeneratedText, extractAmountsCents } from '../src/lib/contentGuard.js';
import { redactText, last4 } from '../src/lib/redact.js';

test('money: exact parsing, no float drift', () => {
  assert.equal(toCents('1234.56'), 123456);
  assert.equal(toCents('0.1'), 10);
  assert.equal(toCents('-15.5'), -1550);
  assert.equal(toCents(0.1 + 0.2), 30);
  assert.equal(toCents(null), null);
  assert.throws(() => toCents('12.345'));
  assert.throws(() => toCents('abc'));
  assert.equal(fromCents(123456), '1234.56');
  assert.equal(fromCents(-5), '-0.05');
  assert.equal(formatUsd(123456789), '$1,234,567.89');
  assert.equal(toMillis('2.5'), 2500);
  assert.equal(medianCents([300, 100, 200, 400]), 250);
});

test('content guard: prohibited phrases are caught', () => {
  assert.ok(findProhibited('This charge is illegal'));
  assert.ok(findProhibited('This looks like FRAUD'));
  assert.ok(findProhibited('You will save $400 by doing this'));
  assert.equal(findProhibited('Ask the billing office to review this charge.'), null);
});

test('content guard: amounts must be grounded in evidence (±1¢)', () => {
  assert.deepEqual(extractAmountsCents('Pay $1,234.56 not $50'), [123456, 5000]);
  assert.ok(amountsGrounded('The difference is $150.00.', new Set([15000])));
  assert.ok(!amountsGrounded('The difference is $151.00.', new Set([15000])));
  assert.ok(validateGeneratedText('Your EOB shows $540.00.', new Set([54000])).ok);
  assert.equal(validateGeneratedText('You were overcharged illegally by $540.00.', new Set([54000])).ok, false);
});

test('redaction: SSN, DOB, email, phone, dotted ICD-10 removed', () => {
  const out = redactText('SSN 123-45-6789 DOB: 01/02/1980 mail a@b.com call (555) 123-4567 dx J18.9');
  assert.ok(!/123-45-6789|01\/02\/1980|a@b\.com|555|J18\.9/.test(out), out);
  assert.equal(last4('ABC123456789'), '••••6789');
});
