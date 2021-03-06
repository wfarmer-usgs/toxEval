library(toxEval)
library(dplyr)
library(data.table)
library(tidyr)
library(ggplot2)
library(grid)
library(gridExtra)

source("getDataReady.R")

###########################################################################
# WQ boxplot
filePath <- file.path(pathToApp, "waterSamples.RData")
load(file=filePath)
waterSamples$site["USGS-04157005" == waterSamples$site] <- "USGS-04157000"
valColumns <- grep("valueToUse", names(waterSamples))
qualColumns <- grep("qualifier", names(waterSamples))
waterData <- waterSamples[,valColumns]
waterData[waterSamples[,qualColumns] == "<"] <- 0
wData <- cbind(waterSamples[,1:2],waterData)

wDataLong <- gather(wData, pCode, measuredValue, -ActivityStartDateGiven, -site) %>%
  rename(date = ActivityStartDateGiven) %>%
  filter(!is.na(measuredValue)) %>%
  mutate(pCode = gsub("valueToUse_", replacement = "", pCode)) %>%
  left_join(select(pCodeInfo, parameter_cd, casrn, class,parameter_nm,
                   # EEF_avg_in.vitro,EEF_max_in.vitro_or_in.vivo,
                   AqT_EPA_acute,AqT_EPA_chronic,
                   AqT_other_acute,AqT_other_chronic),
            by=c("pCode" = "parameter_cd")) %>%
  gather(endPoint, value, 
         # EEF_avg_in.vitro,EEF_max_in.vitro_or_in.vivo,
         AqT_EPA_acute,AqT_EPA_chronic,
         AqT_other_acute,AqT_other_chronic) %>%
  mutate(EAR =  measuredValue/value) %>%
  filter(!is.na(EAR)) 

waterSamplePCodes <- unique(wDataLong$pCode)

toxCastChems <- gather(ACC, endPoint, ACC, -casn, -chnm, -flags) %>%
  filter(!is.na(ACC)) %>%
  left_join(pCodeInfo[pCodeInfo$parameter_cd %in% waterSamplePCodes,c("casrn", "parameter_units", "mlWt")],
            by= c("casn"="casrn")) %>%
  filter(!is.na(parameter_units)) %>%
  select(casn, chnm) %>%
  distinct()

wDataLong <- wDataLong %>%
  left_join(toxCastChems, by=c("casrn"="casn")) %>%
  filter(!is.na(chnm)) %>%
  mutate(parameter_nm = chnm) %>%
  select(-chnm)

wDataLong$parameter_nm[wDataLong$parameter_nm == "4-(1,1,3,3-Tetramethylbutyl)phenol"] <- "4-tert-Octylphenol"

graphData.wq <- wDataLong %>%
  group_by(site,date,parameter_nm,class) %>%
  summarise(sumEAR=sum(EAR)) %>%
  data.frame() %>%
  group_by(site, parameter_nm,class) %>%
  summarise(meanEAR=max(sumEAR)) %>%
  data.frame() 

##################################################
# Regular toxEval stuff:
graphData <- graphData %>%
  mutate(category = as.character(category),
         guideline = "ToxCast")

graphData.full_WQ <- mutate(graphData.wq, class=as.character(class)) %>%
  rename(category = parameter_nm) %>%
  mutate(guideline = "Traditional")

graphData.full_WQ$class[graphData.full_WQ$class == "Detergent Metabolites"] <- "Detergent"

wDataLong_EQ <- gather(wData, pCode, measuredValue, -ActivityStartDateGiven, -site) %>%
  rename(date = ActivityStartDateGiven) %>%
  filter(!is.na(measuredValue)) %>%
  mutate(pCode = gsub("valueToUse_", replacement = "", pCode)) %>%
  left_join(select(pCodeInfo, parameter_cd, casrn, class,parameter_nm,
                   EEF_max_in.vitro_or_in.vivo),
            by=c("pCode" = "parameter_cd")) %>%
  gather(endPoint, value, EEF_max_in.vitro_or_in.vivo) %>%
  mutate(EAR =  measuredValue*value/0.7) %>%
  filter(!is.na(EAR)) 

wDataLong_EQ$parameter_nm[wDataLong_EQ$parameter_nm == "4-(1,1,3,3-Tetramethylbutyl)phenol"] <- "4-tert-Octylphenol"

waterSamplePCodes_EQ <- unique(wDataLong_EQ$pCode)

toxCastChems_EQ <- gather(ACC, endPoint, ACC, -casn, -chnm, -flags) %>%
  filter(!is.na(ACC)) %>%
  left_join(pCodeInfo[pCodeInfo$parameter_cd %in% waterSamplePCodes_EQ,c("casrn", "parameter_units", "mlWt")],
            by= c("casn"="casrn")) %>%
  filter(!is.na(parameter_units)) %>%
  select(casn, chnm) %>%
  distinct()

toxCastChems_EQ$chnm[toxCastChems_EQ$chnm == "4-(1,1,3,3-Tetramethylbutyl)phenol"] <- "4-tert-Octylphenol"

wDataLong_EQ <- wDataLong_EQ %>%
  left_join(toxCastChems_EQ, by=c("casrn"="casn")) %>%
  filter(!is.na(chnm)) %>%
  mutate(parameter_nm = chnm) %>%
  select(-chnm)

graphData.eq <- wDataLong_EQ %>%
  group_by(site,date,parameter_nm,class) %>%
  summarise(sumEAR=sum(EAR)) %>%
  data.frame() %>%
  group_by(site, parameter_nm,class) %>%
  summarise(meanEAR=max(sumEAR)) %>%
  data.frame() %>%
  mutate(guideline = "Traditional") %>%
  rename(category = parameter_nm)

subTox <- filter(graphData, category %in% graphData.eq$category) %>%
  mutate(otherThing = "EEQ")
  
subTox$category[subTox$category == "4-(1,1,3,3-Tetramethylbutyl)phenol"] <- "4-tert-Octylphenol"

EQ <- graphData.eq %>%
  mutate(otherThing = "EEQ")

EQ$category[EQ$category == "4-(1,1,3,3-Tetramethylbutyl)phenol"] <- "4-tert-Octylphenol"

subToxWQ <- graphData %>%
  mutate(otherThing = "Water Quality Guidelines")

WQ <- graphData.wq %>%
  rename(category = parameter_nm) %>%
  mutate(otherThing = "Water Quality Guidelines") %>%
  mutate(guideline = "Traditional")

fullFULL <- bind_rows(subTox, EQ, subToxWQ, WQ) %>%
  mutate(class = factor(class, levels=rev(as.character(orderClass$class))))

fullData <- bind_rows(graphData.full_WQ, graphData) 

fullData$class[fullData$class == "Detergent Metabolites"] <- "Detergent"

x <- graphData[is.na(graphData$category),]  

orderChem <- graphData %>%#fullData %>% #not fullFULL...or just graphData....needs just tox and WQ
  group_by(category,class) %>%
  summarise(median = quantile(meanEAR[meanEAR != 0],0.5)) %>%
  data.frame() %>%
  mutate(class = factor(class, levels=orderClass$class)) %>%
  arrange(class, median)

orderedLevels <- as.character(orderChem$category)
orderedLevels <- orderedLevels[!is.na(orderedLevels)]
orderedLevels <- c(orderedLevels[1:2], "Cumene", 
                   orderedLevels[3:4],"Bromoform",
                   orderedLevels[5:length(orderedLevels)])

fullFULL <- fullFULL %>%
  mutate(guideline = factor(as.character(guideline), levels=c("ToxCast","Traditional")),
         otherThing = factor(as.character(otherThing), levels = c("Water Quality Guidelines","EEQ"))) %>%
  mutate(class = factor(class, levels=rev(orderClass$class))) %>%
  mutate(category = factor(category, levels=orderedLevels)) 

fullFULL$class[fullFULL$category == "4-Nonylphenol"] <- "Detergent"

fullFULL$class[which(is.na(fullFULL$class))] <- "Other"

cbValues <- c("#DCDA4B","#999999","#00FFFF","#CEA226","#CC79A7","#4E26CE",
              "#FFFF00","#78C15A","#79AEAE","#FF0000","#00FF00","#B1611D",
              "#FFA500")

textData <- data.frame(guideline = factor(c(rep("Traditional", 2),
                                          rep("ToxCast", 2),rep("Traditional", 2)), levels = levels(fullFULL$guideline)),
                       otherThing = factor(c("Water Quality Guidelines","EEQ",
                                             "Water Quality Guidelines","EEQ",
                                             "Water Quality Guidelines","EEQ"), levels = levels(fullFULL$otherThing)),
                       category = factor(c("2-Methylnaphthalene","1,4-Dichlorobenzene", 
                                           "Bisphenol A","Bisphenol A",
                                           "Bisphenol A","Bisphenol A"), levels = levels(fullFULL$category)),
                       textExplain = c("Water Quality Guidelines Quotients",
                                       "Estradiol Equivalent Quotients",
                                       "A","B","C","D"),
                       y = c(0.5,0.5,10,10,100,100))

countNonZero <- fullFULL %>%
  select(site, category,guideline,otherThing, meanEAR) %>%
  group_by(site, category,guideline,otherThing) %>%
  summarise(meanEAR = mean(meanEAR, na.rm=TRUE)) %>%
  group_by(category,guideline,otherThing) %>%
  summarise(nonZero = as.character(sum(meanEAR>0))) %>%
  data.frame() %>%
  select(category, otherThing, nonZero) %>%
  distinct() %>%
  mutate(guideline = factor(c("ToxCast"), levels = levels(fullFULL$guideline)),
         otherThing = factor(otherThing, levels = levels(fullFULL$otherThing)),
         category = factor(category, levels = levels(fullFULL$category))) 

countNonZero <- countNonZero[!duplicated(countNonZero[,1:2]),]

astrictData <- countNonZero %>%
  mutate(guideline = factor(c("Traditional"), levels = levels(fullFULL$guideline))) %>%
  filter(otherThing == "Water Quality Guidelines") %>%
  mutate(nonZero = "*") %>%
  filter(!(category %in% unique(WQ$category)))

levels(fullFULL$guideline) <- c("ToxCast\nMaximum EAR Per Site", 
                                "Traditional*\nMaximum Quotient Per Site")
levels(countNonZero$guideline) <- c("ToxCast\nMaximum EAR Per Site", 
                                "Traditional*\nMaximum Quotient Per Site")
levels(astrictData$guideline) <- c("ToxCast\nMaximum EAR Per Site", 
                                    "Traditional*\nMaximum Quotient Per Site")
levels(textData$guideline) <- c("ToxCast\nMaximum EAR Per Site", 
                                   "Traditional*\nMaximum Quotient Per Site")

toxPlot_All <- ggplot(data=fullFULL) +
  scale_y_log10(labels=fancyNumbers)  +
  geom_boxplot(aes(x=category, y=meanEAR, fill=class),
               lwd=0.1,outlier.size=0) +
  facet_grid(otherThing ~ guideline, scales = "free", space = "free") +
  theme_bw() +
  scale_x_discrete(drop=TRUE) +
  coord_flip() +
  theme(axis.text = element_text( color = "black"),
        axis.text.y = element_text(size=7),
        axis.title=element_blank(),
        panel.background = element_blank(),
        plot.background = element_rect(fill = "transparent",colour = NA),
        strip.background = element_rect(fill = "transparent",colour = NA),
        strip.text.y = element_blank()) +
  guides(fill=guide_legend(ncol=6)) +
  theme(legend.position="bottom",
        legend.justification = "left",
        legend.background = element_rect(fill = "transparent", colour = "transparent"),
        legend.title=element_blank(),
        legend.text = element_text(size=8),
        legend.key.height = unit(1,"line")) +
  scale_fill_manual(values = cbValues, drop=FALSE) 

ymin <- 10^-6
ymax <- ggplot_build(toxPlot_All)$layout$panel_ranges[[1]]$y.range[2]

toxPlot_All <- toxPlot_All +
  geom_text(data=countNonZero, aes(x=category,label=nonZero, y=ymin), size=2.5) +
  geom_text(data = textData[-1:-2,], aes(x=category, label=textExplain, y=y), 
            size = 3) +
  geom_text(data = astrictData, aes(x=category, label=nonZero, y=0.00002), 
            size=5, vjust = 0.70)

toxPlot_All

ggsave(toxPlot_All, bg = "transparent",
       filename = "allPanels.png", 
       height = 10, width = 7.75)
