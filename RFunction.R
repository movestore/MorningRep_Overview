library('move2')
library("dplyr")
library("sf")
library("geosphere")
library('lutz')
library('grid')
library('gridExtra')

# data <- readRDS("./data/raw/input4_move2loc_LatLon.rds")
# time_now <- max(mt_time(data))
# names(data)
# volt_name <- "eobs_battery_voltage"
# mig7d_distKM <- 100
# dead7d_dist <- 100

rFunction = function(time_now=NULL, volt_name=NULL, mig7d_distKM, dead7d_dist, data) {
  
  Sys.setenv(tz="UTC")
  
  mig7d_dist <- mig7d_distKM*1000
  
  if (is.null(time_now)) time_now <- Sys.time() else time_now <- as.POSIXct(time_now,format="%Y-%m-%dT%H:%M:%OSZ",tz="UTC")
  
  if (is.null(volt_name)) {
    data$noVolt <- NA
    volt_name <- "noVolt"
    logger.info("No specification of voltage variable given, thus NA returned in voltage column of the overview table.")
  } 
  if (all(!is.null(volt_name) & !volt_name %in% names(data))){
    data$noVolt <- NA
    volt_name <- "noVolt"
    logger.info("Your provided tag voltage variable name does not exist in the data. Please double check and try again. NAs are returned in the voltage column of your overview table.")
  }
  
  # table parameters
  trkIDcolnm <- mt_track_id_column(data)
  ## get tag names or set to NA
  if(any(names(mt_track_data(data))=="tag_local_identifier")){
  }else{
    data <- data %>% mutate_track_data(tag_local_identifier=NA)
  }
  
  getoverview <- function(x){
    ## get local timezone for last position (probably posible to code more efficiently...)
    timeEi <- max(mt_time(x))
    coo <- st_coordinates(x %>% filter(mt_time()==max(mt_time())))
    timeEi_tz <- lutz::tz_lookup_coords(coo[,2],coo[,1], method="accurate")
    timeEi_offset <- lutz::tz_offset(as.Date(timeEi),timeEi_tz)
    locl_time <- as.character(timeEi+(timeEi_offset$utc_offset_h*3600))
    ## tracks of last 24h and last 7 days 
    trk24h <- x %>% filter(mt_time(x) <= time_now & mt_time(x) >= time_now-(24*60*60))
    trk7d <- x %>% filter(mt_time(x) <= time_now & mt_time(x) >= time_now-(7*24*60*60))
    
    df <- data.frame(
      ids=unique(mt_track_id(x)),
      tags=mt_track_data(x)$tag_local_identifier,
      time0=as.character(min(mt_time(x))),
      timeE=as.character(max(mt_time(x))),
      timeE_local=locl_time,
      voltE=pull(x,var=volt_name)[nrow(x)],
      posis24h=nrow(trk24h),
      posis7d=nrow(trk7d),
      displ24h=if(nrow(trk24h)==0){NA}else{paste(round(sum(mt_distance(trk24h),na.rm=T)/1000,digits=3),"km")},
      displ7d=if(nrow(trk7d)==0){NA}else{paste(round(sum(mt_distance(trk7d),na.rm=T)/1000,digits=3),"km")}
    )
    return(df)
  }
  
  overview_tb <- data%>%group_by(mt_track_id()) %>%
    group_modify(~getoverview(.x))
  overview_tb <- st_drop_geometry(overview_tb)
  overviewTB <- rename(overview_tb, {{trkIDcolnm}}:= 1)
  
  ## get animal status (probably took a coding detour)
  data <- dplyr::mutate(data, lon = st_coordinates(data)[,1], lat = st_coordinates(data)[,2])
  datai7d <-
    data %>%
    group_by(mt_track_id()) %>%
    filter(mt_time() <= time_now & mt_time() >= time_now-(7*24*60*60))%>% 
    reframe(
      meanlon = mean(lon),
      meanlat = mean(lat)
    )
  
  datai7d <- rename(datai7d, {{trkIDcolnm}}:= 1)
  data <- left_join(data,datai7d, by=trkIDcolnm)
  
  evnt <- function(x){
    if(!all(is.na(x$meanlat))){
      if (any(distVincentyEllipsoid(st_coordinates(x),c(unique(x$meanlon),unique(x$meanlat)))>(mig7d_dist*1000))){
        df <- data.frame(event="migration")
      } else if (all(distVincentyEllipsoid(st_coordinates(x),c(unique(x$meanlon),unique(x$meanlat)))<dead7d_dist )){
        df <- data.frame(event="dead")
      } else{df <- data.frame(event="-")}
    } else {df <- data.frame(event="no data")}
    return(df)
  }
  
  eventDF <- data %>%
    group_by(mt_track_id()) %>%
    group_modify(~evnt(.x))
  eventDF <- rename(eventDF, {{trkIDcolnm}}:= 1)
  
  ## join tables
  overviewTB <- left_join(overviewTB,eventDF, by=trkIDcolnm)
  overviewTB <- overviewTB %>% as_tibble() %>% select(-c(1)) # drop trkIDcolnm column used for joining
  overviewTB <- overviewTB %>% relocate(ids,tags,time0,timeE,timeE_local,voltE,posis24h,posis7d,displ24h,displ7d,event)
  
  ## "cheating" to achive a quicker fix. converting tibble to data.frame so the code below works. Will update gradually to tidyverse
  overviewDF <- as.data.frame(overviewTB)
  names(overviewDF) <- c("Animal","Tag","First timestamp UTC","Last timestamp UTC","Last timestamp local tz","Tag voltage","N posi. 24h","N posi. 7d","Moved dist. 24h","Moved dist. 7d","Event 7d")
  
  ## plot table
  mytheme <- gridExtra::ttheme_default(
    core = list(fg_params=list(cex = 0.7)),
    colhead = list(fg_params=list(cex = 0.7)),
    rowhead = list(fg_params=list(cex = 0.65)))
  
  tblG <- tableGrob(overviewDF, rows = NULL, theme =mytheme)# ttheme_minimal())
  fullwidth <- convertWidth(sum(tblG$widths), "cm", valueOnly = TRUE)
  fullheight <- convertHeight(sum(tblG$heights), "cm", valueOnly = TRUE)
  a4height <- 15 # leaving a margin
  a4width <- 25 # leaving a margin
  heights <- convertHeight(tblG$heights, "cm", valueOnly = TRUE)
  cumheight <- cumsum(heights)
  max_rows_per_page <- length(which(cumheight<a4height))
  max_rows_per_page_splt <- max_rows_per_page/2
  
  if(fullwidth>a4width){ 
    # Split the data into two parts
    table_top <- overviewDF[, 1:5] #"Animal","Tag","First timestamp UTC","Last timestamp UTC","Last timestamp local tz"
    table_bottom <- overviewDF[, c(1:2, 6:ncol(overviewDF))] #"Animal","Tag","Tag voltage","N posi. 24h","N posi. 7d","Moved dist. 24h","Moved dist. 7d","Event 7d"
    
    # Function to create a grob for a single table
    create_table_grob <- function(overviewDF, rows) {
      tableGrob(overviewDF[rows, ], rows = NULL, theme = mytheme)#ttheme_minimal())
    }
    
    if((fullheight*2)>a4height){  
      # split into multiple pages
      # Calculate the number of pages needed
      num_rows <- nrow(overviewDF)
      num_pages <- ceiling(num_rows/(max_rows_per_page_splt))
      
      plot_pages <- list()
      
      for (page in 1:num_pages) {
        start_row <- (page - 1) * max_rows_per_page_splt + 1
        end_row <- min(page * max_rows_per_page_splt, num_rows)
        
        # Create grobs for top and bottom tables, including column names
        top_page <- create_table_grob(table_top, c(0, start_row:end_row))
        bottom_page <- create_table_grob(table_bottom, c(0, start_row:end_row))
        
        # Combine top and bottom tables vertically
        page_grob <- arrangeGrob(top_page, bottom_page, ncol = 1, heights = c(0.5, 0.5))
        
        plot_pages[[page]] <- page_grob
      }
    }else{
      # Create grobs for top and bottom tables
      top_page <- create_table_grob(table_top, c(0:nrow(overviewDF)))
      bottom_page <- create_table_grob(table_bottom, c(0:nrow(overviewDF)))
      
      page_grob <- arrangeGrob(top_page, bottom_page, ncol = 1, heights = c(0.5, 0.5))
      
      plot_pages <- list()
      plot_pages[[1]] <- page_grob
    }
  }else{
    # one table
    if(fullheight>a4height){
      # split into multiple pages
      num_rows <- nrow(overviewDF)
      num_pages <- ceiling(num_rows/max_rows_per_page)
      
      # Function to create a grob for a single table
      create_table_grob <- function(overviewDF, rows) {
        tableGrob(overviewDF[rows, ], rows = NULL, theme =mytheme)# ttheme_minimal())
      }
      
      plot_pages <- list()
      
      for (page in 1:num_pages) {
        start_row <- (page - 1) * max_rows_per_page + 1
        end_row <- min(page * max_rows_per_page, num_rows)
        
        # Subset the grobs for the current page
        single_page <- tableGrob(overviewDF[c(0, start_row:end_row),], rows = NULL, theme = mytheme)# ttheme_minimal())
        plot_pages[[page]] <- single_page
      }
    }else{
      plot_pages <- list()
      plot_pages[[1]] <- tblG
    }
  }
  
  pdf(appArtifactPath("MorningReport_overviewTable.pdf"), width = 11.69, height = 8.27) # A4 size in landscape
  for (page in plot_pages) {
    grid.newpage()
    grid.draw(page)
  }
  dev.off()
  
  write.csv(overviewDF, row.names=F, file = appArtifactPath("MorningReport_overviewTable.csv"))
  
  return(data)
}
