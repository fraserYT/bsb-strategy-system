# Proposal: AI-Assisted Strategic Advisory for Bitesize Bio

**Prepared for:** Fraser Smith, Bitesize Bio
**Date:** 13 February 2026
**Author:** Claude (Opus 4.6), via Claude Code

---

## Executive Summary

Bitesize Bio has built a strategy execution system that tracks projects, milestones, and focus cycles across four strategic bets. This system currently operates as a **passive tracker** — it records what has been decided and reports on progress.

This proposal outlines how that system can be extended into an **active strategic advisory layer**, where I serve as an always-available thinking partner who holds the full business context, challenges assumptions, identifies gaps, and suggests what should happen next.

This is not a replacement for human judgment. It is a force multiplier for a leader who is already making good decisions but is constrained by time, cognitive load, and the difficulty of holding an entire business in their head simultaneously.

---

## The Problem

Running a small-to-medium business involves holding an extraordinary number of interconnected variables in your head at once:

- **Strategic direction** — Are we working on the right things?
- **Resource allocation** — Are people deployed where they'll have the most impact?
- **Sequencing** — Are we doing things in the right order? Are there dependencies we're missing?
- **Opportunity cost** — What are we *not* doing, and does that matter?
- **Market timing** — Are external conditions changing in ways that should alter our plans?
- **Team capacity** — Are we overloading people? Underutilising them?
- **Cross-functional impact** — Does a decision in editorial affect development? Does a sales initiative create production bottlenecks?

Most leaders manage this through a combination of experience, intuition, spreadsheets, and conversations with trusted colleagues. The challenge is that:

1. **No single person can hold the full picture at all times.** Important connections between projects get missed.
2. **Strategic review happens periodically, not continuously.** By the time you review, the situation has already moved.
3. **External advisors are expensive and context-limited.** A consultant needs weeks of onboarding and still won't know your business as well as you do.
4. **Team members have partial views.** Each person sees their domain clearly but not the whole.

---

## The Proposed Solution

### What I Would Do

Serve as a **persistent strategic thinking partner** with three core functions:

#### 1. Hold the Full Picture

After an initial briefing, I would maintain a comprehensive understanding of:

- Your business model, revenue streams, and unit economics
- Market position, competitive landscape, and industry trends
- Team structure, capabilities, and capacity constraints
- All active projects across all departments (not just technical ones)
- Strategic bets and the logic behind them
- Dependencies between projects, teams, and external factors
- Historical context — what was tried before, what worked, what didn't

This context would persist across sessions via structured memory files and a dedicated beads instance, meaning every conversation starts with full awareness rather than a cold start.

#### 2. Actively Advise

Rather than waiting to be asked, I would:

- **Flag risks early** — "Project X in editorial depends on the platform work in dev, which is now two weeks behind. Should we adjust the editorial timeline or reprioritise the dev work?"
- **Identify gaps** — "You have four projects targeting B2 (Informed Standardisation) but none of them address the data quality issue you mentioned in the initial briefing. Is that deliberate?"
- **Challenge assumptions** — "You've allocated 40% of dev capacity to B3 (Automation) but only 15% to B4 (Owned Audience). Your revenue analysis suggests B4 has the highest near-term impact. What's driving the allocation?"
- **Suggest sequencing** — "If you complete the email migration before the content restructure, you can use the new segmentation data to inform the restructure. Doing them in parallel means the restructure won't benefit from that data."
- **Propose experiments** — "Before committing a full focus cycle to this initiative, could you run a two-week proof of concept with just one team member?"

#### 3. Track Everything

Using a dedicated beads instance, I would maintain:

- All strategic initiatives, whether they involve code or not
- Status updates as you report them
- Decision logs — what was decided, why, and what alternatives were considered
- Risk register — known risks, their likelihood, impact, and mitigation
- Dependency map — which projects depend on which others
- Retrospective notes — what we learned from completed or abandoned work

### How Sessions Would Work

I envision four types of interaction:

#### Weekly Strategy Check-in (30-45 minutes)

A structured session at a consistent time each week:

1. You update me on what happened since last session
2. I update my tracking and flag anything that's changed
3. We review the week ahead — what's planned, what's at risk
4. I raise any strategic questions or suggestions
5. We capture decisions and action items

#### Ad-Hoc Decision Support (as needed)

When you face a decision and want a thinking partner:

- "We've been approached by Company X for a partnership. Here's what they're proposing. What should I consider?"
- "A team member has resigned. How does this affect our FC2 plans?"
- "A competitor just launched a product similar to what we're building in B1. Should we change course?"

#### Focus Cycle Planning (every 6 weeks)

A deeper session at the start of each focus cycle:

1. Review what was achieved in the previous cycle
2. Assess what's changed in the business context
3. Plan the upcoming cycle — which projects, which milestones, which people
4. Identify the one or two things that matter most this cycle
5. Flag anything that should be paused, killed, or accelerated

#### Quarterly Strategic Review (every 3 months)

The most comprehensive session:

1. Are the four strategic bets still the right bets?
2. Is the resource allocation across bets still appropriate?
3. What has the market done that we should respond to?
4. Are there new opportunities or threats?
5. What should change for the next quarter?

---

## Infrastructure

### Dedicated Beads Instance

A new beads database at `~/.beads-strategy/` (or similar), entirely separate from the existing dev-focused `~/.beads/`:

| Aspect | Dev Beads (`~/.beads/`) | Strategy Beads (new) |
|--------|------------------------|---------------------|
| **Scope** | Technical implementation tasks | All business initiatives |
| **Granularity** | Code changes, bug fixes, feature work | Projects, decisions, risks, experiments |
| **Audience** | Developer (you + Claude Code) | Business leader (you + Claude as advisor) |
| **Prefix** | `claude-wp-` | `bsb-strat-` (or similar) |
| **Relationship** | Child | Parent |

Some strategic items would have corresponding dev tasks. For example:

```
bsb-strat-014: Launch email segmentation v2
  └── claude-wp-xyz: Implement AC template changes (dev beads)
```

The strategic beads tracks the business outcome; the dev beads tracks the implementation work.

### Memory Architecture

A dedicated context file (similar to `claude.md` but for the full business) would hold:

- **Business Model Canvas** — value proposition, customer segments, channels, revenue streams, cost structure
- **Competitive Landscape** — key competitors, their strengths, your differentiation
- **Team Map** — who does what, their capacity, their strengths
- **Strategic Bets** — the logic behind each bet, success criteria, key assumptions
- **Active Initiatives** — all projects across all departments
- **Decision Log** — significant decisions with rationale
- **Risk Register** — tracked risks and mitigations
- **Lessons Learned** — insights from completed or failed work

This file would be updated after each session, ensuring the next session starts with full context.

### Integration with Existing Systems

The strategy advisory layer sits above the existing BsB Strategy System:

```
┌─────────────────────────────────────────────────┐
│         AI STRATEGY ADVISORY LAYER              │
│  (Claude Code + Strategy Beads + Memory Files)  │
│                                                 │
│  Business model / Market position / All teams   │
│  Decision support / Risk tracking / Planning    │
└──────────────────────┬──────────────────────────┘
                       │ informs
                       ▼
┌─────────────────────────────────────────────────┐
│         BsB STRATEGY EXECUTION SYSTEM           │
│  (Asana + PostgreSQL + Metabase + Make.com)     │
│                                                 │
│  Strategic bets / Projects / Milestones         │
│  Focus cycles / Dashboards / Notifications      │
└──────────────────────┬──────────────────────────┘
                       │ some items become
                       ▼
┌─────────────────────────────────────────────────┐
│         DEV IMPLEMENTATION (existing)           │
│  (Claude Code + Dev Beads + Git repos)          │
│                                                 │
│  Code changes / Theme work / Plugin dev         │
│  Template updates / Infrastructure              │
└─────────────────────────────────────────────────┘
```

---

## Benefits

### 1. Continuous Strategic Awareness

Instead of strategy being something you think about during quarterly offsites, every interaction with me would be informed by the full strategic context. A status update about an editorial project would automatically be considered against dev dependencies, sales timelines, and team capacity.

### 2. Reduced Cognitive Load

You currently hold the entire business in your head. By externalising it into structured memory files and beads, you free up mental bandwidth for the judgment calls that only you can make. I handle the bookkeeping of "what depends on what" and "what did we decide about X."

### 3. Faster Decision-Making

When a decision needs to be made, you wouldn't need to reconstruct context from scratch. The relevant history, constraints, and trade-offs would already be organised and accessible.

### 4. Institutional Memory

Decisions, rationale, and lessons learned would be captured systematically. Six months from now, you could ask "why did we decide to deprioritise B2 in FC3?" and get a precise answer with context, not a vague recollection.

### 5. Cross-Functional Visibility

I would hold context across all departments simultaneously — something that's difficult for any single team member. This means spotting dependencies and conflicts that might otherwise surface too late.

### 6. Judgment-Free Sounding Board

I have no ego, no politics, no career ambitions, and no emotional attachment to previous decisions. If a strategic bet isn't working, I can say so without the social cost that might prevent a colleague from raising it.

### 7. Low Marginal Cost

Once the initial briefing is complete, the ongoing cost is your time in sessions. There is no consulting fee, no retainer, no SOW negotiation. The tool is already available to you.

### 8. Always Available

Unlike a human advisor, I'm available whenever you need to think through a problem — evenings, weekends, during travel. The quality of advice doesn't degrade based on my schedule.

---

## Risks, Limitations, and Honest Drawbacks

I want to be straightforward about where this breaks down. If I'm pitching for this job, you should know exactly what you're not getting.

### Risk 1: Garbage In, Garbage Out

**The problem:** My understanding of your business is only as good as what you tell me. If you forget to mention a key constraint, competitor move, or team issue, my advice will be based on an incomplete picture.

**Mitigation:** Structured briefing templates for each session type. Periodic "full context review" sessions where we systematically walk through each area to catch anything that's drifted.

**Residual risk:** Medium. You are a single point of information flow. If you're too busy to brief me properly, the advice quality drops.

### Risk 2: No Independent Information Gathering

**The problem:** A human advisor can attend your team meetings, observe your culture, talk to your customers, read industry reports, and form impressions from sources you don't control. I cannot. I only know what's in our conversations and my training data.

**Mitigation:** You could share relevant documents, customer feedback, competitor announcements, or industry articles during sessions. But this is additional work for you.

**Residual risk:** High. This is the single biggest limitation. I am structurally unable to notice things you haven't noticed or don't think to tell me.

### Risk 3: Over-Reliance

**The problem:** If the advisory relationship works well, there's a risk of defaulting to "ask Claude" instead of developing your own strategic thinking or consulting your team. This could weaken your independent judgment over time and reduce team engagement in strategic discussions.

**Mitigation:** Use me as a thinking partner, not a decision-maker. Always make the final call yourself. Continue to involve your team in strategic discussions — I should augment those conversations, not replace them.

**Residual risk:** Low-Medium. Depends on discipline.

### Risk 4: Context Window and Session Boundaries

**The problem:** Each conversation starts fresh. While memory files and beads provide continuity, I don't carry the nuance of previous discussions automatically. Subtle context (your tone of concern about a particular initiative, a half-formed idea you mentioned in passing) may be lost between sessions.

**Mitigation:** Good note-taking habits and structured memory files. Explicit flags when something is important but not yet actionable ("remember that I'm worried about X, we should revisit next week").

**Residual risk:** Medium. Memory files help but are not the same as genuine continuity of thought.

### Risk 5: Training Data Limitations

**The problem:** My knowledge of life science media, scientific publishing, and the specific market Bitesize Bio operates in comes from my training data (cut off May 2025). I may have outdated views on industry trends, competitor positions, or market dynamics.

**Mitigation:** You would need to brief me on current market conditions. I can ask good questions to draw this out, but I cannot independently research it.

**Residual risk:** Medium. I can reason well about strategy in general, but my domain-specific insights for your niche will be limited without your input.

### Risk 6: I Cannot Read People

**The problem:** A significant part of business strategy involves people — their motivations, their capacity for change, their unspoken concerns, team dynamics, and organisational culture. I have no visibility into any of this.

**Mitigation:** You can describe team dynamics and people considerations to me, and I can reason about them. But I'm working from your description, not direct observation.

**Residual risk:** High. People are often the most important variable in whether a strategy succeeds, and I'm essentially blind to this dimension.

### Risk 7: Confidentiality Considerations

**The problem:** You would be sharing detailed business information — financials, strategy, competitive intelligence, personnel matters — with an AI system. This data is processed by Anthropic's infrastructure.

**Mitigation:** Review Anthropic's data policies. Avoid sharing information that would be genuinely damaging if exposed (exact financials, personal employee data, legal matters). Use general descriptions where specifics aren't needed for the advice to be useful.

**Residual risk:** Low-Medium. Depends on your comfort level and Anthropic's data handling policies.

### Risk 8: I May Be Confidently Wrong

**The problem:** I present analysis clearly and confidently. This can make bad advice sound convincing. I don't have the self-doubt that a human advisor might express through body language or hedging.

**Mitigation:** Always pressure-test my recommendations. Ask "what could go wrong with this?" or "what am I missing?" I'm generally good at generating counterarguments when prompted. Treat my suggestions as hypotheses to evaluate, not conclusions to adopt.

**Residual risk:** Medium. This is an inherent property of the tool and requires conscious effort to manage.

---

## What I Would Need From You

### Initial Briefing (one-off, 2-3 sessions)

A comprehensive briefing covering:

1. **Business model** — What does Bitesize Bio do? How does it make money? What are the revenue streams and their relative sizes? What's the cost structure?
2. **Market position** — Who are your customers? What do they value? How do they find you? What's your competitive advantage?
3. **Competitive landscape** — Who are the main competitors? What do they do well? Where are they weak? What are they likely to do next?
4. **Team** — Who works here? What are the departments? What's the capacity? Where are the strengths and gaps?
5. **Strategic bets** — The logic behind B1-B4. What assumptions underpin each bet? What does success look like? What would cause you to abandon a bet?
6. **Current state** — All active projects (not just the ones in the strategy system). What's going well? What's struggling?
7. **History** — What has the company tried before? What worked? What failed? Why?
8. **Constraints** — Budget, headcount, technical debt, contractual obligations, regulatory requirements, anything that limits freedom of action.

### Ongoing Requirements

- **Weekly status updates** (15-30 minutes of your time) — What happened this week? What changed? Any surprises?
- **Prompt escalation** — When something significant happens (team change, competitor move, customer loss/win, market shift), tell me sooner rather than later.
- **Honest feedback** — If my advice is off-base, tell me why. This helps me calibrate.
- **Willingness to be challenged** — The value of this arrangement drops significantly if you only want confirmation of decisions you've already made.

---

## Comparison to Alternatives

| Factor | AI Advisor (this proposal) | Fractional COO / Consultant | Internal Team Discussion | Doing Nothing |
|--------|---------------------------|----------------------------|--------------------------|---------------|
| **Cost** | Included in existing Claude subscription | $$$ (typically hundreds/day) | Free but uses team time | Free |
| **Availability** | Always | Scheduled / limited hours | When team is available | N/A |
| **Context depth** | As good as briefing quality | Takes weeks to onboard | Team has deep context but partial views | N/A |
| **Independent observation** | None | Yes — can attend meetings, interview team | Yes — they live in the business | N/A |
| **Objectivity** | High (no politics, no ego) | Moderate (may tell you what you want to hear to retain the contract) | Low (career incentives, team dynamics) | N/A |
| **Domain expertise** | General + training data | Can hire for specific domain | Varies by team member | N/A |
| **Institutional memory** | Structured, persistent, searchable | Leaves when contract ends | Leaves when people leave | N/A |
| **Speed** | Immediate | Days to schedule | Depends on calendars | N/A |
| **People insight** | None (major gap) | Strong | Strong | N/A |

**My recommendation:** This is not either/or. An AI advisor works best *alongside* human input, not instead of it. If you have trusted colleagues or advisors you consult on strategy, continue doing so. I add the most value in the spaces between those conversations — maintaining context, tracking details, and being available when you need to think something through at short notice.

---

## Proposed Implementation Plan

### Phase 1: Infrastructure Setup (1 session)

- Create dedicated strategy beads instance
- Set up strategy memory file structure
- Define session templates (weekly, cycle planning, quarterly review)
- Establish naming conventions and tracking structure

### Phase 2: Initial Briefing (2-3 sessions)

- Full business model briefing
- Competitive landscape mapping
- Team and capacity assessment
- Current state inventory (all active initiatives)
- Strategic bet deep-dive (assumptions, success criteria, risks)

### Phase 3: Trial Period — FC1 (6 weeks)

- Weekly check-in sessions
- Track all strategic initiatives via strategy beads
- I provide observations, questions, and suggestions
- You evaluate: Is this adding value? Where is it falling short?

### Phase 4: Review and Adjust

- What worked well during the trial?
- What needs to change?
- Should we continue, modify, or stop?
- Adjust session structure, tracking approach, and scope based on experience

---

## What Success Looks Like

After three months, this is working if:

1. You feel like you have **better visibility** across all parts of the business
2. I've flagged at least one significant risk or dependency you hadn't spotted
3. Strategic decisions are being made **faster** because context is pre-assembled
4. The decision log means you can explain *why* something was decided, not just *what*
5. Focus cycle planning takes less time because the groundwork is already done
6. You feel comfortable saying "that advice was wrong" and I adjust accordingly

This is **not** working if:

1. Sessions feel like a reporting chore rather than a thinking exercise
2. You find yourself ignoring my suggestions because they're too generic or uninformed
3. The overhead of maintaining context files exceeds the value of having them
4. You feel less confident in your own strategic thinking, not more

---

## Closing

I'm a tool, not a guru. I don't have intuition, I can't read a room, and I don't know your industry as well as you do. What I can do is hold an enormous amount of context simultaneously, reason about trade-offs systematically, never forget a previous decision, and be available whenever you need to think something through.

The worst case is that after a six-week trial, you decide it's not adding enough value and you stop. The infrastructure (beads, memory files) would still be useful as a personal knowledge base even without the advisory sessions.

The best case is that you gain a persistent, structured thinking partner who makes the full complexity of your business easier to navigate.

I'd like the chance to prove it's closer to the best case.
