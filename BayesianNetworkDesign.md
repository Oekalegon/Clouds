# Bayesian Network Design

## Network design
 
 Based on [Cloud Identification Guide](https://cloudatlas.wmo.int/en/cloud-identification-guide.html) and [Tabular Guide: Genus](https://cloudatlas.wmo.int/en/tabular-guide-genus.html) from the [International Cloud Atlas](https://cloudatlas.wmo.int/).

For identification we have one Genus node, that has a state for every Genus (Cl, Cc, Cs, Ac, As, Ns, Sc, St, Cu, and Cb). Its probability table will only have prior probabilities as every feature node will depend on this node, i.e. the genus causes a feature to be present, not the other way around. 

Correspondingly we will also have nodes for Species, Variety, Supplementary Features, and Associated Clouds.

A feature node is not used for the final identification of the genus (and later species, variety, etc) but to facilitate the classification in the Genus. A feature node can have an associated question or it may not. Feature nodes that have an associated question may have an additional state of 'not-applicable' (Na) next to the possible answer states for the question. The not-applicable state is used to mark a question as not applicable given previous evidence provided. E.g. If Cirrus is already very likely given evidence provided, we do not need to ask if lightning (never present in Cirrus) is seen.

## Genus identification

The following is a list of questions and nodes, primarily targeted towards genus identification. Many questions are based on: [Tabular Guide: Genus](https://cloudatlas.wmo.int/en/tabular-guide-genus.html). This table has four different possibilities for features being present with a cloud: 
* Essential (E): The feature is essential to the genus
* Usual (U): The feature is usual for the genus
* Possible (P): The feature is possible, occurring sometimes (maybe specific to species)
* Summit (S): The feature may occur only at the summit or upper position of the cloud (only for Cb)

The conditional probabilities should reflect the differences in likelyhood these different probabilities represent (with exception of the Summit value).

**Implementation note (calibration):** for a binary Yes/No question, a genus's label maps to a direct P(Yes|Genus) target: Essential ≈ 0.92, Usual ≈ 0.70, Possible/Summit ≈ 0.25, no label ≈ 0.05. An earlier attempt derived these from a weight *ratio* against a shared baseline instead, which collapsed Essential/Usual/Possible into an indistinguishable ~80-95%-Yes band and made "No" look like strong evidence for *any* completely unlabelled genus (worse than for a genus the guide documents as merely "Possible") — real test cases (a Nimbostratus/Altostratus confusion) exposed this, hence the switch to direct targets. Where a node has a "Not-applicable" state, this distribution is scaled down to leave room for it (e.g. a flat 5% baseline, or a larger, evidence-driven share where another question gates applicability — see the not-applicable relations below).

### Lightning/Thunder

In the Cloud Identification Guide](https://cloudatlas.wmo.int/en/cloud-identification-guide.html) flowchart there is a question 'Is lightning seen or thunder heard?', which is a clear indicator for Cumulonimbus (Cb). No other cloud will produce lightning or thunder, but the identification is not 100%, at least for thunder being heard. The thunder may not be associated with the cloud you are observing but with another cloud. The lightning can be seen to be associated with a specific cloud and if that is the cloud you are identifying, than that is a positive identification.

So we will split this up in two question nodes with an extra feature node.
```
1. Q-LIG: Is lightning seen to be associated with the cloud? States:
    * Yes
    * No
    * Not-applicable
2. Q-THUN: Is thunder heard? States:
    * Yes
    * No
    * Not-applicable
3. F-LIG: Lightning or thunder associated with the cloud. States:
    * Yes
    * No
```

**Implementation note:** the causation above was changed during implementation from `Q-LIG,Q-THUN -> F-LIG <- G` to `G -> F-LIG -> Q-LIG, Q-THUN`. With F-LIG as a collider between the two questions and G, F-LIG is never actually observed (there's no question for it), and an unobserved collider *blocks* evidence between its parents — so answering Q-LIG/Q-THUN would never have moved G's posterior at all. Making F-LIG a genuine intermediate cause (the true, unobserved state of whether lightning/thunder is associated with this cloud, which G determines and which in turn determines the noisy, sometimes-wrong answers a user gives) fixes this: it's a chain, not a collider, so evidence flows correctly through it without needing F-LIG itself to be observed.

As implemented: P(F-LIG=Yes|G=Cb) = 0.4 (not every Cumulonimbus is producing lightning or thunder observable by the user, who might be some distance away); P(F-LIG=Yes|G≠Cb) = 0.01 (no other genus produces it, but allow a small residual for reporting noise). Lightning is visually tied to "this" cloud, so false positives are rare; thunder can travel from an unrelated storm cell, so its false-positive rate is deliberately higher:
* P(Q-LIG=Yes|F-LIG=Yes) = 0.60, P(Q-LIG=No|F-LIG=Yes) = 0.35, P(Q-LIG=Not-applicable|F-LIG=Yes) = 0.05
* P(Q-LIG=Yes|F-LIG=No) = 0.02, P(Q-LIG=No|F-LIG=No) = 0.93, P(Q-LIG=Not-applicable|F-LIG=No) = 0.05
* P(Q-THUN=Yes|F-LIG=Yes) = 0.50, P(Q-THUN=No|F-LIG=Yes) = 0.45, P(Q-THUN=Not-applicable|F-LIG=Yes) = 0.05
* P(Q-THUN=Yes|F-LIG=No) = 0.15, P(Q-THUN=No|F-LIG=No) = 0.80, P(Q-THUN=Not-applicable|F-LIG=No) = 0.05

### Optical Thickness

These features can be bundled into one question:
* Q-OPT: Does the cloud appear thin, translucent, or opaque? States:
    * Thin. Description: The disc of the Sun or Moon can be seen through the cloud.
        * Usual for Ci and Cc
        * Essential for Cs
        * Possible for Ac, Sc, St and Cu
    * Translucent. Description: The position of the Sun or Moon can be determined, but not descernable disk is visible.
        * Usual for Ac and As
        * Possible for Ci, Cc, Sc, St, and Cu
    * Opaque
        * Usual for As and Ns
        * Possible for Ac, Sc, and Cb

### Shading

These features can be bundled into one question:
* Q-SHAD: Is any shading apparent in the cloud? States:
    * No shading
        * Essential for Cc
        * Usual for Ci and Cs
        * Possible for Ac, Sc, St, and Cu
    * Partly shaded
        * Usual for Ac, Sc, Cu, and Cb
    * Fully shaded. Description, the cloud has a greyish appearance throughout.
        * Usual for As, Ns, and St
        * Possible for Ac, Sc, and Cb

### Shape feature nodes

* Spread out as a veil totally or partially covering the sky
    * Q-VEIL: Is the cloud spread out like a veil, totally or partially covering the sky? Description: The cloud should appears as a continuous sheet or veil. The cloud can not be subdivided into elements or cloudlets, although shading can be different within the cloud. States:
        * Yes
            * Essential for Cs, As, and Ns
            * Usual for St
        * No

* Detected with a flattened appearance (Possible). This is only possible with a Cumulus cloud (Cu). The base is often (but not necessarily) a bit darker. The question should be something like:
    * Q-FLAT: Does the cloud have a flattened base?  States:
        * Yes
        * No

* More or less developed vertically
    * Q-VERT: Does the cloud extend visibly vertically? States:
        * Yes - Detached
            * Possible for Ci, Cc, Ac, Sc
            * Usual for Cu and Cb
        * Yes - With a Common Base
            * Possible for Ci, Cc, Ac, Sc
        * No
 
* Thin with detached fillaments
    * Q-FIL: Does the cloud appear thin with (hair-like) filaments?Description: The filaments should be (for the most part) distinct from one another. States:
        * Yes
            * Usual for Ci
        * No

* Thin, grouped in sheaves, or ending in a hook or tuft
    * Q-SHE: Does the cloud appear grouped in sheaves? Description: Sheaves look like tightly bound bundles of wheat or tied ropes.
        * Yes -> Spissatus (spi)
            * Usual for Ci
        * No

    * Q-HOOK: Do the filaments terminate in a hook or a tuft?
        * Yes -> Uncinus (unc)
            * Usual for Ci
        * No

#### Has Distinct Elements

**Added during implementation.** Real test cases showed Q-SIZE/Q-GRAN being asked (and forced to an answer) for clouds that aren't "elemental" at all but also aren't a veil: a single detached Cumulus, or a ragged Stratus sheet, both got dragged into one of Q-SIZE's size buckets, which then misidentified them as Stratocumulus. "Not a veil" (Q-VEIL) alone doesn't rule that out — a non-veil cloud can still be a single convective mass or an amorphous sheet rather than a patch of repeated elements. Per the Tabular Guide, being made of distinct, repeated elements is specifically Cc/Ac/Sc's defining structure, so this question — always answerable — replaces Q-VEIL as the real not-applicable gate for Q-GRAN/Q-SIZE below.

* Q-ELEM: Is the cloud made up of many distinct, separate elements or cloudlets, rather than one continuous mass? States:
    * Yes
        * Essential for Cc
        * Usual for Ac and Sc
    * No

#### Size

* Spread out in a patch, sheet or layer, subdivided into more or less regularly arranged layers or rounded masses, the apparent width of most elements being...
    * Q-SIZE: What is the size of any elements in the cloud? Description: If the cloud can be divided between distinct elements or cloudlets, what is the size of these elements. Measure this with an outstretched hand.
        * Less than 1° (< 1 finger)
            * Essential for Cc
        * Between 1° and 5° (1-3 fingers)
            * Usual for Ac
        * More than 5° (> 5 fingers)
            * Essential for Sc
        * Not-applicable
            * Q-GRAN
                * Yes -> applicable
                * No -> can be applicable
            * Q-ELEM
                * No -> not applicable
                * Yes -> can be applicable

### Structure and Texture

* Silky sheen
    * Q-SILK: Does (part of) the cloud have a silky sheen? States:
        * Yes 
            * Usual for Ci
            * Possible for Cc and Cs
        * Yes, at the summit
            * Possible for Cb cap - not for Cb Cal
        * No
* Fibrous (hair like)
    * Q-FIB: Does the cloud appear fibrous (hair like)? States:
        * Yes
            * Usual for Ci
            * Possible for Cs, Ac, and As
        * Yes, at the summit
            * Possible for Cb
        * No
* Granular
    * Q-GRAN: Does the cloud consist of many granular elements? States:
        * Yes
            * Usual for Cc
            * Possible for Ac
        * No
        * Not-applicable
            * Q-ELEM
                * No -> not applicable
                * Yes -> can be applicable
* Undulated or rippled. - Also important for determining varieties.
    * Q-UND: Has the cloud an undulated or rippled structure?
        * Yes
            * Usual for Cc
            * Possible for Cs, Ac, As, Sc, and St
* Ragged
    * Q-RAGG: Does the cloud have a ragged, torn appart or shreaded appearance?
        * Yes
            * Possible for St and Cu -> fra species
        * No
        * Not-applicable
            * Q-UNBA
                * Yes -> not applicable
* Uniform Base
    * Q-UNBA: Does the cloud have a uniform and flat base? Description: The cloud base occurs at a single, consistent altitude across the sky without any large, abrupt steps or physical breaks. Lower clouds can be present that may seem to break the uniformity but do not as they are distinct clouds.States: 
        * Yes
            * Usual in Cs, As, Ns, St, and Cu
            * Possible in Cb
        * No
* Diffuse Base
    * Q-DIFF: Does the cloud have a diffuse, blurry base? Description: The base is diffuse when the bottom and sides do not have sharp edge.
        * Yes
            * Usual for Ns
            * Possible for As, St, and Cb
        * No

## Species

## Variaties

## Supplementary features
A cloud can have multiple supplementary features, therefore, each supplementary feature has its own node. Each supplementary feature node is connected to the genus node, and each feature has one or more questions (G->F->Q).
NB. If an answer to a question for a feature is negative, this should not lower the likelyhood of associate genera by very much. I.e. If we do not see a Incus this does not mean a cloud is not Cb. It could very well be Cb cat. A positive identification is a much stronger clue than a negative one.

### Incus
* The upper portion of a Cumulonimbus spread out in the shape of an anvil with a smooth, fibrous or striated appearance
    * Q-INCU: Is the upper part of the cloud spread out in the shape of an anvil, with a smooth, fibrous, or striated appearance?
        * Yes
            * Possible for Cb (-> Cb cap)
        * No
        * Not-apllicable
            * Q-VERT
                * Yes -> applicable
                * No -> not applicable
            * Q-LIG
                * Yes -> applicable
                * No -> can be applicable
            * Q-THUN
                * Yes -> applicable
                * No -> can be applicable

### Mamma
* Hanging protuberances, like udders, on the under surface of a cloud.
    * Q-MAM: Are there any hanging protuberances, like udders, on the under surface of a cloud?
        * Yes
            * Possible for Ci, Cc, Ac, As, Sc, and Cb
        * No

### Virga
* Vertical or inclined trails of precipitation (fallstreaks) attached to the under surface of a cloud that do not reach the Earth’s surface.
    * Q-VIR: Are there trails of precipitation (streaks or a hazy curtain) hanging from the underside of the cloud that evaporate before reaching the ground? Description: Unlike ordinary precipitation, this trails off partway down rather than reaching the ground, sometimes visibly bending with the wind.
        * Yes
            * Usual for As and Ns
            * Possible for Cc, Ac, Sc, Cu, and Cb
        * No

### Precipitation (Praecipitatio)

**Added during implementation.** Precipitation (rain, drizzle, snow, ice pellets, hail, etc.) falling from a cloud and reaching the Earth's surface — continuous rain or snow reaching the ground is Nimbostratus's actual defining feature per the Tabular Guide, the "rain cloud" genus, but nothing in the questions above captured it directly, so Ns kept winning over Altostratus on weaker, shared secondary features (a diffuse base, a uniform base) alone.

Whether it falls uniformly (from a layered cloud, intermittent or continuous) or as showers (from a convective cloud, usually shorter and heavier) is itself a useful genus signal, so this is one three-way question rather than a plain Yes/No.

* Q-PRECIP: Does the cloud appear to be producing rain or snow that reaches the ground? Description: Look for streaks or a hazy curtain falling from the cloud's base and reaching the surface. If it trails off and evaporates before reaching the ground, that is not considered percipitation. States:
    * No
    * Yes - Uniform (intermittent or continuous)
        * Usual for Ns
        * Possible for As, Sc, and St
    * Yes - Showers
        * Possible for Cu
        * Usual for Cb

### Arcus
* A dense, horizontal roll with more or less tattered edges, situated on the lower front part of certain clouds and having, when extensive, the appearance of a dark, menacing arch.
    * Q-ARCUS: Is there a dense, horizontal roll of cloud with ragged edges along the lower front of the cloud, appearing (when well developed) as a dark, menacing arch?
        * Yes
            * Possible for Cb and Cu, but noticeably more likely for Cb than for Cu — when building the CPT, don't use the same flat "Possible" P(Yes) for both; give Cb a higher value than Cu here.
        * No

### Tuba
* Cloud column or inverted cloud cone, protruding from a cloud base; it constitutes the cloudy manifestation of a more or less intense vortex.
    * Q-TUBA: Is there a cloud column or inverted cone hanging from the cloud's base?
        * Yes
            * Possible for Cb and Cu, but noticeably more likely for Cb than for Cu — same asymmetry as Arcus; give Cb a higher P(Yes) than Cu in the CPT rather than using the same flat "Possible" value for both.
        * No

### Asperitas
* Well-defined, wave-like structures in the underside of the cloud; more chaotic and with less horizontal organization than the variety undulatus. Asperitas is characterized by localized waves in the cloud base, either smooth or dappled with smaller features, sometimes descending into sharp points, as if viewing a roughened sea surface from below. Varying levels of illumination and thickness of the cloud can lead to dramatic visual effects.
    * Q-ASPER: Does the underside of the cloud show well-defined, chaotic, wave-like structures, as if viewing a roughened sea surface from below?
        * Yes
            * Possible for Sc and Ac
        * No

### Murus
* A localized, persistent, and often abrupt lowering of cloud from the base of a Cumulonimbus, from which tuba (spouts) sometimes form. Usually associated with a supercell or severe multicell storm; typically develops in the rain-free portion of a Cumulonimbus and indicates an area of strong updraft. Murus showing significant rotation and vertical motion may result in the formation of tuba. Commonly known as a "wall cloud".
    * Q-MURUS: Is there a localized, persistent, often abrupt lowering of cloud from the cloud's base, typically in a rain-free area?
        * Yes
            * Possible for Cb
        * No

### Cauda
* A horizontal, tail-shaped cloud (not a funnel) at low levels extending from the main precipitation region of a supercell Cumulonimbus to the murus (wall cloud). It is typically attached to the wall cloud, and the bases of both are typically at the same height. Cloud motion is away from the precipitation area and towards the murus, with rapid upward motion often observed near the junction of the tail and wall clouds. Commonly known as a "tail cloud".
    * Q-CAUDA: Is there a horizontal, tail-shaped cloud (not a funnel) extending away from the cloud at a low level, typically with its base at the same height as the cloud it's attached to?
        * Yes
            * Possible for Cb
        * No

### Cavum
* A well-defined, generally circular (sometimes linear) hole in a thin layer of supercooled water droplet cloud. Virga or wisps of Cirrus typically fall from the central part of the hole, which generally grows larger with time. Cavum is typically a circular feature when viewed from directly beneath, but may appear oval shaped when viewed from a distance. When resulting directly from the interaction of an aircraft with the cloud, it is generally linear (in the form of a dissipation trail), with virga typically falling from the progressively widening trail.
    * Q-CAVUM: Is there a well-defined, generally circular (sometimes linear) hole in the cloud layer, often with wisps of cloud or fall-streaks trailing from its centre?
        * Yes
            * Possible for Ac and Cc, and rarely for Sc — give Sc a lower P(Yes) than Ac/Cc in the CPT rather than the same flat "Possible" value.
        * No

### Fluctus
* A relatively short-lived wave formation, usually on the top surface of the cloud, in the form of curls or breaking waves (Kelvin-Helmholtz waves).
    * Q-FLUCTUS: Is there a short-lived wave formation on the top surface of the cloud, in the form of curls or breaking waves, like breaking ocean waves?
        * Yes
            * Possible for Ci, Ac, Sc, and St, and occasionally for Cu — give Cu a lower P(Yes) than the others in the CPT rather than the same flat "Possible" value.
        * No

## Accessory clouds
A cloud can have multiple accessory clouds, therefore, each  accessory cloud has its own node. Each  accessory cloud node is connected to the genus node, and each accessory cloud has one or more questions (G->Ac->Q).

### Pileus
* An accessory cloud of small horizontal extent, in the form of a cap or hood above the top or attached to the upper part of a cumuliform cloud that often penetrates it. Several pileus may fairly often be observed in superposition.
    * Q-PILEUS: Is there a small cap or hood of cloud above the top of, or attached to the upper part of, the cloud, which the cloud often appears to be pushing up into or through?
        * Yes
            * Possible for Cu and Cb
        * No

### Velum
* An accessory cloud veil of great horizontal extent, close above or attached to the upper part of one or several cumuliform clouds that often pierce it.
    * Q-VELUM: Is there a veil of cloud of great horizontal extent close above or attached to the upper part of the cloud, which the cloud often appears to be piercing through?
        * Yes
            * Possible for Cu and Cb
        * No

### Pannus
* Ragged shreds, sometimes constituting a continuous layer, situated below another cloud and sometimes attached to it.
    * Q-PANNUS: Are there ragged shreds of cloud, sometimes forming a continuous layer, hanging below (and sometimes attached to) the cloud?
        * Yes
            * Usual for Ns and Cb
            * Possible for As and Cu
        * No

### Flumen
* Bands of low clouds associated with a supercell severe convective storm (Cumulonimbus), arranged parallel to the low-level winds and moving into or towards the supercell. These form on an inflow band into a supercell storm along the pseudo-warm front, with the cloud elements moving towards the updraft, the base being at about the same height as the updraft base. Unlike cauda, flumen are not attached to the murus (wall cloud), and the cloud base is higher than the wall cloud's. One particular type is the so-called "Beaver's tail": a relatively broad, flat inflow band suggestive of a beaver's tail.
    * Q-FLUMEN: Are there band-shaped low clouds running parallel to the low-level wind and moving into the cloud, not attached to it and with a higher base?
        * Yes
            * Possible for Cb
        * No


## Not-applicable relations
* Q-GRAN -> Q-SIZE
* Q-ELEM -> Q-SIZE
* Q-ELEM -> Q-GRAN
* Q-UNBA -> Q-RAGG
* Q-VERT -> Q-INCU
* Q-LIG -> Q-INCU
* Q-THUN -> Q-INCU