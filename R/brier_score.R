#' @title Calculate Brier score, called by dsBrierScore
#' @description This function calculates the Brier score for a given 0-1-vector and
#'   vector of probabilities.
#' @param truth_name (`character(1L)`) Character containing the name of the vector of 0-1-values
#'   encoded as integer or numeric.
#' @param prob_name (`character(1L)`) Character containing the name of the vector of probabilities.
#' @return Brier score and number of values used as weights for later aggregation.
#' @author Daniel S.
#' @export
brierScore = function(truth_name, prob_name) {

  #############################################################
  #MODULE 1: CAPTURE THE nfilter SETTINGS
  thr = dsBase::listDisclosureSettingsDS()
  nfilter_tab = as.numeric(thr$nfilter.tab)
  #nfilter_glm = as.numeric(thr$nfilter.glm)
  #nfilter_subset = as.numeric(thr$nfilter.subset)
  #nfilter_string = as.numeric(thr$nfilter.string)
  #############################################################

  checkmate::assertCharacter(truth_name, len = 1L, null.ok = FALSE, any.missing = FALSE)
  checkmate::assertCharacter(prob_name, len = 1L, null.ok = FALSE, any.missing = FALSE)

  #truth = eval(parse(text = truth_name))
  truth = get(truth_name, envir = parent.frame())
  #prob = eval(parse(text = prob_name))
  prob = get(prob_name, envir = parent.frame())

  ntruth = length(truth)
  checkmate::assertNumeric(prob, len = ntruth, null.ok = FALSE, any.missing = FALSE)

  ## Calculate brier score just if there are at least five or more values to ensure privacy:

  # Fallback if `listDisclosureSettingsDS` returns NULL:
  if (length(nfilter_tab) == 0) nfilter_tab = .getPrivacyLevel()
  if (ntruth < nfilter_tab)
    stop("More than ", nfilter_tab, " observations are required to ensure privacy!")

  if (is.character(truth))
    truth = as.integer(as.factor(truth))

  if (is.factor(truth))
    truth = as.integer(truth)

  truth = truth - min(truth)

  if (any(truth > 1))
    stop("Truth values has to be 0 and 1!")

  if ((min(prob) < 0) && (max(prob) > 1))
    stop("Score (probabilities are not between 0 and 1!)")

  bs = mean((truth - prob)^2)
  return(list(bs = bs, n = ntruth))
}

#' @title Calculate Brier score on DataSHIELD servers
#' @description This function enables to calculate the Brier score distributively
#'   on DataSHIELD servers.
#' @param connections (`DSI::connection`) Connection to an OPAL server.
#' @param truth_name (`character(1L)`) `R` object containing the models name as character.
#' @param pred_name (`character(1L)`) Name of the object predictions should be assigned to.
#' @return Brier score for multiple server
#' @author Daniel S.
#' @export
dsBrierScore = function(connections, truth_name, pred_name) {
  checkmate::assertCharacter(truth_name, len = 1L, null.ok = FALSE, any.missing = FALSE)
  checkmate::assertCharacter(pred_name, len = 1L, null.ok = FALSE, any.missing = FALSE)

  sym = DSI::datashield.symbols(connections)
  snames = names(sym)
  for (s in snames) {
    if (! pred_name %in% sym[[s]])
      stop("There is no data object '", pred_name, "' on server '", s, "'.")
  }

  call = paste0("brierScore(\"", truth_name, "\", \"", pred_name, "\")")
  cq = NULL
  eval(parse(text = paste0("cq = quote(", call, ")")))
  individuals  = DSI::datashield.aggregate(conns = connections, cq)

  bs = Reduce("c", lapply(individuals, function(ll) ll$bs))
  w  = Reduce("c", lapply(individuals, function(ll) ll$n))

  return(stats::weighted.mean(bs, w))
}
