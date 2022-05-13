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
  conns = try(expr, silent = TRUE)
  if (inherits(conns, "opal")) {
    return(conns)
  } else {
    return("Was not able to establish connection")
  }
}

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
