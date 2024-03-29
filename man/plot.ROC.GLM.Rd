% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/roc_glm_plot.R
\name{plot.ROC.GLM}
\alias{plot.ROC.GLM}
\title{Visualize ROC-GLM}
\usage{
\method{plot}{ROC.GLM}(x, ...)
}
\arguments{
\item{x}{(`list()`) List containing the ROC-GLM parameter returned from `dsROCGLM`.}

\item{...}{Additional parameter. Two special parameter `by` (`numeric(1L)`) and `plot_ci` (`logical(1L)`) can
can be specified. `by` is a numeric value indicating the grid size (default is `0.001`).
This value must be between 0 and 1. `plot_ci` is an indicator whether the CI should be added
to the plot or not (default is `TRUE`).}
}
\value{
ggplot of approximated ROC curve, AUC, and CI for the AUC.
}
\description{
This function plots the approximted ROC curve after calculating the ROC-GLM using `dsROCGLM`.
  The function calculates a regular grid from 0 to 1 and calculate the ROC from the binormal form
  `pnorm(a + b*qnorm(x))` with a and b the parameter from the ROC-GLM.
}
\author{
Daniel S.
}
