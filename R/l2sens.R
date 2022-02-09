#'
#' @title Calculate the l2 sensitivity
#'
#' @description Calculation of the l2 sensitivity using a histogram representetation.
#'   Source: https://www.cis.upenn.edu/~aaroth/Papers/privacybook.pdf
#' @param dat (`data.frame()`) The data used to find adjacent inputs.
#' @param scores (`numeric()`) Predicted scores/probabilities.
#' @param nbreaks (`integer(1L)`) Number of breaks used for the histogram
#'   (default = nrow(dat) / 3).
#' @param cols (`character()`) Subset of columns used to find adjacent inputs.
#' @param norm (`function()`) Function to calculate the differnece between the
#'   scores of adjacent inputs (default = Euclidean norm).
#' @return List with maximal l2 sensitivity, indices of inputs that are
#'   used to calculate the maximal l2 sensitivity, and the number of adjacent inputs.
#' @author Daniel S.
#' @export
l2sens = function(dat, scores, nbreaks = NULL, cols = NULL, norm = diff) {
  checkmate::assertDataFrame(dat)
  checkmate::assertNumeric(scores, len = nrow(dat))
  checkmate::assertCount(nbreaks, null.ok = TRUE)
  checkmate::assertCharacter(cols, null.ok = TRUE)
  checkmate::assertFunction(norm)

  if (is.null(nbreaks)) nbreaks = floor(nrow(dat) / 3)
  if (is.null(cols)) cols = colnames(dat)
  dtmp = dat[, cols, drop = FALSE]
  int_representation = do.call(cbind, lapply(dtmp, function(cl) {
    if (is.numeric(cl)) {
      xh = hist(cl, plot = FALSE, breaks = nbreaks)$breaks
      return(vapply(cl, function(x) which.min(xh <= x) - 1, FUN.VALUE = numeric(1L)))
    } else {
      return(model.matrix(~ 0 + cl))
    }
  }))
  l1n = as.matrix(dist(int_representation, method = "manhattan"))
  mdist = min(l1n[l1n > 0])
  if (mdist > 1)
    warning("Was not able to found direct neighbour. Found l1 norm of ", mdist, " as closest inputs.")

  idx     = which(l1n == mdist, arr.ind = TRUE)
  l2senss = apply(idx, 1, function(i) norm(scores[i]))
  ml2sens = max(l2senss)

  if (ml2sens == 0)
    stop("No reasonable l2 sensitivity found! Try to decrease the number of breaks (current = ", nbreaks, ")")

  return(list(l2sens = ml2sens, nl1n = nrow(idx) / 2, l1n = mdist,
    idx = unname(idx[which.max(l2senss), ])))
}

#'
#' @title Calculate the l2 sensitivity on DataSHIELD servers
#'
#' @description Calculation of the l2 sensitivity using a histogram representetation.
#'   Source: https://www.cis.upenn.edu/~aaroth/Papers/privacybook.pdf
#' @param connections (`DSI::connection`) Connection to an OPAL server.
#' @param D (`character(1)`) The name of the data at the DataSHIELD servers.
#' @param pred_name (`character(1)`) Name of the prediction object at the DataSHIELD server.
#' @param nbreaks (`integer(1L)`) Number of breaks used for the histogram
#'   (default = nrow(dat) / 3).
#' @param cols (`character()`) Subset of columns used to find adjacent inputs.
#' @return List with maximal l2 sensitivity, indices of inputs that are
#'   used to calculate the maximal l2 sensitivity, and the number of adjacent inputs.
#' @author Daniel S.
#' @export
dsL2Sens = function(connections, D, pred_name, nbreaks = NULL, cols = NULL) {
  checkmate::assertCharacter(D, len = 1L)
  checkmate::assertCharacter(pred_name, len = 1L)
  checkmate::assertCount(nbreaks, null.ok = TRUE)
  checkmate::assertCharacter(cols, null.ok = TRUE)

  if (is.null(nbreaks))
    nbreaks = "NULL"

  if (is.null(cols[1]))
    cnames = "NULL"
  else
    cnames = paste0("c(", paste(paste0("\"", cols, "\""), collapse = ", "), ")")

  f = paste0("l2sens(\"", D, "\", \"", pred_name, "\", ", nbreaks, ", ", cnames, ")")

  ll_l2s = DSI::datashield.aggregate(conns = connections, f)
  l2s = as.data.frame(do.call(rbind, lapply(ll_l2s, function(x) {
    c(l2s = x$l2sens, l1n = x$l1n)
  })))
  return(max(l2s$l2s[which.min(l2s$l1n)]))
}