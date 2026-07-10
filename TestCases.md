# 8 July


## 1 

let evidence: [NodeID: StateID] = ["Shading": "PartlyShaded", "UniformBase": "No", "ElementSize": "MoreThanFiveDegrees", "Undulated": "No", "DiffuseBase": "No", "ThinFilaments": "No", "Ragged": "Yes", "FlattenedBase": "No", "Granular": "No", "VerticalDevelopment": "YesDetached", "OpticalThickness": "Opaque", "LightningSeen": "No", "Fibrous": "No", "SilkySheen": "No", "ThunderHeard": "No", "SpreadAsVeil": "No", "Sheaves": "No", "HookOrTuft": "No"]
// Posterior: Stratocumulus: 80.8%, Cumulus: 13.2%, Cumulonimbus: 5.4%, Altocumulus: 0.6%, Nimbostratus: 0.0%, Stratus: 0.0%, Altostratus: 0.0%, Cirrocumulus: 0.0%, Cirrostratus: 0.0%, Cirrus: 0.0%

Incorrect - should be Stratus (fractus)

Observations: Why element size as 3rd question - we haven't established yet that there are elements...  This question should be less applicable until we know there are separate elements. (Is there a question about elements?)

## 2

let evidence: [NodeID: StateID] = ["Shading": "FullyShaded", "SpreadAsVeil": "Yes", "OpticalThickness": "Translucent", "Undulated": "No", "DiffuseBase": "Yes", "Fibrous": "No", "VerticalDevelopment": "No", "UniformBase": "Yes", "LightningSeen": "No", "FlattenedBase": "No", "SilkySheen": "No", "ThunderHeard": "No", "ThinFilaments": "No", "Sheaves": "No", "HookOrTuft": "No"]
// Posterior: Nimbostratus: 41.2%, Stratus: 34.4%, Altostratus: 24.2%, Cumulonimbus: 0.1%, Cumulus: 0.0%, Cirrostratus: 0.0%, Stratocumulus: 0.0%, Altocumulus: 0.0%, Cirrocumulus: 0.0%, Cirrus: 0.0%

Incorrect - should be Altostratus

Observation: Questions that are not relevant are asked like thunder, questions for cirrus clouds while it seems to be certain that it is neither Cb or Ci quite early on

## 3

let evidence: [NodeID: StateID] = ["Shading": "NoShading", "Granular": "Yes", "ElementSize": "LessThanOneDegree"]
// Posterior: Cirrocumulus: 90.4%, Cirrus: 4.8%, Altocumulus: 1.8%, Cumulus: 1.5%, Cirrostratus: 0.6%, Cumulonimbus: 0.4%, Stratus: 0.3%, Stratocumulus: 0.2%, Altostratus: 0.1%, Nimbostratus: 0.1%

Correct

## 4

let evidence: [NodeID: StateID] = ["Shading": "NoShading", "Granular": "No", "ThinFilaments": "Yes", "Sheaves": "No", "UniformBase": "No", "HookOrTuft": "Yes", "Undulated": "No"]
// Posterior: Cirrus: 96.6%, Stratocumulus: 1.4%, Cumulus: 0.8%, Cumulonimbus: 0.4%, Altocumulus: 0.3%, Cirrocumulus: 0.3%, Cirrostratus: 0.1%, Nimbostratus: 0.1%, Stratus: 0.0%, Altostratus: 0.0%

Correct

Observation: In my first try I came to Cirrocumulus because I it was not clear whether filaments are also elements. In the Cloud Atlas definition they apparently are not. We should make that clear in the question. This may be the question about whether there are any elements anyhow (see case 1)

## 5

let evidence: [NodeID: StateID] = ["Shading": "PartlyShaded", "UniformBase": "No", "ElementSize": "MoreThanFiveDegrees", "Undulated": "No", "DiffuseBase": "No", "HookOrTuft": "No", "Ragged": "No", "Granular": "No", "VerticalDevelopment": "YesDetached", "FlattenedBase": "Yes", "OpticalThickness": "Opaque", "LightningSeen": "No", "Fibrous": "No", "SilkySheen": "No", "ThunderHeard": "No", "SpreadAsVeil": "No", "ThinFilaments": "No", "Sheaves": "No"]
// Posterior: Stratocumulus: 80.8%, Cumulus: 13.2%, Cumulonimbus: 5.4%, Altocumulus: 0.6%, Nimbostratus: 0.0%, Altostratus: 0.0%, Cirrocumulus: 0.0%, Cirrostratus: 0.0%, Stratus: 0.0%, Cirrus: 0.0%

Incorrect: Should be Cumulus

Observation: It looks like the ElementSize question gets asked early on. There are no elements in Cumulus, except when you regard single Cumulus clouds as elements. There should be a clear definition of when it is an individual cloud, or multiple elements.