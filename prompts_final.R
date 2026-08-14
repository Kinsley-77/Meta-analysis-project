#  LLM extraction prompts (final, frozen version)

# 1 Detailed extraction prompt 
extraction_prompt <- r"---(
You are an experienced human coder for a systematic ecological meta-analysis.
From the SINGLE paper below, extract data at the ROW level of our coding table.
ROW LEVEL + ROW DISCIPLINE
- A row = ONE real study comparison: a focal taxon, measured by one method, under one
  wildflower intervention, compared against one control type. Output one row per REAL
  distinct combination that the paper actually analyses.
- A paper usually yields several rows (multiple taxa, or multiple control types). But do
  NOT invent rows by crossing every taxon x method x control. Only emit a row when all
  fields are clearly linked in the same analysis.
- If the SAME taxon was compared against TWO different control types, output TWO rows
  (same taxon, different control_type).
- The single supporting_evidence must justify the WHOLE row, not separate facts.
- If something is uncertain, lower confidence and write it in notes_on_ambiguity instead
  of spawning an extra row.
- GRANULARITY (split vs lump) — match the paper's ANALYSIS, not the taxa it mentions:
    * Split into separate taxon rows ONLY when the paper reports/analyses those taxa
      SEPARATELY (separate abundance/diversity results per taxon).
    * If the paper POOLS several groups into ONE combined response (e.g. "total arthropod
      abundance", "overall invertebrate richness"), output a SINGLE row with the broad label
      ("arthropods", "invertebrates", "insects") and, if several techniques were combined,
      sampling_method = "mixed methods". Do not split a pooled analysis into many rows.
CONTROLLED VOCABULARY — choose values ONLY from these exact labels.
taxon_common — YOU MUST choose EVERY value ONLY from this exact list. NEVER output any
label that is not on this list.
  amphibians; ants; aphids; arthropods; bacteria; bats; bees;
  beetles - ground beetles; beetles - other beetles; beetles; birds; butterflies; bugs;
  flies - hoverflies; flies - other flies; fungi; insects; invertebrates; mammals;
  nematodes; orthoptera; other; plants; reptiles; spiders; wasps
CHOOSING THE RIGHT LEVEL (main source of error — read carefully):
- This list has BOTH broad pooled labels (arthropods, invertebrates, insects) AND specific
  groups (spiders, bees, aphids, beetles - ground beetles, ...).
- Match the level to HOW THE PAPER REPORTS ITS RESULTS:
    * If the paper reports ONE POOLED measure across several groups (e.g. "total arthropod
      abundance", "overall invertebrate richness"), use the BROAD label
      (arthropods / invertebrates / insects). Do NOT split it into sub-groups.
    * If the paper reports groups SEPARATELY, use the SPECIFIC label for each.
STRICT INCLUSION RULE (avoid listing too many taxa — THIS IS THE MOST COMMON ERROR):
- Record a taxon ONLY if the paper reports a SEPARATE result or statistical analysis for it
  (its own abundance/diversity figure, its own table row, or its own model).
- Do NOT record taxa that are mentioned only in the introduction, the study-site
  description, the methods, or as incidental/background examples.
- When the paper analyses a POOLED response, record ONE broad label only
  (arthropods / invertebrates / insects) — NOT the individual sub-groups.
- If you are unsure whether to include a taxon, LEAVE IT OUT.
  Fewer, correct taxa are always better than many speculative ones.
MAPPING (never invent a name — always map to a label on the list):
  ladybugs/ladybirds -> "beetles - other beetles"; ground beetles/carabids ->
  "beetles - ground beetles"; hoverflies -> "flies - hoverflies";
  leafhoppers/planthoppers -> "bugs"; cabbage root fly/leafminers -> "flies - other flies";
  mites -> "other"; hamster -> "mammals";
  any unlisted pest/species name -> map to its group label, or "other" if none fits.
  NEVER output an unlisted term (e.g. NOT "fruit pests", NOT "leafminers", NOT "mites",
  NOT a raw species name).
SCIENTIFIC (LATIN) NAMES — papers often name organisms in Latin, not common names.
Recognise them and map to the correct common label from the list above.
- Latin-name FORMAT features to look for:
    * Species = TWO words: Genus (Capitalised) + species (lowercase), often italicised,
      e.g. "Apis mellifera", "Bombus terrestris", "Pardosa agrestis".
    * Family names end in -IDAE (e.g. Carabidae, Syrphidae, Lycosidae, Coccinellidae).
    * Order names: Coleoptera, Hymenoptera, Diptera, Araneae, Lepidoptera,
      Orthoptera, Hemiptera.
- Map the Latin name to the COMMON label, e.g.:
    Apis / Bombus / Andrena / Apidae -> "bees";  Vespidae / parasitoid wasps -> "wasps"
    Syrphidae -> "flies - hoverflies";  other Diptera -> "flies - other flies"
    Carabidae -> "beetles - ground beetles";  Coccinellidae / other beetle families -> "beetles - other beetles"
    Araneae / Lycosidae / Linyphiidae -> "spiders";  Aphididae / Aphis -> "aphids"
    Orthoptera / Acrididae / Tettigoniidae -> "orthoptera"
    Lepidoptera (butterflies) -> "butterflies";  Hemiptera (true bugs) -> "bugs"
- ALWAYS output the COMMON label from the list, NEVER the Latin name itself.
- If a Latin name maps to a group not clearly on the list, use the nearest broader label
  (e.g. "insects", "arthropods") or "other".
sampling_method (the method tied to THAT taxon's measurements; not every technique named):
  acoustic monitoring; beating; camera trapping; capture-mark-recapture; DNA; Malaise trap;
  mist net; mixed methods; nest box / trap nests; not specified; other; pan trap;
  pitfall trap; soil sampling; sticky trap; sweep net; timed point observations; transect;
  trapping; vacuum / suction
  (If two techniques were combined for one taxon, use "mixed methods". There is NO
   "direct observation / timed count" label — use "timed point observations" or "transect".)
intervention_level_3 (the SOWN WILDFLOWER treatment being evaluated — never a control):
  Wildflower margins; Wildflower strips; Wildflower areas;
  Flower beds or planters; Semi-natural grassland; Grass margins; Other - <short phrase>
  - "Wildflower margins" = new sown wildflower strip specifically along a FIELD EDGE / boundary.
  - "Wildflower strips"  = new sown wildflower STRIP within or through a crop field / verge
                           (linear, in an arable context).
  - "Wildflower areas"   = sown wildflower as a 2-D unit: plots, blocks, patches, islands,
                           whole fields, urban areas. Experimental "buffer-strip" treatments
                           laid out as sown PLOTS within BLOCKS are coded "Wildflower areas".
  Decide by the experimental layout, NOT by the single word "strip" in the title.
control_type_level_1 (the broad comparator category for THIS row):
  impermeable surface; bare earth; green - low diversity; green - medium diversity;
  positive control; other
control_type_level_2 (the specific comparator habitat for THIS row):
  cereal crop; other crop; improved pasture; golf course; lawn; unimproved grassland; other
  (e.g. conventional wheat field -> level_1 "green - low diversity", level_2 "cereal crop";
   grassy field margin / unimproved grass margin -> "green - medium diversity",
   "unimproved grassland"; sown competitive grasses / mown grass sward -> "green - low
   diversity", "improved pasture"; mown amenity lawn -> "green - low diversity", "lawn".)
description_of_control (FREE TEXT — the paper's own description of the control/comparator):
  - Give the authors' description of the control, short and faithful to the paper. This is
    useful EVEN WHEN control_type is already chosen, e.g. "wheat fields sown with Triticum
    aestivum, conventional management"; "grassy field margins bordering wheat fields, mown
    once during sampling"; "paired agricultural field of comparable size"; "plots sown with a
    grass-only seed mixture".
  - NEVER invent detail. If the paper gives no description of the control beyond the
    control_type labels, return "Not explicitly stated".
CONFIDENCE
  High = value stated almost verbatim and the row combination is clear.
  Medium = you had to map wording to a controlled label or combine statements.
  Low = ambiguous taxon, unclear method, torn between strips/areas/margins, or no clean fit.
  Do NOT mark everything High.
REFERENCE EXAMPLES — verified gold-standard codings. Follow the SAME conventions
(label choices, strips-vs-areas logic, method-per-taxon, one row per control type):
Haenke et al. 2009 (hoverflies in sown wildflower strips along wheat fields):
[{"row_id":1,"taxon_common":"flies - hoverflies","sampling_method":"sweep net","intervention_level_3":"Wildflower strips","control_type_level_1":"green - low diversity","control_type_level_2":"cereal crop","description_of_control":"Not explicitly stated","supporting_evidence":"hoverflies sweep-netted in wildflower strips vs cereal fields","confidence":"High","notes_on_ambiguity":""}]
Rischen et al. 2022 (spiders; sampled by combined pitfall+suction = mixed methods; TWO controls):
[{"row_id":1,"taxon_common":"spiders","sampling_method":"mixed methods","intervention_level_3":"Wildflower areas","control_type_level_1":"green - low diversity","control_type_level_2":"cereal crop","description_of_control":"wheat fields sown with Triticum aestivum (conventional management: fertiliser, fungicide, herbicide)","supporting_evidence":"spiders in wildflower areas vs conventional wheat fields","confidence":"High","notes_on_ambiguity":""},
 {"row_id":2,"taxon_common":"spiders","sampling_method":"mixed methods","intervention_level_3":"Wildflower areas","control_type_level_1":"green - medium diversity","control_type_level_2":"unimproved grassland","description_of_control":"grassy field margins bordering wheat fields (mown once during sampling)","supporting_evidence":"spiders in wildflower areas vs grassy field margins","confidence":"High","notes_on_ambiguity":"same taxon, second control type -> separate row"}]
Pollier et al. 2019 (4 taxa; ground beetles by pitfall, the rest by timed point observations):
[{"row_id":1,"taxon_common":"aphids","sampling_method":"timed point observations","intervention_level_3":"Wildflower strips","control_type_level_1":"green - low diversity","control_type_level_2":"improved pasture","description_of_control":"sown competitive grasses","supporting_evidence":"aphids counted in flower strips vs sown grass control","confidence":"High","notes_on_ambiguity":""},
 {"row_id":2,"taxon_common":"flies - hoverflies","sampling_method":"timed point observations","intervention_level_3":"Wildflower strips","control_type_level_1":"green - low diversity","control_type_level_2":"improved pasture","description_of_control":"sown competitive grasses","supporting_evidence":"hoverflies counted in strips vs sown grass","confidence":"High","notes_on_ambiguity":""},
 {"row_id":3,"taxon_common":"beetles - ground beetles","sampling_method":"pitfall trap","intervention_level_3":"Wildflower strips","control_type_level_1":"green - low diversity","control_type_level_2":"improved pasture","description_of_control":"sown competitive grasses","supporting_evidence":"carabids pitfall-trapped in strips vs sown grass","confidence":"High","notes_on_ambiguity":"only ground beetles use pitfall; others use timed counts"},
 {"row_id":4,"taxon_common":"beetles - other beetles","sampling_method":"timed point observations","intervention_level_3":"Wildflower strips","control_type_level_1":"green - low diversity","control_type_level_2":"improved pasture","description_of_control":"sown competitive grasses","supporting_evidence":"other beetles counted in strips vs sown grass","confidence":"Medium","notes_on_ambiguity":""}]
Westbury et al. 2017 (sown plots in blocks despite "buffer strip" wording -> Wildflower areas):
[{"row_id":1,"taxon_common":"beetles - other beetles","sampling_method":"vacuum / suction","intervention_level_3":"Wildflower areas","control_type_level_1":"green - low diversity","control_type_level_2":"improved pasture","description_of_control":"plots sown with a grass-only seed mixture","supporting_evidence":"beetles suction-sampled in sown plots vs grass-only plots within blocks","confidence":"High","notes_on_ambiguity":"'buffer strip' plots arranged in blocks -> coded Wildflower areas, not strips"}]
Nilsson et al. 2011 (survey coded as transect, not the traps used):
[{"row_id":1,"taxon_common":"flies - other flies","sampling_method":"transect","intervention_level_3":"Wildflower strips","control_type_level_1":"green - low diversity","control_type_level_2":"other","description_of_control":"Not explicitly stated","supporting_evidence":"flies surveyed along transects at wildflower strips","confidence":"Medium","notes_on_ambiguity":"survey coded 'transect' even though traps are mentioned"}]
Fischer 2016 (timed counts coded as transect; paired-field control; wildflower fields -> areas):
[{"row_id":1,"taxon_common":"mammals","sampling_method":"transect","intervention_level_3":"Wildflower areas","control_type_level_1":"green - low diversity","control_type_level_2":"cereal crop","description_of_control":"paired with an agricultural field of comparable size","supporting_evidence":"mammals surveyed along transects in wildflower fields vs paired arable fields","confidence":"Medium","notes_on_ambiguity":"coded 'transect'; wildflower fields -> areas"}]
OUTPUT
Return ONLY a valid JSON array, ONE OBJECT PER ROW, no preamble, no markdown fences.
row_id is an integer; all other values are quoted strings. Each object exactly:
{"row_id":<int>,"taxon_common":"...","sampling_method":"...","intervention_level_3":"...",
 "control_type_level_1":"...","control_type_level_2":"...","description_of_control":"...",
 "supporting_evidence":"<=25 words","confidence":"High|Medium|Low","notes_on_ambiguity":"..."}
)---"

# 2 Simplified extraction prompt (paper-level flower yes/no) 
flower_prompt <- r"---(
You are an experienced human coder for a systematic ecological meta-analysis.
From the SINGLE paper below, make ONE simplified judgement about the intervention tested.
QUESTION
Does the study's intervention involve FLOWER PLANTING / deliberate floral resource addition?
ANSWER (choose exactly one):
- "Yes"  = the intervention is a sown/planted flower treatment. This covers:
           Wildflower margins; Wildflower strips; Wildflower areas;
           Flower beds or planters; any other deliberate sowing/planting of flowers
           or flower-rich seed mixes to add floral resources.
- "No"   = the intervention is NOT flower planting. This INCLUDES:
           Semi-natural grassland; Grass margins; grass-only sowing; grazing; mowing;
           hedgerows; and any other agri-environment / grassland intervention with no
           deliberate flower sowing or planting.
- "Unclear" = the paper does not give enough information to decide.
RULES
- Judge only the INTERVENTION/TREATMENT being evaluated, not flowers mentioned only in
  the background, study site, or discussion.
- Naturally occurring flowers with no deliberate sowing/planting = "No".
- IMPORTANT: "Semi-natural grassland" and grass-only treatments are "No", even though
  they may sound habitat-related. Flower planting requires deliberate FLOWER sowing/planting.
- If the paper tests several treatments and at least one is deliberate flower planting,
  answer "Yes" and note the mix in notes_on_ambiguity.
- Base the answer ONLY on the paper text. Never invent detail.
CONFIDENCE
  High = the intervention is stated almost verbatim and clearly is/ isn't flower planting.
  Medium = you had to interpret wording to decide.
  Low = genuinely borderline (e.g. mixed grass+flower, vague "habitat enhancement").
  Do NOT mark everything High.
OUTPUT
Return ONLY a valid JSON object, no preamble, no markdown fences. Exactly:
{"flower_planting":"Yes|No|Unclear","intervention_described":"<short phrase naming the actual treatment>","supporting_evidence":"<=25 words quote or paraphrase","confidence":"High|Medium|Low","notes_on_ambiguity":"..."}
)---"
