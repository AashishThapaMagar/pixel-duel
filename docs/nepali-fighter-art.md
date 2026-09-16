# Nepali fighter art pass

Generated with the built-in image tool for the user's request for different Nepali-style fighters: some big, some small, some skinny. Final PNGs and frame metadata are under `assets/sprites/fighter/nepali/`.

Shared generation brief: an original adult Nepali male fighter in a transparent 4-by-4 cel-shaded, ink-outlined sprite atlas, facing right, full bodies, consistent scale and costume, no labels, text, scenery, franchise likenesses, or weapons. Frames: ready, guard, two walk poses, jump, three punch phases, three kick phases, recoil, three signature phases, KO. Real RGBA transparency is required, not a baked checkerboard.

Individual art briefs:

- **Anug:** medium athletic goalkeeper; green long-sleeve jersey, cream gloves, teal trousers, Dhaka-inspired collar and waist trim. Signature: diving double-glove clearance.
- **Ish:** skinny, wiry long limbs and angular adult face; red shirt, black open waistcoat, woven red/cream trim, knee support, red hand wraps. Signature: long-reaching rushing punch.
- **Sab:** broad stocky heavyweight with beard, thick neck, waist and forearms; navy bhoto-inspired wrap vest, copper patuka, cream loose trousers. Signature: clinch grab and twisting follow-through.
- **Bib:** small compact adult, slim shoulders, short black hair; blue streetwear hoodie, patterned sash, dark joggers and turquoise shoes. Signature: running side kick.
- **Abhi:** large heavyset adult, moustache, expressive face; purple waistcoat over cream kurta, red patuka, patterned Dhaka topi. Signature: speaking taunt with cupped hand and gestures.
- **Sup:** lean flexible dancer, tied-back long hair; gold wrap top with maroon edging, teal patuka, loose calf-length trousers and soft shoes. Signature: low sweep and inverted cartwheel.
- **Anant:** tall, balanced powerful build, composed mature face, short beard; charcoal daura-inspired crossed-front coat with restrained gold trim, burgundy patuka, dark trousers and boots. Signature: committed power straight.

These designs are original costume interpretations, not documentary reconstructions of regional dress or portraits of the named people. An earlier Ish export and its edit had baked checkerboards; both were discarded in favor of a newly generated RGBA sheet. All seven final files passed alpha and frame-isolation checks.

The sprite renderer uses the controller's attack clock, keeps the active contact frame frozen during hit-stop, mirrors with facing, and anchors grounded frames to the combat floor. Display heights vary from 113 px (Bib) to 146 px (Anant); collision and move reach remain governed by the existing gameplay rules. Sixteen frames per fighter is the current art pass, with animation families shared for some advanced moves.
