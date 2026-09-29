-- ═══════════════════════════════════════════════════════════════════════════
--  BillFixer — reference seed data. Idempotent (upserts).
--  Run:  mysql -u billfixer -p billfixer < db/seed.sql        (or: npm run migrate:seed)
--  The data pipeline keeps these current automatically after deployment.
-- ═══════════════════════════════════════════════════════════════════════════
SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- 2026 HHS Poverty Guidelines, verified against the ASPE API.
-- us = 48 contiguous states + DC. Per-person increment: us $5,680 · ak $7,100 · hi $6,530.
INSERT INTO fpl_guidelines (year, region, household_size, amount, source_url, fetched_at) VALUES
  (2026, 'us', 1, 15960.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/us/1', UTC_TIMESTAMP()),
  (2026, 'us', 2, 21640.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/us/2', UTC_TIMESTAMP()),
  (2026, 'us', 3, 27320.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/us/3', UTC_TIMESTAMP()),
  (2026, 'us', 4, 33000.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/us/4', UTC_TIMESTAMP()),
  (2026, 'us', 5, 38680.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/us/5', UTC_TIMESTAMP()),
  (2026, 'us', 6, 44360.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/us/6', UTC_TIMESTAMP()),
  (2026, 'us', 7, 50040.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/us/7', UTC_TIMESTAMP()),
  (2026, 'us', 8, 55720.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/us/8', UTC_TIMESTAMP()),
  (2026, 'ak', 1, 19950.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/ak/1', UTC_TIMESTAMP()),
  (2026, 'ak', 2, 27050.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/ak/2', UTC_TIMESTAMP()),
  (2026, 'ak', 3, 34150.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/ak/3', UTC_TIMESTAMP()),
  (2026, 'ak', 4, 41250.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/ak/4', UTC_TIMESTAMP()),
  (2026, 'ak', 5, 48350.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/ak/5', UTC_TIMESTAMP()),
  (2026, 'ak', 6, 55450.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/ak/6', UTC_TIMESTAMP()),
  (2026, 'ak', 7, 62550.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/ak/7', UTC_TIMESTAMP()),
  (2026, 'ak', 8, 69650.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/ak/8', UTC_TIMESTAMP()),
  (2026, 'hi', 1, 18360.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/hi/1', UTC_TIMESTAMP()),
  (2026, 'hi', 2, 24890.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/hi/2', UTC_TIMESTAMP()),
  (2026, 'hi', 3, 31420.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/hi/3', UTC_TIMESTAMP()),
  (2026, 'hi', 4, 37950.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/hi/4', UTC_TIMESTAMP()),
  (2026, 'hi', 5, 44480.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/hi/5', UTC_TIMESTAMP()),
  (2026, 'hi', 6, 51010.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/hi/6', UTC_TIMESTAMP()),
  (2026, 'hi', 7, 57540.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/hi/7', UTC_TIMESTAMP()),
  (2026, 'hi', 8, 64070.00, 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/2026/hi/8', UTC_TIMESTAMP())
ON DUPLICATE KEY UPDATE amount = VALUES(amount), source_url = VALUES(source_url), fetched_at = VALUES(fetched_at);

-- Pipeline sources (the pipeline fills in etag / hashes / timestamps).
INSERT INTO data_sources (name, source_url, status) VALUES
  ('fpl',       'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api', 'never'),
  ('hospitals', 'https://data.cms.gov/provider-data/api/1/metastore/schemas/dataset/items/xubh-q36u', 'never'),
  ('mpfs',      'https://www.cms.gov/medicare/payment/fee-schedules/physician/pfs-relative-value-files', 'never'),
  ('mrf',       'hospital cms-hpt.txt files', 'never')
ON DUPLICATE KEY UPDATE source_url = VALUES(source_url);
