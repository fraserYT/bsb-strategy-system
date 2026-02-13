# Daily Check-in System — Setup Guide

## Overview

Two separate but complementary daily Slack interactions:

1. **Mood & Busyness Check-in** — anonymous ratings stored in PostgreSQL, charted in Metabase. Built with Make.com + Slack interactivity.
2. **Fun Question of the Day** — social/team-building. Managed entirely via Google Sheet + Slack Workflow Builder ([based on this approach](https://aaronheth.medium.com/slack-hack-make-a-completely-automated-question-of-the-day-system-for-your-team-with-no-plugins-4dbdd26a0573)). No database involvement.

---

## Part A: Mood & Busyness Check-in

### A1. Slack App Configuration

Update **BsB Strategy Bot** at [api.slack.com/apps](https://api.slack.com/apps):

1. **Interactivity & Shortcuts** (left sidebar):
   - Toggle **Interactivity** to **On**
   - Set **Request URL** to your Make.com webhook URL (created in step A4)
   - Save Changes
2. **OAuth & Permissions** — verify these Bot Token Scopes exist:
   - `chat:write` (already have)
   - `chat:write.public` (already have)
   - No additional scopes needed
3. **Reinstall the app** to your workspace if you added any new scopes

### A2. Run the Database Schema

Run `sql/checkin-schema.sql` against your PostgreSQL database. This creates:

- `checkin_responses` — anonymous responses (no user ID column)
- `insert_checkin(p_mood, p_busyness)` — function to store a response
- Views: `v_checkin_daily`, `v_checkin_weekly`, `v_checkin_by_cycle`

After running, refresh the function list in Make.com (PostgreSQL module → reconnect or re-select the connection).

### A3. Make.com Scenario 1 — Daily Post

**Trigger:** Schedule → Every day at 09:30 (Mon–Fri)

#### Module 1: Slack — Create a Message (Block Kit)

- **Channel:** `#daily-checkin` (or your preferred channel)
- **Use Block Kit:** Yes
- **Blocks JSON:**

```json
[
  {
    "type": "header",
    "text": {
      "type": "plain_text",
      "text": "Daily Check-in"
    }
  },
  {
    "type": "section",
    "text": {
      "type": "mrkdwn",
      "text": "How are you doing today? Click below to share your mood and busyness — it's completely anonymous."
    }
  },
  {
    "type": "actions",
    "elements": [
      {
        "type": "button",
        "text": {
          "type": "plain_text",
          "text": "Check In"
        },
        "action_id": "open_checkin_modal",
        "style": "primary"
      }
    ]
  }
]
```

Save and activate with a Mon–Fri 09:30 schedule.

### A4. Make.com Scenario 2 — Response Handler (Webhook)

**Trigger:** Webhooks → Custom webhook

1. Create a new scenario with a **Custom webhook** trigger
2. Copy the webhook URL — this goes into the Slack app's **Request URL** (step A1)

#### Router setup

The webhook receives different payload types from Slack. Use a **Router** with three branches:

**Branch 1 — URL Verification** (runs once during setup):
- **Filter:** `type` equals `url_verification`
- **Module:** Webhook response → return JSON: `{"challenge": "{{1.challenge}}"}`

**Branch 2 — Button click → open modal:**
- **Filter:** `type` equals `block_actions`

**Branch 3 — Modal submission → store data:**
- **Filter:** `type` equals `view_submission`

#### Branch 2: Handle button click

When a user clicks "Check In", Slack sends a `block_actions` payload with a `trigger_id`.

**Module: Slack — Make an API Call**
- **Method:** POST
- **URL:** `views.open`
- **Body:**

```json
{
  "trigger_id": "{{1.trigger_id}}",
  "view": {
    "type": "modal",
    "callback_id": "checkin_submit",
    "title": {
      "type": "plain_text",
      "text": "Daily Check-in"
    },
    "submit": {
      "type": "plain_text",
      "text": "Submit"
    },
    "blocks": [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "Your ratings are *completely anonymous* — we only store the numbers, not who submitted them."
        }
      },
      {
        "type": "input",
        "block_id": "mood_block",
        "label": {
          "type": "plain_text",
          "text": "How are you feeling today?"
        },
        "element": {
          "type": "static_select",
          "action_id": "mood_rating",
          "placeholder": {
            "type": "plain_text",
            "text": "Select 1-10"
          },
          "options": [
            {"text": {"type": "plain_text", "text": "1 - Awful"}, "value": "1"},
            {"text": {"type": "plain_text", "text": "2"}, "value": "2"},
            {"text": {"type": "plain_text", "text": "3"}, "value": "3"},
            {"text": {"type": "plain_text", "text": "4"}, "value": "4"},
            {"text": {"type": "plain_text", "text": "5 - Okay"}, "value": "5"},
            {"text": {"type": "plain_text", "text": "6"}, "value": "6"},
            {"text": {"type": "plain_text", "text": "7"}, "value": "7"},
            {"text": {"type": "plain_text", "text": "8"}, "value": "8"},
            {"text": {"type": "plain_text", "text": "9"}, "value": "9"},
            {"text": {"type": "plain_text", "text": "10 - Amazing"}, "value": "10"}
          ]
        }
      },
      {
        "type": "input",
        "block_id": "busyness_block",
        "label": {
          "type": "plain_text",
          "text": "How busy are you?"
        },
        "element": {
          "type": "static_select",
          "action_id": "busyness_rating",
          "placeholder": {
            "type": "plain_text",
            "text": "Select 1-10"
          },
          "options": [
            {"text": {"type": "plain_text", "text": "1 - Nothing on"}, "value": "1"},
            {"text": {"type": "plain_text", "text": "2"}, "value": "2"},
            {"text": {"type": "plain_text", "text": "3"}, "value": "3"},
            {"text": {"type": "plain_text", "text": "4"}, "value": "4"},
            {"text": {"type": "plain_text", "text": "5 - Manageable"}, "value": "5"},
            {"text": {"type": "plain_text", "text": "6"}, "value": "6"},
            {"text": {"type": "plain_text", "text": "7"}, "value": "7"},
            {"text": {"type": "plain_text", "text": "8"}, "value": "8"},
            {"text": {"type": "plain_text", "text": "9"}, "value": "9"},
            {"text": {"type": "plain_text", "text": "10 - Swamped"}, "value": "10"}
          ]
        }
      }
    ]
  }
}
```

> **Note:** The `trigger_id` comes from the Slack payload and is only valid for 3 seconds, so this module must run immediately after the webhook trigger.

**After the Slack API call, add:** Webhook response → return `{}` with status 200.

#### Branch 3: Handle modal submission

When the user submits the modal, Slack sends a `view_submission` payload.

**Module 3a: PostgreSQL — Execute a function**
- **Function:** `insert_checkin`
- **Parameters:**
  - `p_mood`: `{{1.view.state.values.mood_block.mood_rating.selected_option.value}}`
  - `p_busyness`: `{{1.view.state.values.busyness_block.busyness_rating.selected_option.value}}`

> **Anonymity:** This module does NOT use `{{1.user.id}}` or `{{1.user.name}}`. Only the two rating values are stored.

**Module 3b: Webhook response**
- Return empty JSON `{}` with status 200 (Slack requires acknowledgement within 3 seconds)

### A5. Metabase Dashboard Cards

#### Card 1: Team Mood Over Time (line chart)

```sql
SELECT
    response_date,
    ROUND(AVG(mood_rating), 1) as "Avg Mood",
    COUNT(*) as "Responses"
FROM checkin_responses
WHERE response_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY response_date
ORDER BY response_date;
```

X-axis: response_date, Y-axis: Avg Mood

#### Card 2: Team Busyness Over Time (line chart)

```sql
SELECT
    response_date,
    ROUND(AVG(busyness_rating), 1) as "Avg Busyness",
    COUNT(*) as "Responses"
FROM checkin_responses
WHERE response_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY response_date
ORDER BY response_date;
```

#### Card 3: Mood & Busyness Combined (dual-axis line chart)

```sql
SELECT
    response_date,
    ROUND(AVG(mood_rating), 1) as "Avg Mood",
    ROUND(AVG(busyness_rating), 1) as "Avg Busyness"
FROM checkin_responses
WHERE response_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY response_date
ORDER BY response_date;
```

#### Card 4: Weekly Trend (bar chart)

```sql
SELECT * FROM v_checkin_weekly
WHERE week_start >= CURRENT_DATE - INTERVAL '12 weeks';
```

#### Card 5: Mood by Focus Cycle (bar chart)

```sql
SELECT * FROM v_checkin_by_cycle;
```

#### Card 6: Today's Stats (number cards)

```sql
SELECT
    COUNT(*) as "Responses Today",
    ROUND(AVG(mood_rating), 1) as "Avg Mood",
    ROUND(AVG(busyness_rating), 1) as "Avg Busyness"
FROM checkin_responses
WHERE response_date = CURRENT_DATE;
```

#### Anonymity threshold

To protect anonymity on small teams, filter Metabase cards to only show data for days with 3+ responses:

```sql
SELECT * FROM v_checkin_daily WHERE response_count >= 3;
```

---

## Part B: Fun Question of the Day

Handled entirely outside the database, using the Google Sheet + Slack Workflow Builder approach from [Aaron Heth's guide](https://aaronheth.medium.com/slack-hack-make-a-completely-automated-question-of-the-day-system-for-your-team-with-no-plugins-4dbdd26a0573).

### Summary of approach

1. **Google Sheet** with three tabs:
   - **Questions** — list of fun questions (anyone can add more)
   - **Count** — a "1" is appended each time a question is posted (tracks position)
   - **Automations** — formula references the count to determine which question to post next
2. **Slack Workflow 1** (scheduled daily): reads the current question from the Google Sheet and posts it to the channel
3. **Slack Workflow 2** (shortcut): lets team members submit new questions via a form, which appends them to the Google Sheet

### Timing

Schedule the fun question workflow to post at a different time from the mood check-in (e.g. mood at 09:30, fun question at 10:00), or post them in separate channels. This keeps the two purposes distinct while both being part of the daily routine.

---

## Duplicate Prevention

The current design allows multiple submissions per person per day (since we don't track who submitted). Options if this becomes an issue:

1. **Accept it** — treat multiple submissions as valid mood updates throughout the day
2. **Cap per day** — if you have N team members and consistently see >N responses, investigate
3. **Slack-side prevention** — would require storing a hashed user ID, which weakens anonymity

Recommendation: start with option 1.

---

## Testing Checklist

- [ ] Run `sql/checkin-schema.sql` on PostgreSQL
- [ ] Verify `insert_checkin(5, 7)` inserts a row
- [ ] Create Make.com Scenario 1 (daily post), test manually
- [ ] Create Make.com Scenario 2 webhook, set as Slack Interactivity URL
- [ ] Verify Slack URL verification handshake completes
- [ ] Click "Check In" button → modal opens
- [ ] Submit modal → check `checkin_responses` table has a row with no user data
- [ ] Set up Metabase dashboard cards
- [ ] Enable Scenario 1 schedule (Mon–Fri 09:30)
- [ ] Set up Google Sheet + Slack Workflows for fun questions (Part B)
- [ ] Disable/remove DailyBot
