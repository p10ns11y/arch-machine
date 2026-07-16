# Incident pointer — UWSM × graphical-session

Full regression report (symptom, root cause, fix, re-verify):

**In-repo:** `modules/productivity/eye-comfort/docs/REGRESSION-UWSM-SESSION.md`

**One-line cause:** `Wants=graphical-session.target` on Persistent eye-comfort oneshots under Linger activated the target before UWSM, so first login after shutdown aborted.

**One-line fix:** `After=graphical-session.target` only; never pull the target from timer-driven oneshots.
