#' @title Get the session information of the DataSHIELD server
#' @description This method returns `sessionInfo()` from the used DataSHIELD servers.
#'   The main purpose is for testing and checking the environment used on the remote servers.
#' @return list of session infos returned from `sessionInfo()` of each machine
#' @author Daniel S.
#' @export

getDataSHIELDInfo = function() {
  out = list(
    session_info = utils::sessionInfo(),
    pcks = utils::installed.packages())

  return(out)
}

# Get `datashield.privacyLevel` from DESCRIPTION file. Note that we do not set the option
# as DataSHIELD does because of the risk of highjacking the R environment. Instead, when
# a function is called that uses the privacy level, the function gets it directly from the
# DESCRIPTION file.
.getPrivacyLevel = function() {
  pl = utils::packageDescription("dsBinVal")$Options
  pl = as.integer(gsub("\\D", "", pl))
  if (is.na(pl)) stop("No privacy level specified in DESCRIPTION.")
  return(pl)
}

.suppressDataSHIELDProgress = function(expr, suppress = TRUE) {
  if (suppress) {
    suppressMessages(expr)
  } else {
    eval(expr)
  }
}

.tryOPALConnection = function(expr) {
  conns = suppressMessages(try(expr, silent = TRUE))
  if (inherits(conns, "opal")) {
    return(conns)
  } else {
    return("Was not able to establish connection")
  }
}

.dsDim = function(connections, symbol = "D") {
  checkmate::assertCharacter(symbol)

  cl = paste0("internDim(\"", symbol, "\")")
  lldim = DSI::datashield.aggregate(conns = connections, cl)
  ddim = Reduce("+", lldim)
  ddim[2] = lldim[[1]][2]

  checkmate::assertIntegerish(ddim)

  return(ddim)
}


.dsNcol = function(connections, symbol = "D") {
  checkmate::assertCharacter(symbol)

  ddim = .dsDim(connections, symbol)
  p = ddim[2]

  return(p)
}

.dsNrow = function(connections, symbol = "D") {
  checkmate::assertCharacter(symbol)

  ddim = .dsDim(connections, symbol)
  n = ddim[1]

  return(n)
}

.dsMean = function(connections, symbol = "D") {
  checkmate::assertCharacter(symbol)

  cl = paste0("internSum(\"", symbol, "\")")
  llm = DSI::datashield.aggregate(conns = connections, cl)
  m = Reduce("+", llm)

  n = .dsLength(connections, symbol)

  checkmate::assertNumeric(m, len = 1L)

  return(m / n)
}

.dsLength = function(connections, symbol = "D") {
  checkmate::assertCharacter(symbol)

  cl = paste0("internLength(\"", symbol, "\")")

  lln = DSI::datashield.aggregate(conns = connections, cl)
  n = Reduce("+", lln)

  checkmate::assertIntegerish(n, len = 1L)

  return(n)
}

#' @title Get number of rows
#' @param symbol (`character(1L)`) \cr
#'   Name of the variable at the DataSHIELD server.
#' @return Number of rows (nrow).
#' @author Daniel S.
#' @export
internN = function(symbol = "D") {
  x = eval(parse(text = symbol), envir = .GlobalEnv)
  checkmate::assertDataFrame(x)
  n = nrow(x)

  nfilter_privacy = .getPrivacyLevel()
  if (n < nfilter_privacy)
    stop("data must have more than ", nfilter_privacy, " rows")

  return(n)
}

#' @title Get data dimension
#' @param symbol (`character(1L)`) \cr
#'   Name of the variable at the DataSHIELD server.
#' @return data dimension (dim).
#' @author Daniel S.
#' @export
internDim = function(symbol = "D") {
  x = eval(parse(text = symbol), envir = .GlobalEnv)
  checkmate::assertDataFrame(x)
  ddim = dim(x)

  nfilter_privacy = .getPrivacyLevel()
  if (ddim[1] < nfilter_privacy)
    stop("data must have more than ", nfilter_privacy, " rows")

  return(ddim)
}

#' @title Get sum of vector
#' @param symbol (`character(1L)`) \cr
#'   Name of the variable at the DataSHIELD server.
#' @return sum
#' @author Daniel S.
#' @export
internSum = function(symbol) {
  x = eval(parse(text = symbol), envir = .GlobalEnv)
  checkmate::assertNumeric(x)

  nfilter_privacy = .getPrivacyLevel()
  if (length(x) < nfilter_privacy)
    stop(symbol, " must have more than ", nfilter_privacy, " rows")

  mout = sum(x)
  return(mout)
}

#' @title Get length of vector
#' @param symbol (`character(1L)`) \cr
#'   Name of the variable at the DataSHIELD server.
#' @return length
#' @author Daniel S.
#' @export
internLength = function(symbol) {
  x = eval(parse(text = symbol), envir = .GlobalEnv)
  n = length(x)
  return(n)

}

.getGlobalEnvVars = function() {
  fglobal = ls(envir = .GlobalEnv)
  return(fglobal)
}

.rmGlobalEnv = function() {
  fglobal = .getGlobalEnvVars()
  rm(list = fglobal, envir = .GlobalEnv)
  return(invisible(NULL))
}

#' @title Truth and Prediction Checker
#' @description This function checks if the vector of true values and predictions
#'   has the correct format to be used for the ROC-GLM. If something does not suit,
#'   then the function tries to convert it into the correct format.
#' @param truth_name (`character(1L)`) Character containing the name of the vector of 0-1-values
#'   encoded as integer or numeric.
#' @param prob_name (`character(1L)`) Character containing the name of the vector of probabilities.
#' @param pos (`character(1L)`) Character containing the name of the positive class.
#' @return Data frame containing the truth and prediction vector.
#' @author Daniel S.
checkTruthProb = function(truth_name, prob_name, pos = NULL) {

  checkmate::assertCharacter(truth_name, len = 1L, any.missing = FALSE)
  checkmate::assertCharacter(prob_name, len = 1L, any.missing = FALSE)

  #truth = eval(parse(text = truth_name))
  truth = get(truth_name, envir = parent.frame())
  #prob = eval(parse(text = prob_name))
  prob = get(prob_name, envir = parent.frame())

  if (length(unique(truth)) > 2)
    stop("\"", truth_name, "\" contains ", length(unique(truth)), " > 2 elements! Two are required!")

  ntruth = length(truth)
  checkmate::assertNumeric(prob, any.missing = FALSE, len = ntruth, null.ok = FALSE, finite = TRUE)

  if (is.null(pos)) {
    if (is.character(truth) | is.factor(truth)) {
      warning("\"", truth_name, "\" is not encoded as 0-1 integer, conversion is done automatically.",
        "This may lead to a label flip! Set argument \"pos\" to ensure correct encoding.")
    }

    if (is.character(truth))
      truth = as.integer(as.factor(truth))

    if (is.factor(truth))
      truth = as.integer(truth)

    if (max(truth) == 2)
      truth = truth - 1
  } else {
    if (is.character(truth) | is.factor(truth))
      truth = ifelse(truth == pos, 1, 0)

    if (is.numeric(truth)) {
      warning(quote("pos"), " is set but \"", truth_name, "\" is numeric. Are you sure",
        " you know what the response really is?")
    }
  }
  return(invisible(data.frame(truth = truth, prob = prob)))
}

