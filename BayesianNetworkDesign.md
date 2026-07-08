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

With causation Q-LIG,Q-THUN -> F-LIG, and for the Genus node (G): G -> F-LIG. For instance P(F-LIG=Y|Q-LIG=Y,Q_THUN,G) = 0.9 while P(F-LIG=Y|Q-LIG=N,Q-THUN=Y,G) = 0.7. NB. The P values I give here are my own and should of course also depend on the probabilities currently in node G. The values should probably be determined in test cases.

And P(F-LIG=Y|G=Cb,Q-LIG,Q-THUN) = 0.4. Not every Cumulonimbus is producing lightning or thunder that is observable by the user, who might be some distance away.

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
        * Not-applicable

* Detected with a flattened appearance (Possible). This is only possible with a Cumulus cloud (Cu). The base is often (but not necessarily) a bit darker. The question should be something like:
    * Q-FLAT: Does the cloud have a flattened base?  States:
        * Yes
        * No
        * Not-applicable

* More or less developed vertically
    * Q-VERT: Does the cloud extend visibly vertically? States:
        * Yes - Detached
            * Possible for Ci, Cc, Ac, Sc
            * Usual for Cu and Cb
        * Yes - With a Common Base
            * Possible for Ci, Cc, Ac, Sc
        * No
        * Not-applicable
 
* Thin with detached fillaments
    * Q-FIL: Does the cloud appear thin with (hair-like) filaments?Description: The filaments should be (for the most part) distinct from one another. States:
        * Yes
            * Usual for Ci
        * No
        * Not-applicable

* Thin, grouped in sheaves, or ending in a hook or tuft
    * Q-SHE: Does the cloud appear grouped in sheaves? Description: Sheaves look like tightly bound bundles of wheat or tied ropes.
        * Yes -> Spissatus (spi)
            * Usual for Ci
        * No
        * Not-applicable
    * Q-HOOK: Do the filaments terminate in a hook or a tuft?
        * Yes -> Uncinus (unc)
            * Usual for Ci
        * No
        * Not-applicable

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
            * Q-VEIL
                * Yes -> not applicable
                * No -> can be applicable

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
            * Q-VEIL
                * Yes -> not applicable
                * No -> can be applicable
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

## Not-applicable relations
* Q-GRAN -> Q-SIZE
* Q-VEIL -> Q-SIZE
* Q-VEIL -> Q-GRAN
* Q-UNBA -> Q-RAGG