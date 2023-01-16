#' @title Plot calibration curve
#' @description This function plots the calibration curve returned by `dsCalibrationCurve()`.
#' @param cc (`list()`) Object returned by `dsCalibrationCurve()`
#' @param individuals (`logical(1L)`) Logical value indicating whether the individual calibration
#'   curves should be plotted or not (default is `TRUE`).
#' @param ... Additional arguments passed to `geom_point()` and `geom_line()` for the calibration line and points.
#' @return ggplot of calibration curve(s)
#' @author Daniel S.
#' @export
plotCalibrationCurve = function(cc, individuals = TRUE, ...) {
  if (! inherits(cc, "calibration.curve"))
    stop("cc must be of class calibration.curve")

  checkmate::assertList(cc, len = 2L)
  temp = lapply(names(cc), function(ccname) checkmate::assertChoice(ccname, choices = c("individuals", "aggregated")))
  checkmate::assertLogical(individuals, len = 1L)

  for (s in names(cc$individuals)) {
    cc$individuals[[s]]$server = s
  }
  tmp = do.call(rbind, cc$individuals)

  gg = ggplot2::ggplot()
  if (individuals) {
    prob = truth = server = NULL
    gg = gg +
      ggplot2::geom_point(data = tmp,
        ggplot2::aes(x = prob, y = truth, color = server),
        alpha = 0.5) +
      ggplot2::geom_line(data = tmp,
        ggplot2::aes(x = prob, y = truth, color = server),
        alpha = 0.5) +
      ggplot2::labs(color = "Server")
  }
  gg = gg +
    ggplot2::geom_point(data = cc$aggregated, ggplot2::aes(x = prob, y = truth), ...) +
    ggplot2::geom_line(data = cc$aggregated, ggplot2::aes(x = prob, y = truth), ...)

  gg = gg +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "dark red") +
    ggplot2::xlab("Predicted") +
    ggplot2::ylab("True frequency")

  return(gg)
}

#' @title Plot calibration curve
#' @description This function plots the calibration curve returned by `dsCalibrationCurve()`.
#' @param x (`list()`) Object returned by `dsCalibrationCurve()`
#' @param ... Additional arguments passed to `plotCalibrationCurve()`.
#' @return ggplot of calibration curve(s)
#' @author Daniel S.
#' @export
plot.calibration.curve = function(x, ...) {
  if (! inherits(x, "calibration.curve"))
    stop("x must be of class calibration.curve")

  plotCalibrationCurve(cc = x, ...)
}
