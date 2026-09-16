# NEXUS design audit

Date: 2026-09-15
Status: DONE_WITH_CONCERNS — report-only design review completed for the accessible signed-in state.
Scope completed: README, frontend decision, file inventory, existing test runners, rendered login, registration, profile, skill gaps, opportunities, and feedback at localhost:8501. No implementation changes. No source-code audit or production-backend verification.

## Assessment

The pilot has a clear documented purpose: profile → skill gaps → matched opportunities → next action. Its entry UI is simple and uses persistent labels, clear tab selection, and a visible focus border. It is an OPERATE surface. The accepted frontend decision prioritizes a usable Streamlit bootcamp demo; a frontend rewrite is not a prerequisite for addressing the findings below.

## Findings

1. **Medium: the value proposition is abstract.** The entry subtitle says “Student Intelligence & Opportunity Platform.” Explain the outcome in one sentence: “Find the skills to build and opportunities that fit your career goal.” Keep the DSN affiliation as secondary context.
2. **Medium: no visible account-recovery route.** Login offers email, password, and submission, but no recovery or support action. Add a real recovery flow or an explicit pilot support route. Backend recovery capability was not inspected.
3. **Medium: registration provides no visible password requirements.** Show the actual enforced requirements before submission. Validation behavior was not tested because no account was created.
4. **Medium: small text and short controls.** Rendered labels and inputs use 14px Source Sans; inputs measured 36px high and tabs/submit buttons 40px high. Raise entry-form text to 16px and interactive targets to at least 44px. The password visibility button measured 16px; verify and enlarge its effective clickable area.
5. **Medium: wide-screen form stretches excessively.** The registration form spans most of the desktop content area, making short fields and the primary action visually diffuse. Constrain authentication to roughly 440–520px while allowing the future student workspace to use a wider layout.
6. **Polish: developer chrome is student-facing.** Deploy and the Streamlit menu are visible above the app. Use supported deployment settings to remove unnecessary developer controls from the student experience.

All findings are deferred: this is a report-only request. Screenshots were displayed inline in the review conversation. No screenshot files were persisted.

## Quick wins

- Replace the abstract subtitle with a concrete student outcome.
- Constrain authentication form width.
- Increase form text and target sizes.
- Add accurate password help text.

## Verification

- `python app/tests/test_intelligence.py`: 7/7 passed.
- `python app/tests/test_tagger.py`: 10/10 passed.
- Login and registration rendered successfully; tabs switched correctly.
- Narrow and wide layouts were inspected. Exact 375px mobile certification is withheld: the browser override reported an actual inner width of 536px during the requested narrow test. Overrides were reset.
- No AGENTS.md, DESIGN.md, or Git metadata was found in the inspected project folder.
- README inventory omits the present ingestion, sources, tagger, and tagger-test files; refresh it to reflect current build scope.
- The test results establish those suites pass, not that signup, persistence, privacy, ingestion, or the complete student journey passes.

## Authenticated findings, in priority order

### High: match labels overstate what the explanation establishes

For the AI Engineer target, Customer Support Specialist and Senior Independent AI Engineer / Architect both display 100% match. Freelance Writer displays 90% with Communication as its only listed overlap. The senior AI role lists only Large Language Models and Machine Learning. These are observed outputs, not a claim that the scoring implementation is mathematically wrong. The UI does not explain career alignment, seniority, geography, eligibility, or uncertainty, so a student can interpret a skills-based number as overall suitability.

Make the score's meaning explicit; distinguish skills coverage from career relevance and eligibility. Show missing or unverified requirements. Review relevance and extracted tags before presenting a confident overall match. Customer Support Specialist listing Deep Learning is a specific tagging candidate for investigation, not a proven extraction defect without inspecting the source posting.

### High: sample opportunities are mixed with live results

The page announces 34 live-sourced postings, but the same list includes Curated and Sample feed entries whose Open opportunity links point to example.org, including the top AI Engineering Fellowship. Source labels are present, but there is no explicit warning that these entries are non-actionable demonstrations. Separate demo content from live opportunities and label or disable sample application links.

### High: feedback defaults bias pilot evidence

On first inspection the form shows before clarity = 3/5, after clarity = 4/5, and recommendation = 8/10. The introduction says this is how “we prove NEXUS works.” These starting values and wording encourage a positive result. Require deliberate answers, use equivalent neutral starting states or unselected choices, label scale endpoints, and ask what worked and what did not. No feedback was submitted; whether these are global defaults or restored session values was not source-verified.

### Medium: no next action when all skills are on track

Skill gaps shows 17/17 on track, 0 priority gaps, and Biggest gap = an em dash. The page ends after the required-skills table, without a next step. This is a success state that becomes a dead end. Replace the empty metric with an explanation and an action such as View matched opportunities or Validate skills with a project. Do not invent an unnecessary skill gap.

### Medium: opportunity list is difficult to manage

The rendered page contains 39 opportunity headings and repeated match badges, skill percentages, explanations, links, and save buttons. No search, filtering, sorting control, pagination, or saved-only view is exposed. One existing saved item shows a clear Saved state, but there is no dedicated route to retrieve it. Add search and filters for career relevance, opportunity type, seniority, source, and saved status. Collapse secondary details and avoid repeating identical percentages.

### Medium: narrow layout hides the core comparison and navigation

In the narrow app panel, the skill table shows only Skill and part of You; the comparison requires horizontal exploration. Three vertically stacked summary metrics push the table far down. The navigation drawer covers most of the content and remains open after selection, requiring manual closure. Its accessible toggle names are keyboard_double_arrow_left/right rather than Open/Close navigation. Use compact skill rows with current level, target, and status; a concise success summary; and a labeled navigation toggle that closes after selection on small screens. These observations concern the actual narrow panel, not a certified 375px viewport.

### Medium: self-assessment levels lack anchors

The Computer Vision dropdown exposes None, Beginner, Intermediate, Advanced, Expert without behavioral examples. Eleven ML/AI skills occupy one expanded section, and seven category groups must be explored to assess the full profile. Put career-relevant skills first, show category completion summaries, and define the levels with examples such as “can complete a task with guidance” or “can deliver independently.” This improves input consistency before tuning recommendation mathematics.

## What works

- All four signed-in sections render, and navigation selection is visible when the sidebar is open.
- Profile sections have persistent labels and distinct save actions.
- Skill groups use expandable sections, reducing initial clutter.
- Gap analysis names the target career and provides readable status counts.
- Opportunity entries expose their source, some deadlines, matched skills, and saved state.
- Feedback is short enough for a pilot.
- No browser console errors were returned by the final error-log check.

## Updated quick wins

1. Explicitly mark sample listings and disable sample application links.
2. Explain exactly what the match percentage measures.
3. Give the all-skills-on-track state a concrete next action.
4. Replace persuasive feedback wording and positive starting answers.
5. Add brief proficiency-level definitions.

## Review limits and assessment

Subjective design grade: C (usable pilot foundation with material clarity and trust gaps). Visual originality: C (largely default Streamlit styling, emoji identity, repeated bordered opportunity panels). No score delta: no fixes were made. Detector was not run. Total findings: 13, all reported for later work, none fixed or committed.

This review used the user's existing populated profile. No profile values were changed, no feedback was submitted, no opportunity was saved/unsaved, no feed was refreshed, and no external application link was followed. Save persistence, new-account onboarding, a profile with actual gaps, empty opportunity results, failure recovery, and external listing validity remain untested. Existing unit tests passing does not establish these flows pass.

Durable learning: NEXUS's all-skills-on-track state needs its own next-action design; auditing only a beginner demo profile would miss that dead end. The live-listing mix also requires a product-visible distinction between sample and actionable content. Recorded here because the gstack helper was unavailable.

## Environment note

The gstack startup helper failed through Windows Bash (access denied). Its browser executable failed to locate server.ts, and an explicit path to the bundled server also failed to start. Review continued with the available Codex browser. This is a tooling limitation, not a NEXUS defect.
