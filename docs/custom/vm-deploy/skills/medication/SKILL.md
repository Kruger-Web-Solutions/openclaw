---
name: medication
description: Morning and evening medication and supplement protocol with timing, safety rules, and reminders. Use when Henzard asks about meds, vitamins, supplements, says "morning meds", "evening meds", "what meds tonight", or when medication reminders fire. TRIPLIXAM is safety-critical blood pressure medication.
---

# Medication Protocol

## Morning Meds (6:30am with morning shake)

| Medication | Purpose |
|-----------|---------|
| TRIPLIXAM 10/2.5/10 MG | Blood pressure — **once daily, safety-critical** |
| 2x Staminogro | Bone/joint health |
| Metagenics Ultraflora Balance | Probiotic (gut health) |
| Lifestyle Vitamin C 1000mg | Immune support |
| Gold Co-enzyme Q10 160mg | Heart/energy |
| Gold Zinc | Immune/testosterone |
| Solal Vitamin A 5000iu | Immune/skin |

## Morning Shake (log in SparkyFitness as "Morning Shake")

- L-Glutamine + Collagen + Creatine

## Evening Meds (21:00pm)

| Supplement | Purpose |
|-----------|---------|
| Mag Glycinate | Sleep quality |
| Ashwagandha | Stress/cortisol reduction |
| Zinc | Immune (second dose) |
| Vitamin D3 + K2 | Bone/immune — **take with meal/fat for absorption** |
| Moringa | Nutrient density |

## Safety Rules

- **TRIPLIXAM is non-negotiable.** If Henzard mentions skipping BP meds, escalate immediately: "Your blood pressure medication is safety-critical. Please take it now."
- Never suggest skipping or reducing prescription medication.
- Supplements can be adjusted; prescriptions cannot.
- D3+K2 requires fat for absorption — remind if taken on empty stomach.

## Confirmation Pattern (MANDATORY Cross-Service)

When Henzard confirms meds taken, you MUST complete the Habitica daily. This is non-optional:
- Morning: `habitica complete "Morning Vitamins & Supplements"`
- Evening: `habitica complete "Evening Vitamins & Supplements"`

### Time-of-Day Inference
If Henzard says "took my meds" or "meds done" without specifying morning/evening:
- Before 12pm SAST → morning meds
- After 5pm SAST → evening meds
- Between 12-5pm → ask: "Morning or evening meds?"

### After Completion
Always reply with the progress snapshot: "Morning Vitamins done. Today: X/Y dailies complete."
Run `habitica dashboard` to get the count.

The actual med lists are also in the `notes` field of these Habitica dailies. Always read the real notes via `habitica dailies` rather than reciting from memory.
