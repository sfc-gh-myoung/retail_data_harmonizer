-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/05_seed_data/05g_events.sql
-- Purpose: Seed EVENTS table with realistic 2025/2026 venue events
-- Depends on: 03_event_views.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- EVENTS: 103 Events across 5 venues (Q4 2025 - Q3 2026)
-- Matches every EVENT_ID referenced in raw retail item seed files (04k-04o)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.EVENTS (EVENT_ID, EVENT_NAME, VENUE_CODE, EVENT_TYPE, EVENT_DATE, EXPECTED_ATTENDANCE, ACTUAL_ATTENDANCE)
SELECT * FROM VALUES
    -- ========================================================================
    -- POS_STADIUM: 35 Events - NFL Games, Concerts, Festivals, Sports
    -- ========================================================================
    ('EVT-STD-001', 'NFL Week 14: Home vs Divisional Rival', 'POS_STADIUM', 'GAME', '2025-12-07', 68000, 71234),
    ('EVT-STD-002', 'NFL Week 16: Christmas Eve Game', 'POS_STADIUM', 'GAME', '2025-12-24', 70000, 72156),
    ('EVT-STD-003', 'NFL Wildcard Playoff', 'POS_STADIUM', 'GAME', '2026-01-11', 72000, 72500),
    ('EVT-STD-004', 'College Bowl Game', 'POS_STADIUM', 'GAME', '2025-12-28', 55000, 52890),
    ('EVT-STD-005', 'Monster Truck Rally', 'POS_STADIUM', 'FESTIVAL', '2026-02-15', 35000, 38420),
    ('EVT-STD-006', 'NFL Divisional Playoff', 'POS_STADIUM', 'GAME', '2026-01-18', 72000, 72800),
    ('EVT-STD-007', 'NHL Winter Classic', 'POS_STADIUM', 'GAME', '2026-01-25', 65000, 68450),
    ('EVT-STD-008', 'Soccer International Friendly', 'POS_STADIUM', 'GAME', '2026-02-08', 52000, 55230),
    ('EVT-STD-009', 'NFL Pro Bowl Weekend', 'POS_STADIUM', 'GAME', '2026-02-01', 48000, 45670),
    ('EVT-STD-010', 'Spring Concert Series', 'POS_STADIUM', 'CONCERT', '2026-03-07', 45000, 42300),
    ('EVT-STD-011', 'NBA All-Star Weekend', 'POS_STADIUM', 'GAME', '2026-02-22', 60000, 61500),
    ('EVT-STD-012', 'UFC Fight Night', 'POS_STADIUM', 'GAME', '2026-03-14', 50000, 48200),
    ('EVT-STD-013', 'Motocross Championship', 'POS_STADIUM', 'FESTIVAL', '2026-03-21', 42000, 40150),
    ('EVT-STD-014', 'Spring Football Scrimmage', 'POS_STADIUM', 'GAME', '2026-04-04', 38000, 35800),
    ('EVT-STD-015', 'College Lacrosse Championship', 'POS_STADIUM', 'GAME', '2026-04-18', 35000, 33200),
    ('EVT-STD-016', 'Rugby Sevens Tournament', 'POS_STADIUM', 'GAME', '2026-04-25', 50000, 47800),
    ('EVT-STD-017', 'MLS Opening Day', 'POS_STADIUM', 'GAME', '2026-05-02', 55000, 52100),
    ('EVT-STD-018', 'Country Music Festival', 'POS_STADIUM', 'CONCERT', '2026-05-16', 60000, 58900),
    ('EVT-STD-019', 'College Graduation Ceremony', 'POS_STADIUM', 'FESTIVAL', '2026-05-23', 30000, 28400),
    ('EVT-STD-020', 'NFL Preseason Week 1', 'POS_STADIUM', 'GAME', '2026-08-08', 58000, 54600),
    ('EVT-STD-021', 'Summer Music & Arts Festival', 'POS_STADIUM', 'CONCERT', '2026-06-13', 65000, 62000),
    ('EVT-STD-022', 'Summer Track & Field Championships', 'POS_STADIUM', 'GAME', '2026-06-27', 40000, 38500),
    ('EVT-STD-023', 'Independence Day Celebration', 'POS_STADIUM', 'FESTIVAL', '2026-07-04', 70000, 67200),
    ('EVT-STD-024', 'International Soccer Tournament', 'POS_STADIUM', 'GAME', '2026-07-18', 66000, 64300),
    ('EVT-STD-025', 'NFL Season Opener', 'POS_STADIUM', 'GAME', '2026-09-13', 72000, 73100),
    ('EVT-STD-026', 'NFL Playoff Game', 'POS_STADIUM', 'GAME', '2026-01-10', 72000, 72500),
    ('EVT-STD-027', 'College Bowl Game', 'POS_STADIUM', 'GAME', '2026-01-17', 58000, 55800),
    ('EVT-STD-028', 'Soccer International Friendly', 'POS_STADIUM', 'GAME', '2026-02-21', 50000, 48200),
    ('EVT-STD-029', 'Rugby Match', 'POS_STADIUM', 'GAME', '2026-02-28', 44000, 42100),
    ('EVT-STD-030', 'Monster Jam', 'POS_STADIUM', 'FESTIVAL', '2026-03-07', 60000, 58500),
    ('EVT-STD-031', 'Motocross Championship', 'POS_STADIUM', 'FESTIVAL', '2026-03-14', 48000, 45300),
    ('EVT-STD-032', 'Spring Football Scrimmage', 'POS_STADIUM', 'GAME', '2026-03-21', 38000, 35200),
    ('EVT-STD-033', 'Lacrosse Championship', 'POS_STADIUM', 'GAME', '2026-03-28', 40000, 38900),
    ('EVT-STD-034', 'Track & Field Meet', 'POS_STADIUM', 'GAME', '2026-04-04', 30000, 28400),
    ('EVT-STD-035', 'MLS Season Opener', 'POS_STADIUM', 'GAME', '2026-04-11', 55000, 52100),

    -- ========================================================================
    -- POS_ARENA: 25 Events - NBA, NHL, Concerts, Family Shows
    -- ========================================================================
    ('EVT-ARN-001', 'NBA Regular Season: vs Lakers', 'POS_ARENA', 'GAME', '2025-12-12', 19500, 19832),
    ('EVT-ARN-002', 'NHL Regular Season: vs Rivals', 'POS_ARENA', 'GAME', '2025-12-14', 18000, 17650),
    ('EVT-ARN-003', 'Taylor Swift Eras Tour', 'POS_ARENA', 'CONCERT', '2026-01-18', 21000, 21000),
    ('EVT-ARN-004', 'NBA All-Star Weekend Fan Fest', 'POS_ARENA', 'FESTIVAL', '2026-02-14', 20000, 19456),
    ('EVT-ARN-005', 'WWE Live Event', 'POS_ARENA', 'FESTIVAL', '2026-01-25', 16000, 15234),
    ('EVT-ARN-006', 'NBA Regular Season: vs Celtics', 'POS_ARENA', 'GAME', '2025-11-08', 19500, 19100),
    ('EVT-ARN-007', 'NHL Playoff Game', 'POS_ARENA', 'GAME', '2025-11-15', 18000, 18500),
    ('EVT-ARN-008', 'Country Music Festival Night', 'POS_ARENA', 'CONCERT', '2025-11-22', 20000, 20200),
    ('EVT-ARN-009', 'Disney on Ice', 'POS_ARENA', 'FESTIVAL', '2025-12-06', 17000, 16800),
    ('EVT-ARN-010', 'NBA Regular Season: vs Warriors', 'POS_ARENA', 'GAME', '2025-12-20', 19500, 19832),
    ('EVT-ARN-011', 'Cirque du Soleil', 'POS_ARENA', 'CONCERT', '2025-12-28', 15000, 14500),
    ('EVT-ARN-012', 'UFC Fight Night', 'POS_ARENA', 'GAME', '2026-01-10', 17500, 17200),
    ('EVT-ARN-013', 'NBA MLK Day Game', 'POS_ARENA', 'GAME', '2026-01-19', 19500, 19500),
    ('EVT-ARN-014', 'Harlem Globetrotters', 'POS_ARENA', 'FESTIVAL', '2026-02-01', 14000, 13800),
    ('EVT-ARN-015', 'NHL Heritage Classic', 'POS_ARENA', 'GAME', '2026-02-22', 18500, 18900),
    ('EVT-ARN-016', 'NBA Rivalry Game: vs Knicks', 'POS_ARENA', 'GAME', '2026-02-28', 19800, 19900),
    ('EVT-ARN-017', 'Electronic Music Festival', 'POS_ARENA', 'CONCERT', '2026-03-07', 20000, 20500),
    ('EVT-ARN-018', 'NHL Regular Season', 'POS_ARENA', 'GAME', '2026-01-03', 17500, 17400),
    ('EVT-ARN-019', 'Monster Truck Rally', 'POS_ARENA', 'FESTIVAL', '2026-01-31', 16500, 16200),
    ('EVT-ARN-020', 'NBA Fan Appreciation Night', 'POS_ARENA', 'GAME', '2026-03-14', 19500, 19832),
    ('EVT-ARN-021', 'NHL Hockey Game', 'POS_ARENA', 'GAME', '2026-01-18', 18000, 18200),
    ('EVT-ARN-022', 'Monster Truck Rally', 'POS_ARENA', 'FESTIVAL', '2026-01-25', 17000, 16800),
    ('EVT-ARN-023', 'WWE Wrestling Event', 'POS_ARENA', 'FESTIVAL', '2026-02-01', 17500, 17500),
    ('EVT-ARN-024', 'Disney on Ice', 'POS_ARENA', 'FESTIVAL', '2026-02-08', 17000, 17100),
    ('EVT-ARN-025', 'Circus Performance', 'POS_ARENA', 'FESTIVAL', '2026-02-15', 14500, 14200),

    -- ========================================================================
    -- POS_HOSPITAL: 15 Events - Weekly Cafeteria Service Periods
    -- ========================================================================
    ('EVT-HSP-001', 'Hospital Cafeteria Week 50', 'POS_HOSPITAL', 'DAILY_SERVICE', '2025-12-09', 8500, 8234),
    ('EVT-HSP-002', 'Hospital Cafeteria Week 51', 'POS_HOSPITAL', 'DAILY_SERVICE', '2025-12-16', 8000, 7650),
    ('EVT-HSP-003', 'Hospital Cafeteria Week 52 Holiday', 'POS_HOSPITAL', 'DAILY_SERVICE', '2025-12-23', 6000, 5890),
    ('EVT-HSP-004', 'Hospital Cafeteria Week 1 2026', 'POS_HOSPITAL', 'DAILY_SERVICE', '2026-01-06', 8500, 8756),
    ('EVT-HSP-005', 'Hospital Cafeteria Week 2 2026', 'POS_HOSPITAL', 'DAILY_SERVICE', '2026-01-13', 8500, 8432),
    ('EVT-HSP-006', 'Hospital Cafeteria Week 3 2026', 'POS_HOSPITAL', 'DAILY_SERVICE', '2026-01-20', 8500, 8567),
    ('EVT-HSP-007', 'Hospital Cafeteria Week 4 2026', 'POS_HOSPITAL', 'DAILY_SERVICE', '2026-01-27', 8000, 7890),
    ('EVT-HSP-008', 'Hospital Cafeteria Week 5 2026', 'POS_HOSPITAL', 'DAILY_SERVICE', '2026-02-03', 8500, 8123),
    ('EVT-HSP-009', 'Hospital Cafeteria Week 6 2026', 'POS_HOSPITAL', 'DAILY_SERVICE', '2026-02-10', 8500, 8345),
    ('EVT-HSP-010', 'Hospital Cafeteria Week 7 2026', 'POS_HOSPITAL', 'DAILY_SERVICE', '2026-02-17', 8500, 8678),
    ('EVT-HSP-011', 'Hospital Cafeteria Week 8 2026', 'POS_HOSPITAL', 'DAILY_SERVICE', '2026-02-24', 8000, 7950),
    ('EVT-HSP-012', 'Hospital Cafeteria Week 9 2026', 'POS_HOSPITAL', 'DAILY_SERVICE', '2026-03-03', 8500, 8234),
    ('EVT-HSP-013', 'Hospital Cafeteria Week 10 2026', 'POS_HOSPITAL', 'DAILY_SERVICE', '2026-03-10', 8500, 8456),
    ('EVT-HSP-014', 'Hospital Cafeteria Week 11 2026', 'POS_HOSPITAL', 'DAILY_SERVICE', '2026-03-17', 8500, 8890),
    ('EVT-HSP-015', 'Hospital Cafeteria Week 12 2026', 'POS_HOSPITAL', 'DAILY_SERVICE', '2026-03-24', 8500, 8312),

    -- ========================================================================
    -- POS_UNIVERSITY: 15 Events - Campus Dining Periods
    -- ========================================================================
    ('EVT-UNI-001', 'Finals Week Fall 2025', 'POS_UNIVERSITY', 'DAILY_SERVICE', '2025-12-08', 25000, 27890),
    ('EVT-UNI-002', 'Winter Break Reduced Service', 'POS_UNIVERSITY', 'DAILY_SERVICE', '2025-12-22', 5000, 4320),
    ('EVT-UNI-003', 'Spring Semester Week 1', 'POS_UNIVERSITY', 'DAILY_SERVICE', '2026-01-13', 30000, 31245),
    ('EVT-UNI-004', 'Spring Semester Week 2', 'POS_UNIVERSITY', 'DAILY_SERVICE', '2026-01-20', 32000, 32156),
    ('EVT-UNI-005', 'Super Bowl Watch Party', 'POS_UNIVERSITY', 'FESTIVAL', '2026-02-08', 8000, 9234),
    ('EVT-UNI-006', 'Spring Semester Week 3', 'POS_UNIVERSITY', 'DAILY_SERVICE', '2026-01-27', 30000, 30456),
    ('EVT-UNI-007', 'Spring Semester Week 4', 'POS_UNIVERSITY', 'DAILY_SERVICE', '2026-02-03', 32000, 31890),
    ('EVT-UNI-008', 'Valentines Week', 'POS_UNIVERSITY', 'DAILY_SERVICE', '2026-02-10', 30000, 29345),
    ('EVT-UNI-009', 'Spring Semester Week 6', 'POS_UNIVERSITY', 'DAILY_SERVICE', '2026-02-17', 30000, 30123),
    ('EVT-UNI-010', 'Spring Break Reduced', 'POS_UNIVERSITY', 'DAILY_SERVICE', '2026-03-02', 6000, 5678),
    ('EVT-UNI-011', 'Post-Spring Break Week', 'POS_UNIVERSITY', 'DAILY_SERVICE', '2026-03-16', 33000, 33456),
    ('EVT-UNI-012', 'Midterm Exam Week', 'POS_UNIVERSITY', 'DAILY_SERVICE', '2026-03-23', 34000, 34567),
    ('EVT-UNI-013', 'March Madness Week', 'POS_UNIVERSITY', 'FESTIVAL', '2026-03-30', 29000, 28900),
    ('EVT-UNI-014', 'April Regular Week', 'POS_UNIVERSITY', 'DAILY_SERVICE', '2026-04-06', 30000, 29678),
    ('EVT-UNI-015', 'Finals Week Spring 2026', 'POS_UNIVERSITY', 'DAILY_SERVICE', '2026-04-27', 35000, 35234),

    -- ========================================================================
    -- POS_CORPORATE: 13 Events - Corporate Campus Events
    -- ========================================================================
    ('EVT-CRP-001', 'Q4 All-Hands Meeting Catering', 'POS_CORPORATE', 'CORPORATE', '2025-12-05', 2500, 2456),
    ('EVT-CRP-002', 'Holiday Party 2025', 'POS_CORPORATE', 'CORPORATE', '2025-12-19', 3500, 3234),
    ('EVT-CRP-003', 'New Year Kickoff 2026', 'POS_CORPORATE', 'CORPORATE', '2026-01-08', 2000, 1987),
    ('EVT-CRP-004', 'Sales Conference Q1', 'POS_CORPORATE', 'CORPORATE', '2026-01-22', 4000, 4123),
    ('EVT-CRP-005', 'Tech Summit 2026', 'POS_CORPORATE', 'CORPORATE', '2026-02-12', 5000, 5456),
    ('EVT-CRP-006', 'Leadership Retreat Q1', 'POS_CORPORATE', 'CORPORATE', '2026-02-19', 900, 876),
    ('EVT-CRP-007', 'Product Launch Event', 'POS_CORPORATE', 'CORPORATE', '2026-03-05', 2500, 2345),
    ('EVT-CRP-008', 'Q1 Town Hall Meeting', 'POS_CORPORATE', 'CORPORATE', '2026-03-12', 3500, 3567),
    ('EVT-CRP-009', 'Customer Appreciation Day', 'POS_CORPORATE', 'CORPORATE', '2026-03-19', 1200, 1234),
    ('EVT-CRP-010', 'Engineering All-Hands', 'POS_CORPORATE', 'CORPORATE', '2026-04-02', 3000, 2876),
    ('EVT-CRP-011', 'Spring Sales Kickoff', 'POS_CORPORATE', 'CORPORATE', '2026-04-16', 4500, 4567),
    ('EVT-CRP-012', 'Board Meeting & Investor Day', 'POS_CORPORATE', 'CORPORATE', '2026-04-30', 700, 654),
    ('EVT-CRP-013', 'Summer Planning Summit', 'POS_CORPORATE', 'CORPORATE', '2026-05-14', 6000, 5890)

AS t(EVENT_ID, EVENT_NAME, VENUE_CODE, EVENT_TYPE, EVENT_DATE, EXPECTED_ATTENDANCE, ACTUAL_ATTENDANCE);

-- Verify event data: expect 103 total events
SELECT VENUE_CODE, COUNT(*) AS EVENTS, SUM(ACTUAL_ATTENDANCE) AS TOTAL_ATTENDANCE
FROM HARMONIZER_DEMO.RAW.EVENTS
GROUP BY VENUE_CODE
ORDER BY VENUE_CODE;
