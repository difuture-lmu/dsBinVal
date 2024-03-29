#' @title Compute Placement Values on Server
#' @description This function calculates the placement values required to calculate the ROC-GLM.
#' @param pooled_scores_name (`character(1L)`) Name of the object holding the pooled negative scores.
#' @param truth_name (`character(1L)`) Character containing the name of the vector of 0-1-values encoded
#'   as integer or numeric.
#' @param prob_name (`character(1L)`) Character containing the name of the vector of probabilities.
#' @param tset (`numeric()`) Set of thresholds
#' @return Placement values
#' @author Stefan B., Daniel S.
computePlacementValues = function(pooled_scores_name, truth_name, prob_name, tset = NULL) {
  df_pred = checkTruthProb(truth_name, prob_name)
  checkmate::assertCharacter(pooled_scores_name, len = 1L)
  checkmate::assertNumeric(tset, any.missing = FALSE)

  truth = df_pred$truth
  prob  = df_pred$prob

  p_scores = eval(parse(text = pooled_scores_name))
  p_scores = get(pooled_scores_name, envir = parent.frame())

  ecdf_emp = stats::ecdf(p_scores)
  surv_emp = function(x) 1 - ecdf_emp(x)

  if (is.null(tset)) {
    tset = prob[truth == 1]
  }
  tset = sort(tset)

  return(surv_emp(tset))
}

#' @title Calculate U Matrix for ROC-GLM
#' @description This function calculates U matrix which is used as target variable for the ROC-GLM.
#' @param tset (`numeric()`) Set of thresholds
#' @param pv (`numeric()`) Placement values
#' @return Matrix of zeros and ones that are used as target variable for Probit regression
#' @author Stefan B., Daniel S.
calcU = function(tset, pv) {
  checkmate::assertNumeric(tset, any.missing = FALSE)
  checkmate::assertNumeric(pv, any.missing = FALSE)

  tset_sorted = sort(tset)
  out = vapply(
    X         = tset,
    FUN.VALUE = integer(length(pv)),
    FUN       = function(th) ifelse(pv <= th, 1L, 0L))

  return(out)
}

#' @title Get Data for ROC-GLM
#' @description This function calculates the data used for the ROC-GLM
#' @param U (`matrix()`) Response matrix for ROC-GLM
#' @param tset (`numeric()`) Set of thresholds
#' @return Data used for the ROC-GLM
#' @author Stefan B., Daniel S.
rocGLMData = function(U, tset) {
  checkmate::assertIntegerish(U, lower = 0, upper = 1)
  checkmate::assertNumeric(tset, any.missing = FALSE)

  roc_glm_data = data.frame(
    y = rep(c(0, 1), times = length(tset)),
    x = rep(stats::qnorm(tset), each = 2L),
    w = as.vector(apply(X = U, MARGIN = 2, FUN = function(x) c(sum(x == 0), sum(x == 1))))
  )
  return(roc_glm_data)
}

#' @title Calculate data for ROC-GLM
#' @description This function stores the data on the server used for the ROC-GLM
#' @param truth_name (`character(1L)`) Character containing the name of the vector of 0-1-values
#'   encoded as integer or numeric.
#' @param prob_name (`character(1L)`) Character containing the name of the vector of probabilities.
#' @param pooled_scores_name (`character(1L)`) Character containing the name of the object holding
#'   the pooled negative scores.
#' @return Data.frame used to calculate ROC-GLM
#' @author Stefan B., Daniel S.
#' @export
rocGLMFrame = function(truth_name, prob_name, pooled_scores_name) {

  #############################################################
  #MODULE 1: CAPTURE THE nfilter SETTINGS
  thr = dsBase::listDisclosureSettingsDS()
  nfilter_tab = as.numeric(thr$nfilter.tab)
  #nfilter_glm = as.numeric(thr$nfilter.glm)
  #nfilter_subset = as.numeric(thr$nfilter.subset)
  #nfilter_string = as.numeric(thr$nfilter.string)
  #############################################################

  checkmate::assertCharacter(pooled_scores_name, len = 1L)
  df_pred = checkTruthProb(truth_name, prob_name)

  truth = df_pred$truth
  prob  = df_pred$prob

  # Fallback if `listDisclosureSettingsDS` returns NULL:
  if (length(nfilter_tab) == 0) nfilter_tab = .getPrivacyLevel()
  if (length(truth) < nfilter_tab)
    stop("More than ", nfilter_tab, " observations are required to ensure privacy!")

  tset = prob[truth == 1]
  pv   = computePlacementValues(pooled_scores_name, truth_name, prob_name, tset)
  u    = calcU(tset, pv)
  roc_glm_data = rocGLMData(u, tset)

  return(roc_glm_data)
}


#' @title Calculate Parts for Fisher Scoring
#' @description This function calculates the parts required to conduct an update for the
#'   Fisher scoring for probit regression
#' @param formula (`character(1L)`) Formula used for the probit regression as character.
#' @param data (`character(1L)`) Data as character string. Note that all servers must have data of that name.
#' @param w (`character(1L)`) Weights as character. The weight vector must be a column in `data`.
#' @param params_char (`character(1L)`) Parameter vector encoded as one string.
#' @return List with XtX, Xy, and the likelihood of the respective server.
#' @author Daniel S.
#' @export
calculateDistrGLMParts = function(formula, data,  w = NULL, params_char) {

  #############################################################
  #MODULE 1: CAPTURE THE nfilter SETTINGS
  thr = dsBase::listDisclosureSettingsDS()
  #nfilter_tab = as.numeric(thr$nfilter.tab)
  nfilter_glm = as.numeric(thr$nfilter.glm)
  #nfilter_subset = as.numeric(thr$nfilter.subset)
  #nfilter_string = as.numeric(thr$nfilter.string)
  #############################################################

  if (inherits(formula, "formula")) {
    checkmate::assertFormula(formula)
  } else {
    checkmate::assertCharacter(formula, len = 1L)
  }
  checkmate::assertCharacter(data, len = 1L, any.missing = FALSE)
  checkmate::assertCharacter(w, null.ok = TRUE, len = 1L, any.missing = FALSE)
  checkmate::assertCharacter(params_char, len = 1L, any.missing = FALSE)

  fm = format(formula)
  target = strsplit(fm, " ~ ")[[1]][1]

  eval(parse(text = paste0("X = model.matrix(", fm, ", data = ", data, ")")))
  eval(parse(text = paste0("y = as.integer(", data, "[['", target, "']])")))
  if (max(y) == 2) y = y - 1

  if (!is.null(w)) {
    wget = paste0("w = ", data, "[['", w, "']]")
    eval(parse(text = wget))
  } else {
    w = rep(1, length(y))
  }

  if (params_char == "xxx") {
    beta = rep(0, ncol(X))
  } else {
    beta = unlist(lapply(X = strsplit(params_char, "xnx")[[1]], FUN = function(p) {
      sp = strsplit(p, "xex")
      params = vapply(sp, FUN.VALUE = numeric(1L), function(s) as.numeric(s[2]))
      names(params) = vapply(sp, FUN.VALUE = character(1L), function(s) s[1])

      return(params)
    }))
  }

  # Fallback if `listDisclosureSettingsDS` returns NULL:
  if (length(nfilter_glm) == 0) nfilter_glm = 1 / .getPrivacyLevel()
  if ((nfilter_glm * nrow(X)) < length(beta))
    stop("Number of parameters must be greater then the number of observations.")

  w_mat = diag(sqrt(w))
  lambda = calculateLambda(y, X, beta)
  W = diag(as.vector(lambda * (X %*% beta + lambda)))

  if (! is.null(w)) {
    X = w_mat %*% X
    lambda = w_mat %*% lambda
  }
  xtx = t(X) %*% W %*% X
  xy = t(X) %*% lambda

  out = list(
    XtX = xtx,
    Xy = xy,
    likelihood = probitLikelihood(y, X, beta))

  return(out)
}

#' @title Transform Response for Probit Fisher-Scoring
#' @description This function transform the original 0-1-response y  to a new reponse
#'   "lambda" that is used as respone for the fisher scoring.
#' @param y Original 0-1-response
#' @param X Design matrix
#' @param beta Estimated parameter vector
#' @return Numeric vector of new response
#' @author Stefan B., Daniel S.
calculateLambda = function(y, X, beta) {
  checkmate::assertIntegerish(y, lower = 0, upper = 1)
  checkmate::assertNumeric(X)

  if (nrow(X) != length(y))
    stop("nrows of X must be the same length of y")

  if (ncol(X) != length(beta))
    stop("ncols of X must be the same length of beta")

  eta = X %*% beta
  q = 2 * y - 1
  qeta = q * eta

  lambda = (stats::dnorm(qeta) * q) / (stats::pnorm(qeta))
  return(lambda)
}

#' @title Calculate Likelihood of Probit Model
#' @description This function calculates the likelihood used in a probit regression
#'   (Bernoulli distribution + probit link).
#' @param y Original 0-1-response
#' @param X Design matrix
#' @param beta Estimated parameter vector
#' @param w Weight vector
#' @return Numeric value containing the likelihood
#' @author Stefan B., Daniel S.
probitLikelihood = function(y, X, beta, w = NULL) {
  checkmate::assertIntegerish(y, lower = 0, upper = 1)
  checkmate::assertNumeric(X)
  checkmate::assertNumeric(w, null.ok = TRUE, len = length(y))

  if (nrow(X) != length(y))
    stop("nrows of X must be the same length of y")

  if (ncol(X) != length(beta))
    stop("ncols of X must be the same length of beta")

  eta = X %*% beta

  if (is.null(w)) {
    w = rep(1, times = nrow(X))
  }
  lh = stats::pnorm(eta)^y * (1 - stats::pnorm(eta))^(1 - y)
  return(prod(lh^w))
}

#'
#' @title Calculate AUC from ROC-GLM
#' @description This function calculates the AUC from the ROC-GLM by integrating the binormal
#'   form `pnorm(a + b*qnorm(x))`  for x in 0 to 1. The parameter a and b are obtained by `dsROCGLM`.
#' @param roc_glm (`list()`) List containing the ROC-GLM parameter returned from `dsROCGLM`.
#' @return Numeric value of the approximated AUC.
#' @author Daniel S.
#' @export
calculateAUC = function(roc_glm) {
  if (! inherits(roc_glm, "ROC.GLM"))
    stop("roc_glm must be of class ROC.GLM")

  params = roc_glm$parameter
  temp = function(x) {
    stats::pnorm(params[1] + params[2] * stats::qnorm(x))
  }
  int  = stats::integrate(f = temp, lower = 0, upper = 1)
  vint = int$value

  icheck = (vint > 1) || (vint < 0)
  if (icheck) {
    warning("Integrating the binormal model gives an AUC out of the [0,1] range")
  }
  return(vint)
}
