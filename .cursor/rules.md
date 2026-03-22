# Chrona UI Development Rules

## General
- This is a macOS desktop application.
- Built using SwiftUI.
- The UI should feel native to macOS, not like a web app.
- Prefer subtle, clean, and premium visual style.

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

## Restrictions
- Do NOT invent UI that is not in Figma.
- Do NOT change layout structure unless explicitly asked.
- Do NOT add extra padding, spacing, or elements.
- Do NOT refactor unrelated code.

## When Uncertain
- Stay closer to Figma rather than making assumptions.
- If something is unclear, implement the simplest version that matches the design.
