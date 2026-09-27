#!/usr/bin/env bash
# Brain Branches demo: an agent follows skills/brain-branches/SKILL.md on a
# real GBrain. Uses the brain machine `brain` (built by `gbrain-branch init`).
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$PWD:$PATH"
BRAIN=${BRAIN:-brain}
OPTIONS=(hn-launch hackathon-demo twitter-thread)

bold() { printf '\n\033[1m%s\033[0m\n' "$*"; }
say() { printf '  %s\n' "$*"; }
in_brain() { gbrain-branch exec "$BRAIN" -- bash -c "$1"; }

# Fresh start: the brain holds only the seeded problem.
gbrain-branch discard $(gbrain-branch list "$BRAIN") "${OPTIONS[@]/#/$BRAIN-}" >/dev/null 2>&1 || true
in_brain 'for slug in $(gbrain list --type analysis 2>/dev/null | cut -f1); do gbrain delete "$slug" --force >/dev/null 2>&1 || true; done
  git reset -q --hard "$(git rev-list --max-parents=0 HEAD)"
  mkdir -p facts analysis
  cat > facts/goal.md <<EOF
---
title: Launch goal
type: fact
---
We are launching smolmachines at the Own Your Intelligence hackathon.
Goal: the most developer signups by Friday. Budget is zero; one person.
EOF
  git add -A && git commit -qm "seed: launch goal" && gbrain import . --no-embed >/dev/null 2>&1'

bold "1. The brain holds the question (gbrain query)"
in_brain 'gbrain query "how do we get signups" --no-expand 2>/dev/null | head -2' | sed 's/^/  /'

bold "2. Fork the live brain once per option (skill step 2)"
gbrain-branch fork "$BRAIN" "${OPTIONS[@]/#/$BRAIN-}" | sed 's/^/  /'

bold "3. An agent explores each option inside its own branch (skill step 3)"
# What each branch's scripted agent concludes (bash 3.2 has no associative arrays).
finding() {
  case $1 in
    hn-launch) echo "Post a Show HN on a weekday morning, hooked on forking a live VM in under a second. Front page means about 300 signups; missing it means about 20." ;;
    hackathon-demo) echo "Demo branching agent memory live at the YC hackathon. Two hundred builders who ship agents see it today and can install it on their laptops on the spot." ;;
    twitter-thread) echo "A thread with a 20-second clip of 50 forks booting. Reach hinges on one repost from a large account." ;;
  esac
}
score() { case $1 in hn-launch) echo 6 ;; hackathon-demo) echo 9 ;; twitter-thread) echo 5 ;; esac; }
why() {
  case $1 in
    hn-launch) echo "high variance, one shot" ;;
    hackathon-demo) echo "the audience is the customer, same day" ;;
    twitter-thread) echo "depends on luck" ;;
  esac
}
for o in "${OPTIONS[@]}"; do
  (
    gbrain-branch exec "$BRAIN-$o" -- bash -c "gbrain query 'signups goal' --no-expand >/dev/null 2>&1
cat > analysis/$o.md <<'EOF'
---
title: Option $o
type: analysis
score: $(score $o)
---
$(finding $o)

Builds on [[facts/goal]]. Score $(score $o): $(why $o).
EOF
git add -A && git commit -qm 'explore $o' && gbrain import . --no-embed >/dev/null 2>&1 && gbrain extract links --source db >/dev/null 2>&1"
  ) &
done
wait
for o in "${OPTIONS[@]}"; do say "$BRAIN-$o  wrote analysis/$o.md  (score $(score $o): $(why $o))"; done

bold "4. Each branch remembers only its own exploration"
printf '  %-32s' ""; for o in "${OPTIONS[@]}"; do printf '%-17s' "$o"; done; echo
for m in "$BRAIN" "${OPTIONS[@]/#/$BRAIN-}"; do
  printf '  %-32s' "$m"
  for o in "${OPTIONS[@]}"; do
    if gbrain-branch exec "$m" -- gbrain get "analysis/$o" >/dev/null 2>&1; then printf '%-17s' knows; else printf '%-17s' -; fi
  done
  echo
done

bold "5. Compare what each branch learned (skill step 4)"
winner=""; best=-1
for o in "${OPTIONS[@]}"; do
  say "$BRAIN-$o: $(gbrain-branch diff "$BRAIN-$o" | tr '\t\n' '  ')"
  if (( $(score "$o") > best )); then best=$(score "$o"); winner=$o; fi
done
say "best supported: $winner (score $best)"

bold "6. Merge the winner, discard the rest (skill step 5)"
gbrain-branch merge "$BRAIN-$winner" | sed 's/^/  /'
losers=(); for o in "${OPTIONS[@]}"; do [[ $o == "$winner" ]] || losers+=("$BRAIN-$o"); done
gbrain-branch discard "${losers[@]}" "$BRAIN-$winner" | sed 's/^/  /'

bold "7. The brain now knows the winner, wired into its graph (skill step 6)"
in_brain "gbrain get analysis/$winner 2>/dev/null | sed -n '/^---\$/,/^---\$/!p' | sed '/^\\s*\$/d' | head -2" | sed 's/^/  /'
say "backlinks to facts/goal:"
in_brain 'gbrain backlinks facts/goal 2>/dev/null' | grep -o '"from_slug": "[^"]*"' | cut -d'"' -f4 | sed 's/^/    /'
for o in "${OPTIONS[@]}"; do
  [[ $o == "$winner" ]] && continue
  if in_brain "gbrain get analysis/$o >/dev/null 2>&1"; then say "UNEXPECTED: brain knows $o"; else say "discarded option $o left nothing in the brain"; fi
done
say "history: $(in_brain 'git log --oneline | head -3 | tr "\n" ";"')"

bold "8. Later, the merged decision proves wrong: rewind the whole brain (skill step 7)"
checkpoints=$(gbrain-branch log "$BRAIN")
printf '%s\n' "$checkpoints" | sed -n '1,3s/^/  /p'
label=$(printf '%s\n' "$checkpoints" | awk -v w="before-merge-$BRAIN-$winner-" 'index($1, w) == 1 && !found { print $1; found = 1 }')
gbrain-branch rewind "$BRAIN" "$label" | sed 's/^/  /'
if in_brain "gbrain get analysis/$winner >/dev/null 2>&1"; then say "UNEXPECTED: brain still knows $winner"; else say "the merged page is gone; the brain is exactly as it was before the merge"; fi
say "backlinks to facts/goal: $(in_brain 'gbrain backlinks facts/goal 2>/dev/null' | grep -o '"from_slug": "[^"]*"' | cut -d'"' -f4 | tr '\n' ' ')(none)"
undo=$(gbrain-branch log "$BRAIN" | awk '/^before-rewind-/ && !found { print $1; found = 1 }')
say "and the rewind itself can be undone: gbrain-branch rewind $BRAIN $undo"
