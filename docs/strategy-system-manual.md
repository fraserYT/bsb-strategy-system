# BsB Strategy System — User Manual

**Version:** 1.1
**Date:** 23 February 2026

---

## 1. What This System Does

The BsB Strategy System tracks our annual strategic plan from initiative level down to individual milestones. It connects Asana (where work is managed) to a reporting database, providing real-time dashboards that show progress, risks, and team workload without anyone needing to compile a manual report.

**In short:** You continue working in Asana as normal. The system automatically pulls your project and milestone data into dashboards that give leadership a live view of the whole strategy.

---

## 2. How It All Fits Together

```
┌──────────────────────────────────────────────────────┐
│              ASANA (Source of Truth)                  │
│  You manage projects, milestones, and tasks here.    │
│  Portfolios → Projects → Milestones → Subtasks       │
└─────────────────────┬────────────────────────────────┘
                      │  Automatic sync via Make.com
                      ▼
┌──────────────────────────────────────────────────────┐
│            POSTGRESQL (Central Data Hub)              │
│  Stores a structured copy of your Asana data.        │
│  Hosted on Sevalla.                                  │
└─────────────────────┬────────────────────────────────┘
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
┌──────────────────┐   ┌─────────────────────┐
│    METABASE      │   │      SLACK           │
│  (Dashboards)    │   │   (Notifications)    │
│  Hosted on       │   │   (Planned)          │
│  Sevalla         │   │                      │
└──────────────────┘   └─────────────────────┘
```

**What each tool does:**

| Tool | Role | Who Uses It |
|------|------|-------------|
| **Asana** | Day-to-day project and task management. This is where you work. | Everyone |
| **Make.com** | Automated sync. Runs in the background — you don't need to touch it. | Admin only |
| **PostgreSQL** | Stores reporting data. You never interact with it directly. | Admin only |
| **Metabase** | Dashboards. Where you go to see how the strategy is progressing. | Everyone (read-only) |
| **Slack** | Future: notifications and daily check-ins. | Everyone |

---

## 3. Strategic Framework

### 3.1 Initiatives (B1–B5)

Our strategy is organised around five initiatives. Every project in the system belongs to one of these (or sits in the intake pipeline awaiting assignment).

| Code | Initiative | Description |
|------|-----------|-------------|
| **B1** | Build Mentor Machine | Building out our mentoring content and delivery capability |
| **B2** | Standardise Sales and Marketing Processes | Creating repeatable, documented processes across sales and marketing |
| **B3** | Automate Key Processes | Reducing manual work through automation |
| **B4** | Optimise Subscriber Growth Engine | Improving how we attract, convert, and retain subscribers |
| **B5** | Rebrand to reflect who we are now | Updating our brand identity to match our current mission and offering |

### 3.2 Strategic Bet Tags

In addition to belonging to an initiative, individual milestones can be tagged with one or more cross-cutting strategic bets. These represent the four underlying principles that cut across all initiatives:

| Tag |
|-----|
| Video-Led Mentor Content |
| Informed Standardisation |
| Capacity through Automation |
| Owned Audience over SEO |

A milestone in the B1 initiative could be tagged "Video-Led Mentor Content" and "Owned Audience over SEO" simultaneously. This allows us to see progress against these themes across the whole strategy, not just within a single initiative.

### 3.3 Focus Cycles (FC1–FC6)

The year is divided into six eight-week focus cycles. These act as our sprint rhythm — each project and milestone is assigned to one or more cycles.

| Cycle | Dates |
|-------|-------|
| FC1 | 23 Feb – 5 Apr 2026 |
| FC2 | 13 Apr – 24 May 2026 |
| FC3 | 1 Jun – 12 Jul 2026 |
| FC4 | 20 Jul – 30 Aug 2026 |
| FC5 | 7 Sep – 18 Oct 2026 |
| FC6 | 26 Oct – 6 Dec 2026 |

Note the gap weeks between cycles — these are intentional buffer/planning periods.

### 3.4 Departments

| Code | Department |
|------|-----------|
| PROD | Production |
| EDIT | Editorial |
| DEV | Development |
| INFRA | Infrastructure |
| WFS | Workflow Support |
| MKT | Marketing |
| SAL | Sales |
| BOARD | Board |
| STRAT | Strategy |
| DES | Design |

Each project has a single owning department. This keeps accountability clear.

---

## 4. How Asana Is Structured

### 4.1 Portfolio Hierarchy

```
📁 🎯 BsB Strategy 2026              (top-level portfolio)
├── 📁 🧩 Build Mentor Machine (B1)
├── 📁 🧩 Standardise Sales and Marketing Processes (B2)
├── 📁 🧩 Automate Key Processes (B3)
├── 📁 🧩 Optimise Subscriber Growth Engine (B4)
├── 📁 🧩 Rebrand to reflect who we are now (B5)
└── 📋 📥 Upcoming Projects              (intake pipeline)
```

Each initiative portfolio contains the projects that belong to it. The "Upcoming Projects" list holds proposals and ideas that haven't been assigned to an initiative yet.

### 4.2 Inside a Project

```
📋 Project Name
├── ◆ Milestone 1 (native Asana milestone)
│   ├── Subtask: Work item A
│   └── Subtask: Work item B
├── ◆ Milestone 2
│   └── Subtasks...
└── ◆ Milestone 3
    └── Subtasks...
```

**Key points:**
- Milestones are native Asana milestones (not regular tasks). They appear on timelines and have due dates.
- Subtasks sit under milestones. These are your day-to-day work items.
- Completing all subtasks under a milestone means the milestone is done.

### 4.3 Custom Fields You'll See

**On projects (portfolio level):**

| Field | What It Means |
|-------|--------------|
| **Teams** | Which department owns this project |
| **Start Cycle** | Which focus cycle this project begins |
| **End Cycle** | Which focus cycle this project should be complete by |
| **Project Type** | "Standard Project" or "Strategy Milestones" |
| **Status** | Uses Asana's native status: On Track, At Risk, Off Track, On Hold, Complete |
| **Owner** | Uses Asana's native project owner field — this is the project lead |

**On milestones (task level):**

| Field | What It Means |
|-------|--------------|
| **Focus Cycle** | Which cycle this milestone is targeted for (FC1–FC6) |
| **Strategic Bet** | Multi-select: which strategic bet tags this milestone contributes to |

### 4.4 What You Need to Do in Asana

For the system to work correctly:

1. **Set the project custom fields** when a project is created (Teams, Start Cycle, End Cycle, Project Type)
2. **Keep project status up to date** using Asana's native status updates
3. **Create milestones as native Asana milestones** (not regular tasks)
4. **Set the Focus Cycle field** on each milestone
5. **Optionally tag milestones** with Strategic Bet tags if they contribute to one of the four cross-cutting themes
6. **Break milestones into subtasks** for the actual work items
7. **Mark milestones complete** when all work is done

Everything else is automatic.

---

## 5. Project Statuses

Projects move through these statuses:

| Status | Meaning |
|--------|---------|
| **Not Started** | Project is planned but work hasn't begun |
| **On Track** | Work is progressing as expected |
| **At Risk** | Something is threatening the timeline or deliverables |
| **Blocked** | Work cannot continue until an issue is resolved |
| **On Hold** | Deliberately paused |
| **Complete** | All milestones delivered |
| **Cancelled** | Project abandoned (excluded from reports) |

Update your project status in Asana using the native status feature. The sync picks it up automatically.

---

## 6. Metabase Dashboards

### 6.1 Accessing Metabase

Metabase is hosted on Sevalla. You'll receive a login from your admin. It's read-only for most users — you view dashboards but don't edit them.

### 6.2 Strategy 2026 Dashboard

This is the main dashboard with 15 views:

| View | What It Shows |
|------|--------------|
| **Strategic Overview** | Summary table: how many projects per initiative, how many are on track vs needing attention |
| **All Projects** | Full list of every project with initiative, team, status, lead, and cycle range |
| **All Milestones** | Every milestone across all projects, with due dates, status, and strategic bet tags |
| **Alerts — Needs Attention** | Projects that are At Risk or Blocked — these need action |
| **Current Cycle Due** | Milestones due in the active focus cycle that aren't yet complete |
| **Roadmap by Month** | How milestones are distributed across the year, broken down by initiative |
| **Progress Summary** | Overall completion rates for projects and milestones |
| **Focus Cycles 2026** | Calendar of all six focus cycles with their status |
| **Upcoming Projects (Pipeline)** | Projects not yet assigned to an initiative |
| **Milestones by Focus Cycle** | Filter by cycle to see what's planned, with optional cycle selector |
| **Projects Alive in Cycle** | Which projects are active during a given cycle |
| **Cycle Progress** | Completion stats for a specific cycle |
| **Projects by Status** | All assigned projects grouped by their current status |
| **Milestones by Strategic Bet Tag** | Cross-initiative view: which milestones contribute to each strategic bet, regardless of which initiative they belong to |
| **Milestone Timeline** | Full-year scatter of all milestones, clustered by focus cycle |

### 6.3 Using Filters

Some views have an optional **cycle filter** (e.g. type "FC2" to see only that cycle's data). Look for the filter bar at the top of the dashboard.

---

## 7. The Sync — How Data Flows

You don't need to understand this in detail, but it helps to know what's happening:

1. **Make.com runs on a schedule** (or can be triggered manually)
2. It calls the **Asana API** to fetch all projects from each initiative portfolio
3. For each project, it extracts the name, owner, status, team, cycle range, and type
4. It writes this into **PostgreSQL** using an upsert function (creates new records, updates existing ones)
5. It then fetches all **milestones** within each project
6. For each milestone, it extracts the name, due date, completion status, focus cycle, and strategic bet tags
7. It writes these into PostgreSQL the same way
8. **Metabase** reads from PostgreSQL in real time — dashboards always show the latest synced data

**Important:** Asana is the source of truth. If something looks wrong in Metabase, check Asana first. If Asana is correct but Metabase is wrong, the sync may need to be re-run.

**Note on strategic bet tags:** The milestone sync now supports the Strategic Bet multi-select field. Once the Make.com milestone modules are updated with the 7th parameter, bet tags will sync automatically alongside all other milestone data.

---

## 8. Daily Check-in System (Planned)

A daily mood and busyness check-in is designed and ready for deployment. Here's how it will work:

1. Each weekday at 09:30, a message appears in Slack with a **"Check In"** button
2. Clicking the button opens a short form asking two questions:
   - **How are you feeling today?** (1–10 scale)
   - **How busy are you?** (1–10 scale)
3. Your response is **completely anonymous** — only the ratings are stored, never your identity
4. Results appear on a Metabase dashboard showing team mood and busyness trends over time
5. To protect anonymity on small teams, daily results only display when 3 or more people have responded

A separate **Fun Question of the Day** will also post daily in Slack, managed through Google Sheets and Slack Workflows.

---

## 9. Glossary

| Term | Meaning |
|------|---------|
| **Initiative** | One of the five strategic themes (B1–B5) |
| **Strategic Bet Tag** | A cross-cutting theme that can be applied to milestones across any initiative |
| **Focus Cycle** | An eight-week work period (FC1–FC6) |
| **Milestone** | A key deliverable within a project, with a target date and cycle assignment |
| **Pipeline / Upcoming** | Projects proposed but not yet assigned to an initiative |
| **Upsert** | The sync process that creates new records or updates existing ones |
| **Sevalla** | Our hosting platform for the database and Metabase |

---

## 10. FAQ

**Q: Do I need to do anything differently in Asana?**
A: Fill in the custom fields (Teams, Start/End Cycle, Project Type) on projects, and the Focus Cycle field on milestones. Keep project statuses current. That's it.

**Q: How often does the data update?**
A: When Make.com runs the sync. This can be scheduled (e.g. every few hours) or triggered manually by an admin.

**Q: I see wrong data in Metabase — what do I do?**
A: First check that the data is correct in Asana. If it is, ask your admin to re-run the sync.

**Q: Can I edit data in Metabase?**
A: No. Metabase is read-only. All changes are made in Asana and flow through automatically.

**Q: What happens if I don't fill in the custom fields?**
A: The project or milestone will still sync, but it won't appear correctly in filtered views. For example, a milestone without a Focus Cycle won't show up in cycle-specific views.

**Q: Is the daily check-in really anonymous?**
A: Yes. The system deliberately does not store your Slack user ID. Only the date and the two rating numbers are saved.

---

## 11. Key Contacts

For questions about the system, dashboards, or anything that looks broken, contact your strategy system admin.