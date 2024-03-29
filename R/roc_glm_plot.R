#' @title Visualize ROC-GLM
#' @description This function plots the approximted ROC curve after calculating the ROC-GLM using `dsROCGLM`.
#'   The function calculates a regular grid from 0 to 1 and calculate the ROC from the binormal form
#'   `pnorm(a + b*qnorm(x))` with a and b the parameter from the ROC-GLM.
#' @param x (`list()`) List containing the ROC-GLM parameter returned from `dsROCGLM`.
#' @param ... Additional parameter. Two special parameter `by` (`numeric(1L)`) and `plot_ci` (`logical(1L)`) can
#'   can be specified. `by` is a numeric value indicating the grid size (default is `0.001`).
#'   This value must be between 0 and 1. `plot_ci` is an indicator whether the CI should be added
#'   to the plot or not (default is `TRUE`).
#' @return ggplot of approximated ROC curve, AUC, and CI for the AUC.
#' @author Daniel S.
#' @export
plot.ROC.GLM = function(x, ...) {

  if (! inherits(x, "ROC.GLM"))
    stop("x must be of class ROC.GLM")

  ll_args = list(...)
  by = ll_args[["by"]]
  plot_ci = ll_args[["plot_ci"]]
  if (is.null(by)) by = 0.001
  if (is.null(plot_ci)) plot_ci = TRUE

  checkmate::assertNumeric(by, lower = 0, upper = 1, any.missing = FALSE, len = 1L)
  checkmate::assertLogical(plot_ci, any.missing = FALSE, len = 1L)

  roc_glm = x
  x = seq(0, 1, by = by)
  y = stats::pnorm(roc_glm$parameter[1] + roc_glm$parameter[2] * stats::qnorm(x))

  df_plt = data.frame(TPR = y, FPR = x)

  FPR = TPR = NULL # To prevent checks from failing.
  gg = ggplot2::ggplot() +
    ggplot2::geom_line(data = df_plt, mapping = ggplot2::aes(x = FPR, y = TPR), size = 1.5) +
    ggplot2::geom_abline(slope = 1, col = "gray", alpha = 0.9, linetype = "dashed") +
    ggplot2::ggtitle("ROC Curve", "Approximation via ROC-GLM")

  if (plot_ci) {
    lower = upper = auc = NULL
    df_auc = data.frame(lower = roc_glm$ci[1], upper = roc_glm$ci[2], auc = roc_glm$auc)
    gg = gg +
      ggplot2::geom_errorbarh(data = df_auc,
        ggplot2::aes(y = 0.1, xmin = lower, xmax = upper), height = 0.05) +
      ggplot2::geom_point(data = df_auc, ggplot2::aes(y = 0.1, x = auc), size = 5) +
      ggplot2::geom_point(data = df_auc, ggplot2::aes(y = 0.1, x = auc), size = 2, color = "white") +
      ggplot2::annotate("text", x = df_auc$auc, y = 0.1, label = "AUC", vjust = -1) +
      ggplot2::annotate("text", x = df_auc$auc, y = 0.1, label = round(df_auc$auc, 2), vjust = 2) +
      ggplot2::annotate("text", x = df_auc$lower, y = 0.1, label = round(df_auc$lower, 2), vjust = 3) +
      ggplot2::annotate("text", x = df_auc$upper, y = 0.1, label = round(df_auc$upper, 2), vjust = 3)
  }

  return(gg)
}
