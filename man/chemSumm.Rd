% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/chemSumm.R
\name{chemSumm}
\alias{chemSumm}
\title{Create chemical summary}
\usage{
chemSumm(chemicalSummary, EAR.key = "EAR", chnmCol = "chnm",
  classCol = "class", siteCol = "site", dateCol = "date")
}
\arguments{
\item{chemicalSummary}{data frame returned from \code{chemSummBasic}}

\item{EAR.key}{column name of EAR}

\item{chnmCol}{column name of chemical names}

\item{classCol}{column name of chemical class}

\item{siteCol}{column name of site}

\item{dateCol}{column name of date}
}
\description{
Create chemical summary
}
\examples{
wData <- wData
pCodeInfo <- pCodeInfo
endPoint <- endPointToxCreate(pCodeInfo)
chemicalSummary <- chemSummBasic(wData,pCodeInfo,endPoint)
chemSum1 <- chemSumm(chemicalSummary)
}

