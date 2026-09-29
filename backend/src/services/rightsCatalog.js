/**
 * Patient-rights reference content, with primary-source citations.
 * Wording is deliberately "may apply / check" — Bill Fixer flags, it does not give legal advice.
 */
export const RIGHTS = [
  {
    key: 'no_surprises_act',
    title: 'No Surprises Act',
    summary: 'Out-of-network charges for emergency care, and for certain providers at in-network hospitals, may be limited to your in-network cost-sharing.',
    appliesWhen: [
      'You received emergency care, or',
      'An out-of-network provider (for example anesthesia, radiology or pathology) treated you at an in-network hospital or surgery center, or',
      'You were taken by out-of-network air ambulance.',
    ],
    whatToDo: [
      'Compare your EOB: protected services should show in-network cost-sharing.',
      'Ask your insurer to reprocess the claim under the No Surprises Act.',
      'If it is not resolved, contact the No Surprises Help Desk at 1-800-985-3059.',
    ],
    citation: '42 U.S.C. § 300gg-111; 45 CFR §§ 149.410, 149.420, 149.440',
    sourceUrl: 'https://www.cms.gov/nosurprises',
    letterType: 'nsa_dispute',
  },
  {
    key: 'good_faith_estimate',
    title: 'Good Faith Estimate dispute',
    summary: 'If you were uninsured or self-paying and the bill is at least $400 more than your Good Faith Estimate from that provider, you may start a patient-provider dispute.',
    appliesWhen: [
      'You were uninsured or chose not to use insurance (self-pay), and',
      'You received a Good Faith Estimate, and',
      'Your bill from that provider or facility is $400 or more above the estimate.',
    ],
    whatToDo: [
      'Start the dispute within 120 calendar days of the date on your first bill.',
      'Keep a copy of the estimate and the bill.',
      'Ask the provider to pause collections while the dispute is open.',
    ],
    citation: '45 CFR § 149.620',
    sourceUrl: 'https://www.cms.gov/medical-bill-rights/help/dispute-a-bill',
    letterType: 'gfe_dispute',
  },
  {
    key: 'financial_assistance',
    title: 'Hospital financial assistance',
    summary: 'Nonprofit hospitals must have a written financial assistance policy, and patients who qualify cannot be charged more than amounts generally billed to insured patients.',
    appliesWhen: [
      'The hospital is a tax-exempt nonprofit, and',
      'Your household income is within the hospital’s published limits (often up to 200–400% of the federal poverty level).',
    ],
    whatToDo: [
      'Ask for the Financial Assistance Policy and application.',
      'Apply even after you have been billed — hospitals must accept applications for at least 240 days after the first post-discharge bill.',
      'Ask the hospital to hold the account while the application is reviewed.',
    ],
    citation: 'Internal Revenue Code § 501(r); 26 CFR § 1.501(r)-4 to -6',
    sourceUrl: 'https://www.irs.gov/charities-non-profits/charitable-organizations/financial-assistance-policies-faps',
    letterType: 'financial_assistance',
  },
  {
    key: 'itemized_bill',
    title: 'Request an itemized bill',
    summary: 'You can ask for a line-by-line statement showing every charge, code, date and quantity before you pay.',
    appliesWhen: ['Your statement shows totals only, or', 'You want to check individual charges.'],
    whatToDo: [
      'Ask for an itemized statement with CPT/HCPCS codes, dates of service and quantities.',
      'Ask the billing office to pause collection activity until you receive it.',
    ],
    citation: 'Common billing-office practice; required by some state laws',
    sourceUrl: 'https://www.cms.gov/medical-bill-rights',
    letterType: 'itemized_bill_request',
  },
  {
    key: 'eob_match',
    title: 'Compare with your EOB',
    summary: 'For an in-network claim, the amount you owe the provider should match the patient responsibility on your insurer’s Explanation of Benefits.',
    appliesWhen: ['You have insurance and the insurer has processed the claim.'],
    whatToDo: [
      'Match the claim by date of service and provider.',
      'If the bill is higher, ask the provider to correct the balance to the EOB amount.',
    ],
    citation: 'Your plan’s provider agreement and EOB',
    sourceUrl: 'https://www.cms.gov/medical-bill-rights',
    letterType: 'eob_mismatch_dispute',
  },
  {
    key: 'price_transparency',
    title: 'Hospital price transparency',
    summary: 'Hospitals must publish their standard charges, including discounted cash prices and negotiated rates, in a machine-readable file.',
    appliesWhen: ['The service was provided by a hospital.'],
    whatToDo: [
      'Compare your charge with the hospital’s own published cash price.',
      'If you are self-pay, ask for the published cash price to be applied.',
    ],
    citation: '45 CFR Part 180',
    sourceUrl: 'https://www.cms.gov/priorities/key-initiatives/hospital-price-transparency',
    letterType: 'cash_price_adjustment',
  },
];

export const RIGHTS_BY_KEY = Object.fromEntries(RIGHTS.map((r) => [r.key, r]));
