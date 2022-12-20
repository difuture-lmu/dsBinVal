#' @title Get a seed depending on an object
#' @description This function creates a seed based on the hash of an object.
#' @param object (`character(1L)`) Character containing the name of the object
#'   to which the seed is bounded.
#' @param rm_attributes (`logical(1L)`) Flag whether attributes should be deleted or not.
#' @return Integer containing a seed.
#' @author Daniel S.
#' @export
seedBoundedToObject = function(object, rm_attributes = TRUE) {
  checkmate::assertCharacter(object, len = 1L)
  checkmate::assertLogical(rm_attributes, len = 1L)
  so = eval(parse(text = object))

  if (! (is.numeric(so) || is.data.frame(so)))
    stop("Object must be a \"numeric vector\" or \"data.frame\" and not ", dQuote(class(so)))

  if (rm_attributes)
    attributes(so) = NULL

  a = digest::sha1(mean(unlist(so), na.rm = TRUE))
  seed_add = as.integer(gsub("[^\\d]+", "", substr(a, 1, 9), perl = TRUE))

  if (is.na(seed_add)) seed_add = 0

  return(seed_add)
}

#' @title Return variance of positive scores
#' @description This function just returns the variance of positive scores.
#' @param truth_name (`character(1L)`) Character containing the name of the vector of 0-1-values
#'   encoded as integer or numeric.
#' @param prob_name (`character(1L)`) Character containing the name of the vector of probabilities.
#' @param m (`numeric(1L)`) Sample mean used for variance calculation. If `NULL` (default), the
#'   sample mean of the positive scores is used.
#' @param return_sum (`logical(1L)`) Logical value indicating whether the function should
#'   just return the sum of positive scores.
#' @return Variance of differences of positive scores
#' @author Daniel S.
#' @export
getPositiveScoresVar = function(truth_name, prob_name, m = NULL, return_sum = FALSE) {

  #############################################################
  #MODULE 1: CAPTURE THE nfilter SETTINGS
  thr = dsBase::listDisclosureSettingsDS()
  nfilter_tab = as.numeric(thr$nfilter.tab)
  #nfilter_glm = as.numeric(thr$nfilter.glm)
  #nfilter_subset = as.numeric(thr$nfilter.subset)
  #nfilter_string = as.numeric(thr$nfilter.string)
  #############################################################

  df_pred = checkTruthProb(truth_name, prob_name)

  checkmate::assertNumeric(m, len = 1L, null.ok = TRUE)

  truth = df_pred$truth
  prob  = df_pred$prob

  ## Calculate brier score just if there are at least five or more values to ensure privacy:

  # Fallback if `listDisclosureSettingsDS` returns NULL:
  if (length(nfilter_tab) == 0) nfilter_tab = .getPrivacyLevel()
  if (length(truth) < nfilter_tab)
    stop("More than ", nfilter_tab, " observations are required to ensure privacy")

  pv = prob[truth == 1]
  if (return_sum) return(sum(pv))

  if (is.null(m))
    return(stats::var(pv) * (length(pv) - 1))
  else
    return(sum((pv - m)^2))
}

#' @title Return positive scores
#' @description This function just returns positive scores and is used
#'   as aggregator to send these positive scores.
#' @param truth_name (`character(1L)`) Character containing the name of the vector of 0-1-values
#'   encoded as integer or numeric.
#' @param prob_name (`character(1L)`) Character containing the name of the vector of probabilities.
#' @param epsilon (`numeric(1L)`) Privacy parameter for differential privacy (DP).
#' @param delta (`numeric(1L)`) Probability of violating epsilon DP.
#' @param seed_object (`character(1L)`) Name of an object which is used
#'   to add a seed based on an object.
#' @param seed_object (`character(1L)`) Name of an object which is used
#'   to add a seed based on an object.
#' @param sort (`logical(1L)`) Indicator whether the return values should be
#'   sorted or not.
#' @return Positive scores
#' @author Daniel S.
#' @export
getPositiveScores = function(truth_name, prob_name, epsilon = 0.2, delta = 0.2,
  seed_object = NULL, sort = FALSE) {

  df_pred = checkTruthProb(truth_name, prob_name)
  checkmate::assertNumeric(epsilon, len = 1L, lower = 0, upper = 1)
  checkmate::assertNumeric(delta, len = 1L, lower = 0, upper = 1)

  checkmate::assertCharacter(seed_object, null.ok = TRUE, len = 1L)
  checkmate::assertLogical(sort, len = 1L)

  if (epsilon == 0) stop("Epsilon must be > 0")
  if (delta == 0)   stop("Delta must be > 0")

  if (! "l2s" %in% c(ls(envir = .GlobalEnv), ls())) {
    stop("Cannot find l2 sensitivity. Please push an l2 ",
      "sensitivity with name 'l2s' to the servers.")
  }

  l2s = get("l2s", envir = parent.frame())
  #l2s = eval(parse(text = "l2s"))
  checkmate::assertNumeric(l2s, len = 1L, lower = 0, any.missing = FALSE)
  if (l2s == 0)
    stop("L2 sensitivity must be > 0")

  truth = df_pred$truth
  prob  = df_pred$prob

  if (sort) {
    pv  = sort(prob[truth == 1])
  } else {
    pv  = prob[truth == 1]
  }
  sde = GMVar(l2s, epsilon, delta)

  if (sde <= 0)
    stop("Standard deviation must be positive to ensure privacy!")

  if (! is.null(seed_object)) {
    seed = seedBoundedToObject(seed_object)
    set.seed(seed)
  }
  out = stats::rnorm(n = length(pv), mean = pv, sd = sde)

  return(out)
}

#' @title Return variance of negative scores
#' @description This function just returns the variance of negative scores.
#' @param truth_name (`character(1L)`) Character containing the name of the vector of 0-1-values
#'   encoded as integer or numeric.
#' @param prob_name (`character(1L)`) Character containing the name of the vector of probabilities.
#' @param m (`numeric(1L)`) Sample mean used for variance calculation. If `NULL` (default), the
#'   sample mean of the negative scores is used.
#' @param return_sum (`logical(1L)`) Logical value indicating whether the function should
#'   just return the sum of negative scores.
#' @return Variance of differences of Negative scores
#' @author Daniel S.
#' @export
getNegativeScoresVar = function(truth_name, prob_name, m = NULL, return_sum = FALSE) {

  #############################################################
  #MODULE 1: CAPTURE THE nfilter SETTINGS
  thr = dsBase::listDisclosureSettingsDS()
  nfilter_tab = as.numeric(thr$nfilter.tab)
  #nfilter_glm = as.numeric(thr$nfilter.glm)
  #nfilter_subset = as.numeric(thr$nfilter.subset)
  #nfilter_string = as.numeric(thr$nfilter.string)
  #############################################################

  df_pred = checkTruthProb(truth_name, prob_name)

  truth = df_pred$truth
  prob  = df_pred$prob

  ## Calculate brier score just if there are at least five or more values to ensure privacy:

  # Fallback if `listDisclosureSettingsDS` returns NULL:
  if (length(nfilter_tab) == 0) nfilter_tab = .getPrivacyLevel()
  if (length(truth) < nfilter_tab)
    stop("More than ", nfilter_tab, " observations are required to ensure privacy!")

  nv = prob[truth == 0]
  if (return_sum) return(sum(nv))

  if (is.null(m))
    return(stats::var(nv) * (length(nv) - 1))
  else
    return(sum((nv - m)^2))
}

#' @title Return negative scores
#' @description This function just returns negative scores and is used
#'   as aggregator to send these positive scores.
#' @param truth_name (`character(1L)`) Character containing the name of the vector of 0-1-values
#'   encoded as integer or numeric.
#' @param prob_name (`character(1L)`) Character containing the name of the vector of probabilities.
#' @param epsilon (`numeric(1L)`) Privacy parameter for differential privacy (DP).
#' @param delta (`numeric(1L)`) Probability of violating epsilon DP.
#' @param seed_object (`character(1L)`) Name of an object which is used
#'   to add a seed based on an object.
#' @param sort (`logical(1L)`) Indicator whether the return values should be
#'   sorted or not.
#' @return Negative scores
#' @author Daniel S.
#' @export
getNegativeScores = function(truth_name, prob_name, epsilon = 0.2, delta = 0.2,
  seed_object = NULL, sort = FALSE) {

  df_pred = checkTruthProb(truth_name, prob_name)
  checkmate::assertNumeric(epsilon, len = 1L, lower = 0, upper = 1)
  checkmate::assertNumeric(delta, len = 1L, lower = 0, upper = 1)

  checkmate::assertCharacter(seed_object, null.ok = TRUE, len = 1L)
  checkmate::assertLogical(sort, len = 1L)

  if (epsilon == 0) stop("Epsilon must be > 0")
  if (delta == 0) stop("Delta must be > 0")

  if (! "l2s" %in% c(ls(envir = .GlobalEnv), ls()))
    stop("Cannot find l2 sensitivity. Please push an l2 sensitivity with name 'l2s' to the servers.")

  l2s = get("l2s", envir = parent.frame())
  #l2s = eval(parse(text = "l2s"))
  checkmate::assertNumeric(l2s, len = 1L, lower = 0, any.missing = FALSE)
  if (l2s == 0) stop("L2 sensitivity must be > 0")

  truth = df_pred$truth
  prob  = df_pred$prob

  if (sort) {
    nv  = sort(prob[truth == 0])
  } else {
    nv  = prob[truth == 0]
  }
  sde = GMVar(l2s, epsilon, delta)
  if (sde <= 0) stop("Standard deviation must be positive to ensure privacy!")

  if (! is.null(seed_object)) {
    seed = seedBoundedToObject(seed_object)
    set.seed(seed)
  }

  out = stats::rnorm(n = length(nv), mean = nv, sd = sde)

  return(out)
}

#' @title Calculate standard deviation for Gaussian Mechanism
#' @param l2s (`numeric(1L)`) l2-sensitivity.
#' @param epsilon (`numeric(1L)`) First privacy parameter for (e,d)-differential privacy.
#' @param delta (`numeric(1L)`) second privacy parameter for (e,d)-differential privacy.
#' @return Numerical value for the standard deviation for the normal distribution.
#' @author Daniel S.
GMVar = function(l2s, epsilon, delta) {
  checkmate::assertNumeric(l2s, len = 1L)
  checkmate::assertNumeric(epsilon, len = 1L)
  checkmate::assertNumeric(delta, len = 1L)

  return(sqrt(2 * log(1.25 / delta)) * l2s / epsilon)
}
