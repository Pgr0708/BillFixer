import { test } from 'node:test';
import assert from 'node:assert/strict';
import { findProhibited } from '../src/lib/contentGuard.js';

// Template path only: config needs a JWT secret, and the LLM stays off.
process.env.JWT_ACCESS_SECRET ||= 'test-secret-test-secret-test-secret-00';
process.env.LLM_ENABLED = 'false';
const { generateLetter, LETTER_TYPES } = await import('../src/services/letterService.js');

const facts = { providerName: 'Riverside Medical', accountNumber: 'A-1001', serviceDates: '2026-03-15', claimNumber: 'C-77',
  eobDate: '2026-04-02', code: '71046', flaggedAmount: 42000, referenceAmount: 18000, difference: 24000, deadline: '2026-07-13',
  findingSentence: 'The statement balance is higher than the EOB amount.', evidenceSentence: 'Line 3: 71046 Chest X-Ray' };

test('every letter type renders a complete formal letter (template path)', async () => {
  for (const type of LETTER_TYPES) {
    const { content, subject } = await generateLetter({ ...facts, type }, { signerName: 'Jane Doe' });
    assert.ok(subject.length > 10, type);
    for (const part of ['CERTIFIED MAIL', 'Re:', 'Dear Sir or Madam:', 'within 30 days', 'expressly reserved', 'Sincerely,', 'Jane Doe'])
      assert.ok(content.includes(part), `${type} missing ${part}`);
    assert.ok(!/undefined|null|NaN/.test(content), `${type} leaked a raw value`);
    assert.equal(findProhibited(content), null, `${type} uses a prohibited phrase`);
  }
});

test('letters cite the right rules', async () => {
  const cite = async (type) => (await generateLetter({ ...facts, type })).content;
  assert.match(await cite('collections_dispute'), /15 U\.S\.C\. 1692g\(b\)/);
  assert.match(await cite('gfe_dispute'), /45 CFR 149\.620/);
  assert.match(await cite('nsa_dispute'), /300gg-131/);
  assert.match(await cite('financial_assistance'), /1\.501\(r\)-6/);
  assert.match(await cite('itemized_bill_request'), /45 CFR 164\.524/);
  assert.match(await cite('insurance_appeal'), /2560\.503-1/);
  const eob = await cite('eob_mismatch_dispute');
  assert.match(eob, /Adjust my balance to \$180\.00/);
  assert.match(eob, /dated April 2, 2026/);
  assert.match(eob, /Date\(s\) of service: March 15, 2026/);
});
