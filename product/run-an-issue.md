# Run a YLaPiano issue — paste this into a fresh conversation

Replace `{{N}}` with the issue number (e.g. 11 for B1). Run one issue per conversation for clean context.

---

Run YLaPiano issue **#{{N}}** end-to-end. Repo: jnuo/Ylapiano · Project board #4.

1. **Read it.** `gh issue view {{N}}` — note its **Persona**, its **🔢 Sub-tasks** checklist (each ends at a **test gate**), and its **depends_on**. Confirm every dependency issue is already CLOSED. If not, STOP and tell me which is blocking.
2. **Adopt the Persona as your lens.** Invoke that skill (game-_ or jpm-_). YOU (Claude Code) implement; the persona is the judgment/review lens. If the Persona is `add-song`, `jpm-aso`, or `appstore-screenshots`, run that skill directly — it's executable.
3. **Work sub-tasks in order.** For each: write the test FIRST (`superpowers:test-driven-development`), implement, run its test gate (XCTest for unit; build + launch on the **iPad Pro 13-inch (M4)** simulator for device checks). Tick the checkbox on the issue when its gate passes.
4. **Self-review.** Run `/code-review` and `/simplify` on the diff; fix what they surface.
5. **VERIFY ON THE SIMULATOR (always).** Boot the iPad sim, `xcrun simctl status_bar booted override --time 9:41 --batteryLevel 100`, build + install + launch. Take screenshots; for any flow/animation record video (`simctl io … recordVideo`) → `ffmpeg` to gif. **Post the images/gif in chat.**
6. **Move the card to In Review** on project #4 (GraphQL `updateProjectV2ItemFieldValue`; if it 401s, retry, then use the browser). Then **STOP** and tell me exactly what to test on my device.
7. **Do NOT ship yet.** After I approve, run `jpm-ship` — ONE PR + version bump for the whole issue, code review, release notes. Then move the card to **Done**.

**Rules:**

- The checklist is the contract — no scope beyond it.
- If a sub-task needs me (`lane:onur-device` / `art` / `calendar`): do everything you can first (generate the asset, wire it in, build, screenshot/record), THEN hand off with exact steps. "I can't finish" never means "I do nothing."
- If you discover the plan is wrong, STOP and flag it — don't silently deviate.

---

**Build order (NOW tier, dependency-safe):**
P1: **B1**(#11) → B2(#12), B3(#13), B6(#14) → B4(#21) · P2: B5(#27) → B8(#15), B10(#22), B11(#16) · P3: B9(#28) → B13(#18) · P4: B20(#20) → B19(#29) → B21(#23) · B22(#24) recruit-now, runs last.
Onur-track in parallel: B7 art (#25), B18 compliance (#26).
