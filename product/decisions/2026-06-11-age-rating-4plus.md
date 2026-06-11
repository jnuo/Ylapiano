# Decision: age rating questionnaire → 4+ (NOT Kids Category)

**Date:** 2026-06-11 · **Status:** locked (Onur confirmed) · **Card:** B18 (#26)

y la piano files the standard Apple age-rating questionnaire and lands at
**4+**. We do NOT opt into the Kids Category (see
`2026-06-11-kids-category-no-ipad-only.md`).

## Questionnaire answers

Every content question is answered **None / No**:

| Question                                                | Answer                                                                               |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Cartoon or fantasy violence                             | None                                                                                 |
| Realistic violence                                      | None                                                                                 |
| Prolonged graphic/sadistic violence                     | None                                                                                 |
| Profanity or crude humor                                | None                                                                                 |
| Mature/suggestive themes                                | None                                                                                 |
| Horror/fear themes                                      | None                                                                                 |
| Medical/treatment information                           | None                                                                                 |
| Alcohol, tobacco, or drug use or references             | None                                                                                 |
| Simulated gambling                                      | None                                                                                 |
| Sexual content or nudity                                | None                                                                                 |
| Graphic sexual content and nudity                       | None                                                                                 |
| Contests                                                | No                                                                                   |
| Unrestricted web access                                 | No (no web access at all; the abcjs WKWebView loads only a bundled local file)       |
| Gambling with real currency                             | No                                                                                   |
| User-generated content shared with others               | No (the song editor saves only locally; nothing is shared or visible to other users) |
| Messaging / chat                                        | No                                                                                   |
| Third-party advertising                                 | No                                                                                   |
| App designed primarily for kids? (Kids Category opt-in) | **No** — deliberate; see decision doc                                                |

**Resulting rating: 4+** (lowest tier).

## Why these answers are safe

- Content is traditional children's songs + a cartoon squirrel; nothing rated.
- The only WKWebView renders bundled sheet-music HTML/JS — no URL bar, no
  navigation, no remote loads (verified: zero network APIs in the codebase).
- The Add Song editor is local-only — it never uploads, shares, or displays
  other users' content, so it is not "user-generated content" in Apple's sense.

## Re-check trigger

If v1.x ever adds: external links (e.g., the Grown-Ups corner linking to the
website — B17), sharing, or any web access → re-answer "Unrestricted web
access" / link-out questions and add a parental gate where required.
