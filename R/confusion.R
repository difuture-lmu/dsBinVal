#' @title Calculate confusion matrix
#' @description This function calculates the confusion matrix.
#' @param truth_name (`character(1L)`) Character containing the name of the vector of 0-1-values
#'   encoded as integer or numeric.
#' @param prob_name (`character(1L)`) Character containing the name of the vector of probabilities.
#' @param threshold (`numeric(1L)`) Threshold used to transform probabilities into classes (default = 0.5).
#' @return Confusion matrix.
#' @author Daniel S.
#' @export
confusion = function(truth_name, prob_name, threshold = 0.5) {
  checkmate::assertCharacter(truth_name, len = 1L, null.ok = FALSE, any.missing = FALSE)
  checkmate::assertCharacter(prob_name, len = 1L, null.ok = FALSE, any.missing = FALSE)
  checkmate::assertNumeric(threshold, len = 1L, any.missing = FALSE)

  if ((threshold > 1) || (threshold < 0)) {
    warning("Threshold for probabilistic classifiers should be between 0 and 1. It is also possible,",
      "depending on the prediction, and hence scoring classifier, to use other threshold.")
  }

  truth = eval(parse(text = truth_name))
  prob  = eval(parse(text = prob_name))

  ntruth = length(truth)
  checkmate::assertNumeric(prob, len = ntruth, null.ok = FALSE, any.missing = FALSE)

  ## Calculate brier score just if there are at least five or more values to ensure privacy:
  nfilter_privacy = .getPrivacyLevel()
  if (ntruth < nfilter_privacy)
    stop("More than ", nfilter_privacy, " observations are required to ensure privacy!")

  if (is.character(truth))
    truth = as.integer(as.factor(truth))

  if (is.factor(truth))
    truth = as.integer(truth)

  truth = truth - min(truth)

  if (any(truth > 1))
    stop("Truth values has to be 0 and 1!")

  if ((min(prob) < 0) && (max(prob) > 1))
    stop("Score (probabilities are not between 0 and 1!)")

  cls_pred = ifelse(prob > threshold, 1, 0)
  conf = table(truth = truth, predicted = cls_pred)

  if (any(conf < nfilter_privacy))
    stop("Each entry in the confusion matrix must be smaller than the privacy level ", nfilter_privacy, ".")

  return(conf)
}

#' @title Calculate the confusion matrix the DataSHIELD servers
#' @param connections (`DSI::connection`) Connection to an OPAL server.
#' @param truth_name (`character(1L)`) `R` object containing the models name as character.
#' @param pred_name (`character(1L)`) Name of the object predictions should be assigned to.
#' @param threshold (`numeric(1L)`) Threshold used to transform probabilities into classes (default = 0.5).
#' @return Confusion matrix for multiple server
#' @author Daniel S.
#' @export
dsConfusion = function(connections, truth_name, pred_name, threshold = 0.5) {
  checkmate::assertCharacter(truth_name, len = 1L, null.ok = FALSE, any.missing = FALSE)
  checkmate::assertCharacter(pred_name, len = 1L, null.ok = FALSE, any.missing = FALSE)
  checkmate::assertNumeric(threshold, len = 1L, any.missing = FALSE)

  sym = DSI::datashield.symbols(connections)
  snames = names(sym)
  for (s in snames) {
    if (! pred_name %in% sym[[s]])
      stop("There is no data object '", pred_name, "' on server '", s, "'.")
  }

  call = paste0("confusion(\"", truth_name, "\", \"", pred_name, "\", ", threshold, ")")
  cq = NULL
  eval(parse(text = paste0("cq = quote(", call, ")")))
  individuals = DSI::datashield.aggregate(conns = connections, cq)

  conf = Reduce("+", individuals)

  return(conf)
}
