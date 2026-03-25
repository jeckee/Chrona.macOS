# Chrona UI Development Rules

## General
- This is a macOS desktop application.
- Built using SwiftUI.
- The UI should feel native to macOS, not like a web app.
- Prefer subtle, clean, and premium visual style.

## Scope
- These rules apply to all code changes in this project, not only UI implementation.
- For non-UI tasks, still follow the same collaboration, minimal-change, and self-review principles.

## Design Source
- Figma is the single source of truth for UI.
- Do NOT redesign UI when Figma is provided.
- Do NOT simplify layout, spacing, or typography.
- Preserve hierarchy, alignment, and visual weight.

## Layout & Style
- Follow Figma spacing exactly (padding, margin, gaps).
- Use consistent corner radius (avoid random values).
- Maintain proper visual hierarchy (title, subtitle, meta).
- Avoid overly strong colors or contrast.
- Keep UI minimal and calm.

## Components
- Break UI into small reusable SwiftUI components.
- Avoid large monolithic views.
- Prefer composition over duplication.

## Behavior
- Keep interactions macOS-native.
- Avoid web-style interactions.
- Do not introduce new interaction patterns unless required.

## Implementation
- Prioritize visual fidelity first, logic second.
- Use mock data when implementing UI.
- Do not over-engineer state management.
- Prefer the smallest effective change.
- Do not refactor unrelated code.

## Restrictions
- Do NOT invent UI that is not in Figma.
- Do NOT change layout structure unless explicitly asked.
- Do NOT add extra padding, spacing, or elements.
- Do NOT refactor unrelated code.

## Collaboration & Decision Making
- Before making changes, first determine whether the request is fully clear.
- If the requirement is ambiguous, has multiple valid implementations, or may affect product behavior, interaction, architecture, data flow, or business meaning, ask for clarification before coding.
- Do NOT make product, interaction, or architecture decisions on behalf of the user.
- You may decide minor implementation details only when they do not affect UX, business meaning, state flow, or future extensibility.
- When asking for clarification, explicitly list:
  1. what is unclear
  2. the possible options
  3. the impact of each option

## When Uncertain
- Stay closer to Figma rather than inventing new UI.
- If the uncertainty is only visual and does not affect behavior, use the simplest implementation that matches the design.
- If the uncertainty affects behavior, interaction, state flow, architecture, or product meaning, ask for clarification before coding.

## Review & Output
- After completing any code change, perform a strict self-review before presenting the final result.
- Review at least:
  - requirement match
  - possible bugs and edge cases
  - naming consistency
  - unnecessary code changes
  - state/data flow issues
  - macOS-native behavior consistency
- If issues are found in review, fix them before responding.
- In the final response, always include:
  1. what was changed
  2. any important assumptions made
  3. review findings
  4. remaining risks or items needing confirmation