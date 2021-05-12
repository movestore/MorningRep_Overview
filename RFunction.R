library('move')
library('foreach')
library('lutz')
library('sf')
library('grid')
library('gridExtra')

rFunction = function(time_now=NULL, volt_name=NULL, mig7d_dist, dead7d_dist, data, ...) {
  
  if (is.null(time_now)) time_now <- Sys.time() else time_now <- as.POSIXct(time_now,format="%Y-%m-%dT%H:%M:%OSZ",tz="GMT")
  
  data_spl <- move::split(data)
  ids <- namesIndiv((data))
  tags <- foreach(datai = data_spl, .combine=c) %do% {
    datai@data$tag_local_identifier[1]
  }
  time0 <- foreach(datai = data_spl, .combine=c) %do% {
    as.character(min(timestamps(datai)))
  }
  timeE <- foreach(datai = data_spl, .combine=c) %do% {
    as.character(max(timestamps(datai)))
  }
  timeE_local <- foreach(datai = data_spl, .combine=c) %do% {
    timeEi <- max(timestamps(datai))
    coo <- coordinates(datai[timestamps(datai)==timeEi][1,])
    timeEi_tz <- lutz::tz_lookup_coords(coo[,2],coo[,1], method="accurate")
    timeEi_offset <- lutz::tz_offset(as.Date(timeEi),timeEi_tz)
    as.character(as.POSIXct(timeEi)+(timeEi_offset$utc_offset_h*3600))
  }
  
  event <- foreach(datai = data_spl, .combine=c) %do% {
    ix <- which(timestamps(datai) <= time_now & timestamps(datai) >= time_now-(7*24*60*60))
    if (length(ix)>0) 
    {
      datai7d <- datai[ix,]
      meanlon <- mean(coordinates(datai7d)[,1])
      meanlat <- mean(coordinates(datai7d)[,2])
      if (any(distVincentyEllipsoid(coordinates(datai7d),c(meanlon,meanlat))>mig7d_dist))
      {
        "migration"
      } else if (all(distVincentyEllipsoid(coordinates(datai7d),c(meanlon,meanlat))<dead7d_dist))
      {
        "dead"
      } else "-"
    } else "no data"
  }
  
  posis24h <- foreach(datai = data_spl, .combine=c) %do% {
    ix <- which(timestamps(datai) <= time_now & timestamps(datai) >= time_now-(24*60*60))
    length(ix)
  }
  posis7d <- foreach(datai = data_spl, .combine=c) %do% {
    ix <- which(timestamps(datai) <= time_now & timestamps(datai) >= time_now-(7*24*60*60))
    length(ix)
  }
  displ24h <- foreach(datai = data_spl, .combine=c) %do% {
    ix <- which(timestamps(datai) <= time_now & timestamps(datai) >= time_now-(24*60*60))
    if (length(ix)>0) paste(round(sum(distance(datai[ix,]))/1000,digits=3),"km") else NA
  }
  displ7d <- foreach(datai = data_spl, .combine=c) %do% {
    ix <- which(timestamps(datai) <= time_now & timestamps(datai) >= time_now-(7*24*60*60))
    if (length(ix)>0) paste(round(sum(distance(datai[ix,]))/1000,digits=3),"km") else NA
  }
  
  if (is.null(volt_name))
  {
    voltE <- rep(NA,length(ids))
    logger.info("No specification of voltage variable given, thus NA returned in voltage column of the overview table.")
  } else if (volt_name %in% names(data))  
  {
    voltE <- foreach(datai = data_spl, .combine=c) %do% {
      tail(datai@data[,volt_name],1)}
  } else 
  {
    voltE <- rep(NA,length(ids))
    logger.info("Your provided tag voltage variable name does not exist in the data. Please double check and try again. NAs are returned in the voltage column of your overview table.")
  }

  overview <- data.frame(ids,tags,time0,timeE,timeE_local,voltE,posis24h,posis7d,displ24h,displ7d,event)
  names(overview) <- c("Animal","Tag","First timestamp","Last timestamp","Last timestamp local tz","Tag voltage","N posi. 24h","N posi. 7d","Moved dist. 24h","Moved dist. 7d","Event 7d")
  
  mytheme <- gridExtra::ttheme_default(
    core = list(fg_params=list(cex = 0.7)),
    colhead = list(fg_params=list(cex = 0.7)),
    rowhead = list(fg_params=list(cex = 0.65)))
  tg <- tableGrob(overview, rows = seq_len(nrow(overview)),theme=mytheme)
  
  fullheight <- convertHeight(sum(tg$heights), "cm", valueOnly = TRUE)
  margin <- unit(0.51,"in")
  margin_cm <- convertHeight(margin, "cm", valueOnly = TRUE)
  a4height <- 21 - margin_cm #landscape
  nrows <- nrow(tg)
  npages <- ceiling(fullheight / a4height)
  
  heights <- convertHeight(tg$heights, "cm", valueOnly = TRUE) 
  rows <- cut(cumsum(heights), include.lowest = FALSE,
              breaks = c(0, cumsum(rep(a4height, npages))))
  
  groups <- split(seq_len(nrows), rows)
  
  gl <- lapply(groups, function(id) tg[id,])
  
  
  pdf(paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"),"MorningReport_overviewTable.pdf"), paper = "a4r", width = 0, height = 0)
  #pdf("MorningReport_overviewTable.pdf", paper = "a4r", width = 0, height = 0)
  for(page in seq_len(npages)){
    grid.newpage()
    grid.rect(width=unit(29.7,"cm") - margin,
              height=unit(21,"cm")- margin)
    grid.draw(gl[[page]])
  }
  dev.off()
  
  return(data)
}
