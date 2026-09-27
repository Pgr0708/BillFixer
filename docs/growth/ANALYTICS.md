# BillFixer — Analytics

> DELETE BEFORE SUBMISSION

---

## Privacy Rules (non-negotiable)

- **NO** patient names, DOBs, insurance IDs, or document content in analytics events
- **NO** bill amounts, case balances, or provider names in events
- **NO** finding types linked to individual users in detailed logs
- Analytics must be aggregate/anonymized
- Comply with App Store privacy label declarations

---

## Event Taxonomy

### Onboarding Funnel
| Event | Properties |
|---|---|
| `onboarding_started` | — |
| `onboarding_step_viewed` | step: 1/2/3 |
| `onboarding_completed` | — |
| `onboarding_skipped` | at_step: int |
| `auth_method_selected` | method: apple/email |
| `auth_completed` | is_new_user: bool |
| `notifications_permission_shown` | — |
| `notifications_permission_granted` | — |
| `notifications_permission_denied` | — |

---

### Core Analysis Funnel (Primary KPI)
| Event | Properties |
|---|---|
| `scan_started` | source: scan_tab/home_cta |
| `capture_method_selected` | method: camera/pdf/photos |
| `pages_captured` | page_count: int |
| `document_type_added` | type: bill/eob/gfe |
| `ocr_completed` | confidence_avg: float (no content) |
| `ocr_review_started` | field_edit_count: 0 |
| `ocr_field_edited` | field_type: string (generic) |
| `ocr_review_completed` | time_spent_seconds: int |
| `eob_prompt_shown` | — |
| `eob_added` | — |
| `eob_skipped` | — |
| `analysis_started` | has_eob: bool |
| `analysis_completed` | finding_count: int, has_strong: bool, duration_seconds: int |
| `analysis_failed` | error_code: string |

---

### Findings Engagement
| Event | Properties |
|---|---|
| `findings_viewed` | finding_count: int, severity_distribution: {strong:n, likely:n, possible:n, info:n} |
| `finding_expanded` | severity: strong/likely/possible/info (NOT type) |
| `finding_dismissed` | severity: string |
| `recommended_action_tapped` | — |
| `all_findings_viewed` | — |

---

### Actions
| Event | Properties |
|---|---|
| `letter_generation_started` | letter_type: string |
| `letter_generation_completed` | letter_type: string, duration_seconds: int |
| `letter_edited` | — |
| `letter_shared` | method: copy/share/pdf |
| `letter_marked_sent` | — |
| `script_viewed` | call_target: provider/insurer/collections |
| `script_branch_followed` | branch_key: string |
| `pdf_export_completed` | — |

---

### Case Management
| Event | Properties |
|---|---|
| `case_created` | — |
| `case_status_updated` | new_status: string |
| `case_outcome_recorded` | outcome_type: string, has_savings: bool |
| `deadline_added` | deadline_type: string |
| `deadline_completed` | — |
| `case_deleted` | — |

---

### Subscription
| Event | Properties |
|---|---|
| `paywall_shown` | trigger: string (feature name) |
| `paywall_dismissed` | time_viewed_seconds: int |
| `paywall_plan_toggled` | selected: monthly/annual |
| `purchase_started` | product_id: string |
| `purchase_completed` | product_id: string |
| `purchase_failed` | error_code: string |
| `restore_tapped` | — |
| `restore_completed` | restored_product: string |

---

## KPIs to Track (Dashboard)

### Activation
- % of registered users who complete their first analysis
- % of registered users who capture a bill in first session

### Core Engagement
- Analysis started → Analysis completed rate
- OCR review completion rate
- % of analyses that result in at least 1 finding
- % of findings that trigger an action (letter/script)
- % of cases that have a letter marked sent

### Quality
- User-reported false-positive rate ("This finding is wrong" feedback)
- OCR confidence average by document type
- Analysis failure rate

### Retention
- Day-1, Day-7, Day-30 retention (feature usage, not just launch)
- Month-2 subscription retention

### Revenue
- Free → Premium conversion rate
- Monthly vs Annual ratio
- Paywall → Purchase rate by trigger point
- LTV by cohort

### Outcomes (self-reported, optional)
- % of resolved cases with savings
- Average verified savings when reported
- Resolution type distribution
