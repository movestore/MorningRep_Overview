## Morning Report pdf Overview
MoveApps

Github repository: *github.com/movestore/MorningRep_Overview*

## Description
This App provides the Morning Report Overview as PDF download file. Given are for each individual the timestamps of the first and last deployed position, the last tag voltage, the moved distance and number of positions during the last 24h and 7d and an indication of migration or death event during the last 7 days. All you need when in the field looking for your animals. 

## Documentation
An overview table is generated as PDF download: For each animal and tag the table shows the first and last timestamp, the last timestamp in local timezone (for convenience in the field), the last tag volatage and the number of positions and distance travelled during the last 24 hours or 7 days, respectively. If the animal was migrating, dead or had no data during the last 7 days then this event would be indicated.

### Input data
moveStack in Movebank format

### Output data
moveStack in Movebank format

### Artefacts
`MorningReport_overviewTable.pdf`: A simple overview table of the above specified data properties for each animal (row).

### Parameters 
`time_now`: reference timestamp towards which all analyses are performed. Generally (and by default) this is NOW, especially if in the field and looking for one or the other animal or wanting to make sure that it is still doing fine. When analysing older data sets, this parameter can be set to other timestamps so that the number of positions, distance travelled and detected events can be calculated in realtion to it.

`volt_name`: Tags of different manufacturers often return tag voltages with different column names. To allow for this flexibility the user has to exactly provide the name of this data attribute. Please be careful to account for possible points, underscores and capitalisation.

`mig7d_dist`: user-defined distance that an animal of the respecitve species is expected to minimally move during up to 7 days during migration. This variable is used to define the event `migration` that is reported in the overview table. The default value is presently set to 100000 m = 100 km.

`dead7d_dist`: user-defined distance that an animal of the respecitve species is expected to minimally move during 7 days if it is alive. Take into account the data resolution, which can also miss longer displacements. This variable is used to define the event `dead` that is reported in the overview table. The default value is presently set to 100 m.

### Null or error handling:
**Parameter `time_now`:** If this parameter is left empty (NULL) the reference time is set to NOW. The present timestamp is extracted in UTC from the MoveApps server system.

**Parameter `volt_name`:** If this parameter is left empty or the provided column name is not available in the data set, the volatege column in the overview table is set to NA. Respective warning messages are provided.

**Parameter `mig7d_dist`:** The parameter has a explicit default value, so NULL or non-numeric values are not possible and will give an error.

**Parameter `dead7d_dist`:** The parameter has a explicit default value, so NULL or non-numeric values are not possible and will give an error.

**Data:** The data are not manipulated in this App, but used to provide an overview table. So that a possible Workflow can be continued after this App, the input data set is returned.