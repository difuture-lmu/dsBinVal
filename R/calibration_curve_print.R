#' @title Printer for calibration curve objects
#' @param x (`list()`) List containing the calibration curve object returned from `dsCalibrationCurve()`.
#' @param ... Additional parameters (basically none, but CRAN forces us to do this in print).
#' @author Daniel S.
#' @export
print.calibration.curve = function(x, ...) {
  if (! inherits(x, "calibration.curve"))
    stop("cc must be of class calibration.curve")

  cc = x

  summary_tab = Reduce("+", lapply(cc$individuals, function(x) x$n))
  missings = cc$aggregated$missing_ratio * summary_tab

  tt = rbind(
    n = summary_tab,
    not_shared = missings)

  ccd = rbind(
    truth = cc$aggregated$truth,
    predicted = cc$aggregated$prob)

  colnames(tt) = cc$aggregated$bin
  colnames(ccd) = cc$aggregated$bin

  cat("\n",
    "Calibration curve:",
    "\n",
    "\n",
    "\tNumber of shared values:",
    "\n",
    sep = "")

  print(tt)

  cat("\n",
    "Values of the calibration curve:",
    "\n",
    sep = "")

  print(ccd)

  cat("\n",
    "\n",
    "Missing values are indicated by the privacy level of ",
    .getPrivacyLevel(),
    ".\n",
    sep = "")

  return(invisible(x))
}
