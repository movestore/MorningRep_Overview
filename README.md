## Morning Report Overview Table PDF
MoveApps

Github repository: *github.com/movestore/MorningRep_Overview*

## Description
This App provides the Morning Report Overview table as a PDF and csv download file. Given are for each track the timestamps of the first and last deployed position, the last tag voltage, the moved distance and number of positions during the last 24hours and 7days and an indication of migration or death event during the last 7 days. All you need when in the field looking for your animals. 

## Documentation
An overview table is generated as PDF and csv download: For each animal and tag the table shows the first and last timestamp, the last timestamp in local timezone (for convenience in the field), the last tag volatage and the number of positions and distance traveled during the last 24 hours or 7 days, respectively. If the animal was migrating, dead or had no data during the last 7 days then this event will be indicated.

### Application scope
#### Generality of App usability
This App was developed for any taxonomic group. 

#### Required data properties
The App should work for any kind of (location) data. Specially useful for live feed data.

### Input type
`move2::move2_loc`

### Output type
`move2::move2_loc`

### Artefacts
`MorningReport_overviewTable.pdf`: A simple overview table of the above specified data properties for each animal (row).
`MorningReport_overviewTable.csv`: A simple overview table of the above specified data properties for each animal (row).

### Settings 
**Reference time (`time_now`):** reference timestamp towards which all analyses are performed. Generally (and by default) this is NOW, especially if in the field and looking for one or the other animal or wanting to make sure that it is still doing fine. When analysing older data sets, this parameter can be set to other timestamps so that the number of positions, distance traveled and detected events can be calculated in relation to it.

**Voltage variable name (`volt_name`):** Tags of different manufacturers often return tag voltages with different column names. To allow for this flexibility the user has to exactly provide the name of this data attribute. Please be careful to account for possible points, underscores and capitalization. If unsure of attribute names or spelling, please run the previous App in your workflow and check the event_attributes in the App Output Details (green 'i'). For definitions of Movebank attributes please refer to the Movebank Attribute Dictionary (https://www.movebank.org/cms/movebank-content/movebank-attribute-dictionary). 

**Migration buffer (last 7 days) (`mig7d_distKM`):** user-defined distance that an animal of the respective species is expected to minimally move during up to 7 days during migration. This variable is used to define the event `migration` that is reported in the overview table. The default value is presently set to 100 km. Units Km

**Mortality buffer (last 7 days) (`dead7d_dist`):** user-defined distance that an animal of the respective species is expected to minimally move during 7 days if it is alive. Take into account the data resolution, which can also miss longer displacements. This variable is used to define the event `dead` that is reported in the overview table. The default value is presently set to 100 m. Units M

### Changes in output data
The input data remains unchanged.

### Most common errors

### Null or error handling
**Setting `time_now`:** If this parameter is left empty (NULL) the reference time is set to NOW. The present timestamp is extracted in UTC from the MoveApps server system.

**Setting `volt_name`:** If this parameter is left empty or the provided column name is not available in the data set, the volatege column in the overview table is set to NA. Respective warning messages are provided.

**Setting `mig7d_dist`:** The parameter has a explicit default value, so NULL or non-numeric values are not possible and will give an error.

**Setting `dead7d_dist`:** The parameter has a explicit default value, so NULL or non-numeric values are not possible and will give an error.