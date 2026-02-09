# Metabase Query Templates

Predefined SQL queries for Metabase dashboards. These complement the database views in `sql/schema.sql` — use whichever approach suits the dashboard layout.

---

## Dashboard: Strategy 2026

### Question 1: Strategic Overview

```sql
SELECT
    sb.code AS "Bet",
    sb.name AS "Name",
    COUNT(DISTINCT p.id) AS "Projects",
    COUNT(DISTINCT m.id) AS "Milestones",
    SUM(CASE WHEN p.status = 'complete' THEN 1 ELSE 0 END) AS "Complete",
    SUM(CASE WHEN p.status = 'on_track' THEN 1 ELSE 0 END) AS "On Track",
    SUM(CASE WHEN p.status IN ('at_risk', 'blocked') THEN 1 ELSE 0 END) AS "Needs Attention"
FROM strategic_bets sb
LEFT JOIN projects p ON p.strategic_bet_id = sb.id
LEFT JOIN milestones m ON m.project_id = p.id
GROUP BY sb.code, sb.name
ORDER BY sb.code;
```

### Question 2: All Projects

```sql
SELECT
    p.name AS "Project",
    sb.code AS "Bet",
    d.name AS "Team",
    p.status AS "Status",
    p.project_lead AS "Lead",
    fc_start.code AS "Start Cycle",
    fc_end.code AS "End Cycle"
FROM projects p
LEFT JOIN strategic_bets sb ON p.strategic_bet_id = sb.id
LEFT JOIN departments d ON p.owning_department_id = d.id
LEFT JOIN focus_cycles fc_start ON p.start_cycle_id = fc_start.id
LEFT JOIN focus_cycles fc_end ON p.end_cycle_id = fc_end.id
ORDER BY sb.code, p.status;
```

### Question 3: Roadmap — All Milestones

```sql
SELECT
    m.target_date AS "Due Date",
    m.name AS "Milestone",
    p.name AS "Project",
    sb.code AS "Bet",
    fc.code AS "Cycle",
    m.status AS "Status"
FROM milestones m
LEFT JOIN projects p ON m.project_id = p.id
LEFT JOIN strategic_bets sb ON p.strategic_bet_id = sb.id
LEFT JOIN focus_cycles fc ON m.focus_cycle_id = fc.id
WHERE m.status != 'cancelled'
ORDER BY m.target_date;
```

### Question 4: Roadmap — By Month (for charting)

```sql
SELECT
    TO_CHAR(m.target_date, 'YYYY-MM') AS "Month",
    sb.code AS "Bet",
    COUNT(*) AS "Milestones"
FROM milestones m
LEFT JOIN projects p ON m.project_id = p.id
LEFT JOIN strategic_bets sb ON p.strategic_bet_id = sb.id
WHERE m.status != 'cancelled'
GROUP BY TO_CHAR(m.target_date, 'YYYY-MM'), sb.code
ORDER BY "Month", sb.code;
```

### Question 5: Current Cycle — Due

```sql
SELECT
    m.name AS "Milestone",
    m.target_date AS "Due Date",
    p.name AS "Project",
    p.project_lead AS "Lead",
    m.status AS "Status"
FROM milestones m
LEFT JOIN projects p ON m.project_id = p.id
LEFT JOIN focus_cycles fc ON m.focus_cycle_id = fc.id
WHERE fc.start_date <= CURRENT_DATE
  AND fc.end_date >= CURRENT_DATE
  AND m.status != 'complete'
ORDER BY m.target_date;
```

### Question 6: Alerts — Needs Attention

```sql
SELECT
    p.name AS "Project",
    p.status AS "Status",
    p.project_lead AS "Lead",
    sb.code AS "Bet",
    d.name AS "Team"
FROM projects p
LEFT JOIN strategic_bets sb ON p.strategic_bet_id = sb.id
LEFT JOIN departments d ON p.owning_department_id = d.id
WHERE p.status IN ('at_risk', 'blocked')
ORDER BY p.status, sb.code;
```

### Question 7: Progress Summary

```sql
SELECT
    'Projects' AS "Type",
    COUNT(*) AS "Total",
    SUM(CASE WHEN status = 'complete' THEN 1 ELSE 0 END) AS "Complete",
    ROUND(100.0 * SUM(CASE WHEN status = 'complete' THEN 1 ELSE 0 END) / COUNT(*), 1) AS "% Done"
FROM projects
UNION ALL
SELECT
    'Milestones' AS "Type",
    COUNT(*) AS "Total",
    SUM(CASE WHEN status = 'complete' THEN 1 ELSE 0 END) AS "Complete",
    ROUND(100.0 * SUM(CASE WHEN status = 'complete' THEN 1 ELSE 0 END) / COUNT(*), 1) AS "% Done"
FROM milestones;
```

### Question 8: Upcoming Projects (Pipeline)

```sql
SELECT
    p.name AS "Project",
    sc.code AS "Start Cycle",
    ec.code AS "End Cycle",
    p.status AS "Status"
FROM projects p
LEFT JOIN focus_cycles sc ON p.start_cycle_id = sc.id
LEFT JOIN focus_cycles ec ON p.end_cycle_id = ec.id
WHERE p.strategic_bet_id IS NULL
ORDER BY p.name;
```

---

## Dashboard: Focus Cycle View

### Question 1: Cycle Overview

```sql
SELECT
    fc.code AS "Cycle",
    fc.name AS "Name",
    fc.start_date AS "Start",
    fc.end_date AS "End",
    CASE
        WHEN CURRENT_DATE < fc.start_date THEN 'Upcoming'
        WHEN CURRENT_DATE > fc.end_date THEN 'Complete'
        ELSE 'Active'
    END AS "Status"
FROM focus_cycles fc
ORDER BY fc.start_date;
```

### Question 2: Milestones by Cycle (with optional filter)

```sql
SELECT
    m.name AS "Milestone",
    p.name AS "Project",
    sb.code AS "Bet",
    m.target_date AS "Due",
    m.status AS "Status"
FROM milestones m
LEFT JOIN projects p ON m.project_id = p.id
LEFT JOIN strategic_bets sb ON p.strategic_bet_id = sb.id
LEFT JOIN focus_cycles fc ON m.focus_cycle_id = fc.id
[[WHERE fc.code = {{cycle}}]]
ORDER BY m.target_date;
```

### Question 3: Projects Active in Cycle (with optional filter)

```sql
SELECT
    p.name AS "Project",
    sb.code AS "Bet",
    p.project_lead AS "Lead",
    p.status AS "Status",
    sc.code AS "Start Cycle",
    ec.code AS "End Cycle"
FROM projects p
LEFT JOIN strategic_bets sb ON p.strategic_bet_id = sb.id
LEFT JOIN focus_cycles sc ON p.start_cycle_id = sc.id
LEFT JOIN focus_cycles ec ON p.end_cycle_id = ec.id
[[WHERE sc.code <= {{cycle}}
  AND (ec.code >= {{cycle}} OR ec.code IS NULL)]]
ORDER BY sb.code, p.name;
```

### Question 4: Cycle Progress (with optional filter)

```sql
SELECT
    COUNT(*) AS "Total Milestones",
    SUM(CASE WHEN m.status = 'complete' THEN 1 ELSE 0 END) AS "Complete",
    SUM(CASE WHEN m.status = 'in_progress' THEN 1 ELSE 0 END) AS "In Progress",
    SUM(CASE WHEN m.status IN ('at_risk', 'blocked') THEN 1 ELSE 0 END) AS "Needs Attention"
FROM milestones m
LEFT JOIN focus_cycles fc ON m.focus_cycle_id = fc.id
[[WHERE fc.code = {{cycle}}]];
```

---

## Utility Queries

### Check table columns

```sql
SELECT column_name FROM information_schema.columns WHERE table_name = 'projects';
SELECT column_name FROM information_schema.columns WHERE table_name = 'milestones';
```

### Check project cycle assignments

```sql
SELECT p.name AS "Project", p.start_cycle_id, p.end_cycle_id FROM projects p;
```

### Verify Metabase persistence

```sql
SELECT datname FROM pg_database WHERE datname = 'metabase_app';
```
