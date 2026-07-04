# Clouds

Clouds is an iOS app that helps users identify the genus, species, varieties and special features of clouds.
User's are asked questions and based on the answers, the system comes to a most likely identification of the cloud. The questions will be accompaninied by drawings that help the user to identify features.
The app also stores identifications (with location) to enable the user to keep a record of when cloud types appear. The user will also be able to store pictures of the clouds together with their identification.

## App UI
* Main screen shows a history of cloud observations, subdivided by day, week, month, year.
* The main screen has an 'Identify' button the start the identification process that will pop up a popover view showing the first question. This view shows a question with optional description, buttons for the possible answers and an image in the background. When a user has answered a question, the next question is presented. The user should be able to go back and forward in past questions, so that answers can be changed.

## Engine
The core of the identification engine is a Bayesian Network with nodes for each classification (e.g. genus, species, variety, ...), and for each question.
The Bayesian Network (nodes, edges, and CPTs) is stored in JSON files in the project and included in the app to be read when the app starts.

Questions each have their own JSON file with an ID that is referenced in the Bayesian Network file. These Question JSON files will have the text of the question, an optional description, a link to an image, and the possible answers to the question. The answers all have an ID that is reused as the state ID in the Bayesian Network.

The Bayesian Network will initially not use junction trees to calculate the probabilities when evidence is supplied, but use a brute force approach.

## References
* The International Cloud Atlas: https://cloudatlas.wmo.int/en/home.html
* Cloud Classification Summary table: https://cloudatlas.wmo.int/en/cloud-classification-summary.html
* Genus identification table from the International Cloud Atlas: https://cloudatlas.wmo.int/en/tabular-guide-genus.html