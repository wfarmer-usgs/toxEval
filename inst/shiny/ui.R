library(toxEval)
library(shinydashboard)
library(dplyr)
library(ggplot2)
library(DT)
library(leaflet)
library(data.table)
library(tidyr)
library(RColorBrewer)
library(grid)
library(stringi)


endPointInfo <- endPointInfo

endPointInfo <- endPointInfo[!(endPointInfo$assay_source_name == "ATG" & endPointInfo$signal_direction == "loss"),]
endPointInfo <- endPointInfo[!(endPointInfo$assay_source_name == "NVS" & endPointInfo$signal_direction == "gain"),]
endPointInfo <- endPointInfo[endPointInfo$assay_component_endpoint_name != "TOX21_p53_BLA_p3_ratio",]
endPointInfo <- endPointInfo[endPointInfo$assay_component_endpoint_name != "TOX21_p53_BLA_p2_viability",]

endPointInfo$intended_target_family[endPointInfo$assay_component_endpoint_name %in% 
                                      c("CLD_CYP1A1_24hr","CLD_CYP1A1_48hr","CLD_CYP1A1_6hr",
                                        "CLD_CYP1A2_24hr","CLD_CYP1A2_48hr","CLD_CYP1A2_6hr")] <- "dna binding"

endPointInfo$intended_target_family[endPointInfo$assay_component_endpoint_name %in% 
                                      c("CLD_CYP2B6_24hr","CLD_CYP2B6_48hr","CLD_CYP2B6_6hr",
                                        "CLD_CYP3A4_24hr","CLD_CYP3A4_48hr","CLD_CYP3A4_6hr",
                                        "CLD_SULT2A_48hr","CLD_UGT1A1_48hr","NVS_NR_bER",
                                        "NVS_NR_bPR","NVS_NR_cAR")] <- "nuclear receptor"

endPointInfo$intended_target_family[endPointInfo$assay_component_endpoint_name %in% 
                                      c("Tanguay_ZF_120hpf_ActivityScore",
                                        "Tanguay_ZF_120hpf_AXIS_up",
                                        "Tanguay_ZF_120hpf_BRAI_up",
                                        "Tanguay_ZF_120hpf_CFIN_up",
                                        "Tanguay_ZF_120hpf_EYE_up",
                                        "Tanguay_ZF_120hpf_JAW_up",
                                        "Tanguay_ZF_120hpf_MORT_up",
                                        "Tanguay_ZF_120hpf_OTIC_up",
                                        "Tanguay_ZF_120hpf_PE_up",
                                        "Tanguay_ZF_120hpf_PFIN_up",
                                        "Tanguay_ZF_120hpf_PIG_up",
                                        "Tanguay_ZF_120hpf_SNOU_up",
                                        "Tanguay_ZF_120hpf_SOMI_up",
                                        "Tanguay_ZF_120hpf_SWIM_up",
                                        "Tanguay_ZF_120hpf_TR_up",
                                        "Tanguay_ZF_120hpf_TRUN_up",
                                        "Tanguay_ZF_120hpf_YSE_up")] <- "zebrafish"

choicesPerGroup <- apply(endPointInfo, 2, function(x) length(unique(x[!is.na(x)])))
choicesPerGroup <- which(choicesPerGroup > 6 & choicesPerGroup < 100)

endPointInfo <- endPointInfo[,c("assay_component_endpoint_name",names(choicesPerGroup))] %>%
  rename(endPoint = assay_component_endpoint_name)

choicesPerGroup <- apply(endPointInfo[,-1], 2, function(x) length(unique(x[!is.na(x)])))
groupChoices <- paste0(names(choicesPerGroup)," (",choicesPerGroup,")")

pathToApp <- system.file("extdata", package="toxEval")
summaryFile <- readRDS(file.path(pathToApp,"summary.rds"))

endPointInfo$intended_target_family <- stri_trans_totitle(endPointInfo$intended_target_family)
endPointInfo$intended_target_family[grep("Dna",endPointInfo$intended_target_family)] <- "DNA Binding"
endPointInfo$intended_target_family[grep("Cyp",endPointInfo$intended_target_family)] <- "CYP"
endPointInfo$intended_target_family[grep("Gpcr",endPointInfo$intended_target_family)] <- "GPCR"

ep <- data.frame(endPointInfo[,c("endPoint", "intended_target_family")])
ep <- ep[!is.na(ep[,2]),]
ep <- ep[ep[,2] != "NA",]

orderBy <- ep[,2]
orderNames <- names(table(orderBy))
nEndPoints <- as.integer(table(orderBy))

df <- data.frame(orderNames,nEndPoints,stringsAsFactors = FALSE) %>%
  arrange(desc(nEndPoints))

dropDownHeader <- c(paste0(df$orderNames," (",df$nEndPoints,")"))

selChoices <- df$orderNames

# flags <- unique(AC50gain$flags[!is.na(AC50gain$flags)])
# flags <- unique(unlist(strsplit(flags, "\\|")))
flags <- c("Noisy data",
           "Only one conc above baseline, active",
           "Hit-call potentially confounded by overfitting")

flagsALL <- c("Borderline active","Only highest conc above baseline, active" ,      
              "Only one conc above baseline, active","Noisy data",                                 
              "Hit-call potentially confounded by overfitting","Gain AC50 < lowest conc & loss AC50 < mean conc",
              "Biochemical assay with < 50% efficacy")

header <- dashboardHeader(title = "toxEval")

sidebar <- dashboardSidebar(
  sidebarMenu(
   selectInput("data", label = "Data",
                     choices = c("Water Sample",
                                 "Passive Samples",
                                 "Duluth",
                                 "NPS",
                                 "TSHP",
                                 "App State",
                                 "Birds"),
                                 # ,"Detection Limits"),
                     selected = "Water Sample", multiple = FALSE),
   radioButtons("radioMaxGroup", label = "",
                choices = list("Group" = 1, "Chemical" = 2, "Class" = 3), 
                selected = 3),
   conditionalPanel(
     condition = "input.mainOut == 'endpoint'",
     selectInput("epGroup", label = "Choose Chemical",
                 choices = "All",
                 multiple = FALSE,
                 selected = "All")     
   ),
   radioButtons("meanEAR",choices = list("MeanEAR"=TRUE, "MaxEAR" = FALSE),
                inline = TRUE, label = "",selected = "MaxEAR"),
   menuItem("Assay", icon = icon("th"), tabName = "assay",
            checkboxGroupInput("assay", "Assays:",
                               c("Apredica" = "APR",
                                 "Attagene" = "ATG",
                                 "BioSeek" = "BSK",
                                 "NovaScreen" = "NVS",
                                 "Odyssey Thera" = "OT",
                                 "Toxicity Testing" = "TOX21",
                                 "CEETOX" = "CEETOX",
                                 "CLD" = "CLD",
                                 "TANGUAY" = "TANGUAY",
                                 "NHEERL_PADILLA"="NHEERL_PADILLA",
                                 "NCCT_SIMMONS"="NCCT_SIMMONS",
                                 "ACEA Biosciences" = "ACEA"),
              selected= c("ATG","NVS","OT","TOX21","CEETOX", "APR", 
                            "CLD","TANGUAY","NHEERL_PADILLA",
                            "NCCT_SIMMONS","ACEA")),
              actionButton("pickAssay", label="Switch Assays")),
   menuItem("Annotation", icon = icon("th"), tabName = "annotation",
            selectInput("groupCol", label = "Annotation (# Groups)", 
                        choices = setNames(names(endPointInfo)[-1],groupChoices),
                        selected = names(endPointInfo)[names(endPointInfo) == "intended_target_family"], 
                        multiple = FALSE),
            actionButton("changeAnn", label="Switch Annotation")
            ),
   menuItem("Group", icon = icon("th"), tabName = "groupMenu",
            checkboxGroupInput("group", "Groups (# End Points)",
                               setNames(df$orderNames,dropDownHeader),
                               selected=df$orderNames[c(-3)]),
            actionButton("allGroup", label="Select All/Deselect")),
   menuItem("Sites", icon = icon("th"), tabName = "siteMenu",
            selectInput("sites", label = "Site", 
                        choices = c("All","2016 GLRI SP sites",summaryFile$site),
                        selected = "All", multiple = FALSE)
   ),
   menuItem("Flags", icon = icon("th"), tabName = "flagMenu",
            checkboxGroupInput("flags", "Include Flags",choices = flagsALL, selected = flags),
            actionButton("pickFlags", label="Switch flags")),
   menuItem("Hit Threshold",icon = icon("th"), tabName = "hitThresTab",
            numericInput("hitThres",label = "Hit Threshold",value = 0.1,min = 0.0000001),
            actionButton("changeHit", label="Change Hit Threshold")
   ),
   conditionalPanel(
     condition = "input.data == 'Passive Samples'",
     radioButtons("year", label = "",inline = TRUE,
                  choices = c("2010", "2014", "Combo"), 
                  selected = "Combo")   
   ),
   menuItem("Source code", icon = icon("file-code-o"), 
            href = "https://github.com/USGS-R/toxEval/tree/master/inst/shiny")
  )
)

body <- dashboardBody(
  tags$head(tags$link(rel="shortcut icon", href="favicon.ico")),
  tabBox(width = 12, id="mainOut",
    tabPanel(title = tagList("Map", shiny::icon("map-marker")),
             value="map",
            leaflet::leafletOutput("mymap"),
            htmlOutput("mapFooter")
    ),
    tabPanel(title = tagList("Box Plots", shiny::icon("bar-chart")),
             value="summary",
            uiOutput("graphGroup.ui"),
            downloadButton('downloadBoxPlot', 'Download PNG')
    ),
    tabPanel(title = tagList("Bar Charts", shiny::icon("bar-chart")),
             value="summaryBar",
             plotOutput("stackBarGroup"),
             downloadButton('downloadStackPlot', 'Download PNG')
    ),
    tabPanel(title = tagList("Max EAR and Frequency", shiny::icon("bars")),
             value="maxEAR",
            h5("maxEAR = Maximum summation of EARs per sample"),
            h5("freq = Fraction of samples with hits"),
            DT::dataTableOutput('tableSumm')
    ),
    tabPanel(title = tagList("Hit Counts", shiny::icon("bars")),
             value="maxHits",
            htmlOutput("nGroup"),
            DT::dataTableOutput('tableGroupSumm')
    ),
    tabPanel(title = tagList("Site Hits", shiny::icon("barcode")),
            value="siteHits",
            htmlOutput("siteHitText"),
            div(DT::dataTableOutput("hitsTable"), style="font-size:90%")
    ),
    tabPanel(title = tagList("Endpoints Hits", shiny::icon("barcode")),
             value="endHits",
             # htmlOutput("siteHitText"),
             div(DT::dataTableOutput("hitsTableEPs"), style="font-size:90%")
    ),
    tabPanel(title = tagList("Endpoint", shiny::icon("bar-chart")),
             value="endpoint",
            plotOutput("endpointGraph",  height = "1000px")
    ),
    tabPanel(title = tagList("Heat Map", shiny::icon("bar-chart")),
                   value="heat",
                   uiOutput("graphHeat.ui"),
             downloadButton('downloadHeatPlot', 'Download PNG')
    )
  ),

  fluidRow(
    column(1, HTML('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="300" height="75"><path id="USGS" d="m234.95 15.44v85.037c0 17.938-10.132 36.871-40.691 36.871-27.569 0-40.859-14.281-40.859-36.871v-85.04h25.08v83.377c0 14.783 6.311 20.593 15.447 20.593 10.959 0 15.943-7.307 15.943-20.593v-83.377h25.08m40.79 121.91c-31.058 0-36.871-18.27-35.542-39.03h25.078c0 11.462 0.5 21.092 14.282 21.092 8.472 0 12.62-5.482 12.62-13.618 0-21.592-50.486-22.922-50.486-58.631 0-18.769 8.968-33.715 39.525-33.715 24.42 0 36.543 10.963 34.883 36.043h-24.419c0-8.974-1.492-18.106-11.627-18.106-8.136 0-12.953 4.486-12.953 12.787 0 22.757 50.493 20.763 50.493 58.465 0 31.06-22.75 34.72-41.85 34.72m168.6 0c-31.06 0-36.871-18.27-35.539-39.03h25.075c0 11.462 0.502 21.092 14.285 21.092 8.475 0 12.625-5.482 12.625-13.618 0-21.592-50.494-22.922-50.494-58.631 0-18.769 8.969-33.715 39.531-33.715 24.412 0 36.536 10.963 34.875 36.043h-24.412c0-8.974-1.494-18.106-11.625-18.106-8.144 0-12.955 4.486-12.955 12.787 0 22.757 50.486 20.763 50.486 58.465 0 31.06-22.75 34.72-41.85 34.72m-79.89-46.684h14.76v26.461l-1.229 0.454c-3.816 1.332-8.301 2.327-12.453 2.327-14.287 0-17.943-6.645-17.943-44.177 0-23.256 0-44.348 15.615-44.348 12.146 0 14.711 8.198 14.933 18.107h24.981c0.198-23.271-14.789-36.043-38.42-36.043-41.021 0-42.52 30.724-42.52 60.954 0 45.507 4.938 63.167 47.12 63.167 9.784 0 25.36-2.211 32.554-4.18 0.436-0.115 1.212-0.596 1.212-1.216v-59.598h-38.612v18.09" style="fill:rgb(40%,40%,40%); fill-opacity: 0.3" transform="scale(0.5)"/>
  <path id="waves" d="m48.736 55.595l0.419 0.403c11.752 9.844 24.431 8.886 34.092 2.464 6.088-4.049 33.633-22.367 49.202-32.718v-10.344h-116.03v27.309c7.071-1.224 18.47-0.022 32.316 12.886m43.651 45.425l-13.705-13.142c-1.926-1.753-3.571-3.04-3.927-3.313-11.204-7.867-21.646-5.476-26.149-3.802-1.362 0.544-2.665 1.287-3.586 1.869l-28.602 19.13v34.666h116.03v-24.95c-2.55 1.62-18.27 10.12-40.063-10.46m-44.677-42.322c-0.619-0.578-1.304-1.194-1.915-1.698-13.702-10.6-26.646-5.409-29.376-4.116v11.931l6.714-4.523s10.346-7.674 26.446 0.195l-1.869-1.789m16.028 15.409c-0.603-0.534-1.214-1.083-1.823-1.664-12.157-10.285-23.908-7.67-28.781-5.864-1.382 0.554-2.7 1.303-3.629 1.887l-13.086 8.754v12.288l21.888-14.748s10.228-7.589 26.166 0.054l-0.735-0.707m68.722 12.865c-4.563 3.078-9.203 6.203-11.048 7.441-4.128 2.765-13.678 9.614-29.577 2.015l1.869 1.797c0.699 0.63 1.554 1.362 2.481 2.077 11.418 8.53 23.62 7.303 32.769 1.243 1.267-0.838 2.424-1.609 3.507-2.334v-12.234m0-24.61c-10.02 6.738-23.546 15.833-26.085 17.536-4.127 2.765-13.82 9.708-29.379 2.273l1.804 1.729c0.205 0.19 0.409 0.375 0.612 0.571l-0.01 0.01 0.01-0.01c12.079 10.22 25.379 8.657 34.501 2.563 5.146-3.436 12.461-8.38 18.548-12.507l-0.01-12.165m0-24.481c-14.452 9.682-38.162 25.568-41.031 27.493-4.162 2.789-13.974 9.836-29.335 2.5l1.864 1.796c1.111 1.004 2.605 2.259 4.192 3.295 10.632 6.792 21.759 5.591 30.817-0.455 6.512-4.351 22.528-14.998 33.493-22.285v-12.344" style="fill:rgb(40%,40%,40%); fill-opacity: 0.3" transform="scale(0.5)"/></svg>')
    ),
    column(11,
           h4("Disclaimer"),
           h5("This software is in the public domain because it contains materials that originally came from the U.S. Geological Survey (USGS), an agency of the United States Department of Interior. For more information, see the official USGS copyright policy at http://www.usgs.gov/visual-id/credit_usgs.html#copyright
              Although this software program has been used by the USGS, no warranty, expressed or implied, is made by the USGS or the U.S. Government as to the accuracy and functioning of the program and related program material nor shall the fact of distribution constitute any such warranty, and no responsibility is assumed by the USGS in connection therewith.
              This software is provided 'AS IS.'"))
  
  )  
  
)

dashboardPage(header, sidebar, body)

