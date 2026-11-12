# Essential Snugpod Tools

The Snugpod magic. The name is a nod to Essential Housing Tools.

Opening the round Telvanni door in the author's Snugpod animates a piece of furniture behind it, then closes the door again. `/snugpod` runs the same animation by hand, and `/snugpod selected` prints the id and position of the selected furniture (for setting up the animation).

It is tied to that one house: the furniture ids in the code don't exist anywhere else, so the addon does nothing in other houses.

## Where did the rest go?

The general helpers that used to be in this addon are now part of [Schrodi's Housing Tools](../SchrodisHousingTools):

- assistants and the Aetherial Well from your quickslots,
- `/storage`, which brings all storage chests to you.

`/storage magic` is now `/snugpod`.
