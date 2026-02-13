-- BsB Strategy Planning System
-- Daily Check-in Schema (Mood & Busyness tracking)
-- Last updated: 2026-02-12

-- ============================================
-- TABLES
-- ============================================

-- Anonymous mood/busyness responses (NO user identifier)
CREATE TABLE checkin_responses (
    id SERIAL PRIMARY KEY,
    response_date DATE NOT NULL DEFAULT CURRENT_DATE,
    mood_rating SMALLINT NOT NULL CHECK (mood_rating BETWEEN 1 AND 10),
    busyness_rating SMALLINT NOT NULL CHECK (busyness_rating BETWEEN 1 AND 10),
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_checkin_date ON checkin_responses(response_date);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Insert an anonymous check-in response
CREATE OR REPLACE FUNCTION insert_checkin(
    p_mood SMALLINT,
    p_busyness SMALLINT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO checkin_responses (response_date, mood_rating, busyness_rating)
    VALUES (CURRENT_DATE, p_mood, p_busyness);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- VIEWS
-- ============================================

-- Daily aggregates
CREATE VIEW v_checkin_daily AS
SELECT
    response_date,
    COUNT(*) as response_count,
    ROUND(AVG(mood_rating), 1) as avg_mood,
    ROUND(AVG(busyness_rating), 1) as avg_busyness,
    MIN(mood_rating) as min_mood,
    MAX(mood_rating) as max_mood,
    MIN(busyness_rating) as min_busyness,
    MAX(busyness_rating) as max_busyness
FROM checkin_responses
GROUP BY response_date
ORDER BY response_date DESC;

-- Weekly aggregates (ISO week)
CREATE VIEW v_checkin_weekly AS
SELECT
    DATE_TRUNC('week', response_date)::DATE as week_start,
    COUNT(*) as response_count,
    ROUND(AVG(mood_rating), 1) as avg_mood,
    ROUND(AVG(busyness_rating), 1) as avg_busyness
FROM checkin_responses
GROUP BY DATE_TRUNC('week', response_date)
ORDER BY week_start DESC;

-- Aggregates by focus cycle
CREATE VIEW v_checkin_by_cycle AS
SELECT
    fc.code as cycle_code,
    fc.name as cycle_name,
    COUNT(cr.id) as response_count,
    ROUND(AVG(cr.mood_rating), 1) as avg_mood,
    ROUND(AVG(cr.busyness_rating), 1) as avg_busyness
FROM focus_cycles fc
LEFT JOIN checkin_responses cr
    ON cr.response_date BETWEEN fc.start_date AND fc.end_date
GROUP BY fc.id, fc.code, fc.name, fc.start_date
ORDER BY fc.start_date;
