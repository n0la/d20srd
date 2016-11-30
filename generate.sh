#!/bin/sh


for i in $(seq 1 10); do
cat <<EOF >>wondrous/abilities.yml
- name: Resistance +$i
  school: abjuration
  grade: faint
  spell: ["Resistance"]
  feats: ["Craft Wondrous Item"]
  price: $(echo "($i^2)*1000" | bc)
  description: >-
    This item grants a +$i enhancement bonus to all saving throws (fortitude,
    reflex, will).

EOF
done
