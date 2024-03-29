% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/roc_glm_parts.R
\name{calcU}
\alias{calcU}
\title{Calculate U Matrix for ROC-GLM}
\usage{
calcU(tset, pv)
}
\arguments{
\item{tset}{(`numeric()`) Set of thresholds}

\item{pv}{(`numeric()`) Placement values}
}
\value{
Matrix of zeros and ones that are used as target variable for Probit regression
}
\description{
This function calculates U matrix which is used as target variable for the ROC-GLM.
}
\author{
Stefan B., Daniel S.
}
