
<!-- README.md is generated from README.Rmd. Please edit that file -->

[![R-CMD-check](https://github.com/difuture-lmu/dsBinVal/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/difuture-lmu/dsBinVal/actions/workflows/R-CMD-check.yaml)
[![License: LGPL
v3](https://img.shields.io/badge/License-LGPL%20v3-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0)
[![codecov](https://codecov.io/gh/difuture-lmu/dsBinVal/branch/main/graph/badge.svg?token=E8AZRM6XJX)](https://codecov.io/gh/difuture-lmu/dsBinVal)

# ROC-GLM and Calibration for DataSHIELD

The package provides functionality to conduct and visualize ROC analysis
and calibration on decentralized data. The basis is the
[DataSHIELD](https://www.datashield.org/) infrastructure for distributed
computing. This package provides the calculation of the
[**ROC-GLM**](https://www.jstor.org/stable/2676973?seq=1) with [**AUC
confidence intervals**](https://www.jstor.org/stable/2531595?seq=1) as
well as calibration curves and the brier score. In order to calculate
the ROC-GLM or assess calibration it is necessary to push models and
predict them at the servers which is also provided by this package. Note
that DataSHIELD uses an option `datashield.privacyLevel` to indicate the
minimal amount of numbers required to be allowed to share an aggregated
value of these numbers. Instead of setting the option, we directly
retrieve the privacy level from the
[`DESCRIPTION`](https://github.com/difuture-lmu/dsBinVal/blob/master/DESCRIPTION)
file each time a function calls for it. This options is set to 5 by
default. The methodological base of th epackage is explained in detail
[here](https://arxiv.org/abs/2203.10828).

## Installation

At the moment, there is no CRAN version available. Install the
development version from GitHub:

``` r
remotes::install_github("difuture-lmu/dsBinVal")
```

#### Register methods

It is necessary to register the assign and aggregate methods in the OPAL
administration. These methods are registered automatically when
publishing the package on OPAL (see
[`DESCRIPTION`](https://github.com/difuture-lmu/dsBinVal/blob/main/DESCRIPTION)).

Note that the package needs to be installed at both locations, the
server and the analysts machine.

## Installation on DataSHIELD

The two options are to use the Opal API:

- Log into Opal ans switch to the `Administration/DataSHIELD/` tab
- Click the `Add DataSHIELD package` button
- Select `GitHub` as source, and use `difuture-lmu` as user, `dsBinVal`
  as name, and `main` as Git reference.

The second option is to use the `opalr` package to install `dsBinVal`
directly from `R`:

``` r
### User credentials (here from the opal test server):
surl     = "https://opal-demo.obiba.org/"
username = "administrator"
password = "password"

### Install package and publish methods:
opal = opalr::opal.login(username = username, password = password, url = surl)

opalr::dsadmin.install_github_package(opal = opal, pkg = "dsBinVal", username = "difuture-lmu", ref = "main")
opalr::dsadmin.publish_package(opal = opal, pkg = "dsBinVal")

opalr::opal.logout(opal)
```

## Usage

A more sophisticated example is available
[here](github.com/difuture-lmu/datashield-roc-glm-demo).

``` r
library(DSI)
#> Loading required package: progress
#> Loading required package: R6
library(DSOpal)
#> Loading required package: opalr
#> Loading required package: httr
library(dsBaseClient)

library(dsBinVal)
```

#### Log into DataSHIELD server

``` r
builder = newDSLoginBuilder()

surl     = "https://opal-demo.obiba.org/"
username = "administrator"
password = "password"

builder$append(
  server   = "ds1",
  url      = surl,
  user     = username,
  password = password,
  table    = "CNSIM.CNSIM1"
)
builder$append(
  server   = "ds2",
  url      = surl,
  user     = username,
  password = password,
  table    = "CNSIM.CNSIM2"
)
builder$append(
  server   = "ds3",
  url      = surl,
  user     = username,
  password = password,
  table    = "CNSIM.CNSIM3"
)

connections = datashield.login(logins = builder$build(), assign = TRUE)
#> 
#> Logging into the collaborating servers
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Login ds1 [==================>---------------------------------------------------------]  25% / 0s  Login ds2 [=====================================>--------------------------------------]  50% / 0s  Login ds3 [========================================================>-------------------]  75% / 1s  Logged in all servers [================================================================] 100% / 1s
#> 
#>   No variables have been specified. 
#>   All the variables in the table 
#>   (the whole dataset) will be assigned to R!
#> 
#> Assigning table data...
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Assigning ds1 (CNSIM.CNSIM1) [=============>-------------------------------------------]  25% / 1s  Assigning ds2 (CNSIM.CNSIM2) [===========================>-----------------------------]  50% / 1s  Assigning ds3 (CNSIM.CNSIM3) [==========================================>--------------]  75% / 1s  Assigned all tables [==================================================================] 100% / 1s
```

#### Load test model, push to DataSHIELD, and calculate predictions

``` r
# Load the model fitted locally on CNSIM:
load(here::here("Readme_files/mod.rda"))
# Model was calculated by:
#> glm(DIS_DIAB ~ ., data = CNSIM, family = binomial())

# Push the model to the DataSHIELD servers:
pushObject(connections, mod)
#> [2022-10-26 17:17:18] Your object is bigger than 1 MB (5.75186157226562 MB). Uploading larger objects may take some time.
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (mod <- decodeBinary("580a000000030004020100030500000000055554462d3800000313000000...  Finalizing assignment ds1 (mod <- decodeBinary("580a000000030004020100030500000000055554462d380...  Checking ds2 (mod <- decodeBinary("580a000000030004020100030500000000055554462d3800000313000000...  Finalizing assignment ds2 (mod <- decodeBinary("580a000000030004020100030500000000055554462d380...  Checking ds3 (mod <- decodeBinary("580a000000030004020100030500000000055554462d3800000313000000...  Finalizing assignment ds3 (mod <- decodeBinary("580a000000030004020100030500000000055554462d380...  Assigned expr. (mod <- decodeBinary("580a000000030004020100030500000000055554462d38000003130000...

# Create a clean data set without NAs:
ds.completeCases("D", newobj = "D_complete")
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (exists("D")) [-----------------------------------------------------------]   0% / 0s  Getting aggregate ds1 (exists("D")) [===========>--------------------------------------]  25% / 0s  Checking ds2 (exists("D")) [==============>--------------------------------------------]  25% / 0s  Getting aggregate ds2 (exists("D")) [========================>-------------------------]  50% / 0s  Checking ds3 (exists("D")) [=============================>-----------------------------]  50% / 0s  Getting aggregate ds3 (exists("D")) [=====================================>------------]  75% / 0s  Aggregated (exists("D")) [=============================================================] 100% / 0s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (D_complete <- completeCasesDS("D")) [------------------------------------]   0% / 0s  Finalizing assignment ds1 (D_complete <- completeCasesDS("D")) [=====>-----------------]  25% / 0s  Checking ds2 (D_complete <- completeCasesDS("D")) [========>---------------------------]  25% / 0s  Finalizing assignment ds2 (D_complete <- completeCasesDS("D")) [===========>-----------]  50% / 0s  Checking ds3 (D_complete <- completeCasesDS("D")) [=================>------------------]  50% / 0s  Finalizing assignment ds3 (D_complete <- completeCasesDS("D")) [================>------]  75% / 0s  Assigned expr. (D_complete <- completeCasesDS("D")) [==================================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (testObjExistsDS("D_complete")) [-----------------------------------------]   0% / 0s  Getting aggregate ds1 (testObjExistsDS("D_complete")) [=======>------------------------]  25% / 0s  Checking ds2 (testObjExistsDS("D_complete")) [=========>-------------------------------]  25% / 0s  Getting aggregate ds2 (testObjExistsDS("D_complete")) [===============>----------------]  50% / 0s  Checking ds3 (testObjExistsDS("D_complete")) [===================>---------------------]  50% / 0s  Getting aggregate ds3 (testObjExistsDS("D_complete")) [=======================>--------]  75% / 0s  Aggregated (testObjExistsDS("D_complete")) [===========================================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (messageDS("D_complete")) [-----------------------------------------------]   0% / 0s  Getting aggregate ds1 (messageDS("D_complete")) [=========>----------------------------]  25% / 0s  Checking ds2 (messageDS("D_complete")) [===========>-----------------------------------]  25% / 0s  Getting aggregate ds2 (messageDS("D_complete")) [==================>-------------------]  50% / 0s  Checking ds3 (messageDS("D_complete")) [=======================>-----------------------]  50% / 0s  Getting aggregate ds3 (messageDS("D_complete")) [===========================>----------]  75% / 0s  Aggregated (messageDS("D_complete")) [=================================================] 100% / 1s
#> $is.object.created
#> [1] "A data object <D_complete> has been created in all specified data sources"
#> 
#> $validity.check
#> [1] "<D_complete> appears valid in all sources"

# Calculate scores and save at the servers:
pfun =  "predict(mod, newdata = D, type = 'response')"
predictModel(connections, mod, "pred", "D_complete", predict_fun = pfun)
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (pred <- assignPredictModel("580a000000030004020100030500000000055554462d380000001...  Finalizing assignment ds1 (pred <- assignPredictModel("580a000000030004020100030500000000055554...  Checking ds2 (pred <- assignPredictModel("580a000000030004020100030500000000055554462d380000001...  Finalizing assignment ds2 (pred <- assignPredictModel("580a000000030004020100030500000000055554...  Checking ds3 (pred <- assignPredictModel("580a000000030004020100030500000000055554462d380000001...  Finalizing assignment ds3 (pred <- assignPredictModel("580a000000030004020100030500000000055554...  Assigned expr. (pred <- assignPredictModel("580a000000030004020100030500000000055554462d3800000...

datashield.symbols(connections)
#> $ds1
#> [1] "D"          "D_complete" "mod"        "pred"      
#> 
#> $ds2
#> [1] "D"          "D_complete" "mod"        "pred"      
#> 
#> $ds3
#> [1] "D"          "D_complete" "mod"        "pred"
```

#### Calculate l2-sensitivity

``` r
# In order to securely calculate the ROC-GLM, we have to assess the
# l2-sensitivity to set the privacy parameters of differential
# privacy adequately:
l2s = dsL2Sens(connections, "D_complete", "pred")
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (internDim("D_complete")) [-----------------------------------------------]   0% / 0s  Getting aggregate ds1 (internDim("D_complete")) [=========>----------------------------]  25% / 0s  Checking ds2 (internDim("D_complete")) [===========>-----------------------------------]  25% / 0s  Getting aggregate ds2 (internDim("D_complete")) [==================>-------------------]  50% / 0s  Checking ds3 (internDim("D_complete")) [=======================>-----------------------]  50% / 0s  Getting aggregate ds3 (internDim("D_complete")) [===========================>----------]  75% / 0s  Aggregated (...) [=====================================================================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (xXcols <- decodeBinary("580a000000030004020100030500000000055554462d38000000fe", ...  Finalizing assignment ds1 (xXcols <- decodeBinary("580a000000030004020100030500000000055554462d...  Checking ds2 (xXcols <- decodeBinary("580a000000030004020100030500000000055554462d38000000fe", ...  Finalizing assignment ds2 (xXcols <- decodeBinary("580a000000030004020100030500000000055554462d...  Checking ds3 (xXcols <- decodeBinary("580a000000030004020100030500000000055554462d38000000fe", ...  Finalizing assignment ds3 (xXcols <- decodeBinary("580a000000030004020100030500000000055554462d...  Assigned expr. (xXcols <- decodeBinary("580a000000030004020100030500000000055554462d38000000fe"...
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [--------------]   0% / 0s  Getting aggregate ds1 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [>----]  25% / 0s  Checking ds2 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [===>----------]  25% / 0s  Checking ds3 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [===>----------]  25% / 0s  Waiting...  (...) [================>---------------------------------------------------]  25% / 0s  Checking ds2 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [===>----------]  25% / 0s  Getting aggregate ds2 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [=>---]  50% / 0s  Checking ds3 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [======>-------]  50% / 1s  Waiting...  (...) [=================================>----------------------------------]  50% / 1s  Checking ds3 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [======>-------]  50% / 1s  Getting aggregate ds3 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [===>-]  75% / 1s  Aggregated (...) [=====================================================================] 100% / 1s
l2s
#> [1] 0.001476

# Due to the results presented in https://arxiv.org/abs/2203.10828, we set the privacy parameters to
# - epsilon = 0.2, delta = 0.1 if        l2s <= 0.01
# - epsilon = 0.3, delta = 0.4 if 0.01 < l2s <= 0.03
# - epsilon = 0.5, delta = 0.3 if 0.03 < l2s <= 0.05
# - epsilon = 0.5, delta = 0.5 if 0.05 < l2s <= 0.07
# - epsilon = 0.5, delta = 0.5 if 0.07 < l2s BUT results may be not good!
```

#### Calculate ROC-GLM

``` r
# The response must be encoded as integer/numeric vector:
ds.asInteger("D_complete$DIS_DIAB", "truth")
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (exists("DIS_DIAB", D_complete)) [----------------------------------------]   0% / 0s  Getting aggregate ds1 (exists("DIS_DIAB", D_complete)) [=======>-----------------------]  25% / 0s  Checking ds2 (exists("DIS_DIAB", D_complete)) [=========>------------------------------]  25% / 0s  Getting aggregate ds2 (exists("DIS_DIAB", D_complete)) [===============>---------------]  50% / 0s  Checking ds3 (exists("DIS_DIAB", D_complete)) [===================>--------------------]  50% / 0s  Getting aggregate ds3 (exists("DIS_DIAB", D_complete)) [======================>--------]  75% / 0s  Aggregated (exists("DIS_DIAB", D_complete)) [==========================================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (truth <- asIntegerDS("D_complete$DIS_DIAB")) [---------------------------]   0% / 0s  Finalizing assignment ds1 (truth <- asIntegerDS("D_complete$DIS_DIAB")) [===>----------]  25% / 0s  Checking ds2 (truth <- asIntegerDS("D_complete$DIS_DIAB")) [======>--------------------]  25% / 0s  Finalizing assignment ds2 (truth <- asIntegerDS("D_complete$DIS_DIAB")) [======>-------]  50% / 0s  Checking ds3 (truth <- asIntegerDS("D_complete$DIS_DIAB")) [=============>-------------]  50% / 0s  Finalizing assignment ds3 (truth <- asIntegerDS("D_complete$DIS_DIAB")) [=========>----]  75% / 0s  Assigned expr. (truth <- asIntegerDS("D_complete$DIS_DIAB")) [=========================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (testObjExistsDS("truth")) [----------------------------------------------]   0% / 0s  Getting aggregate ds1 (testObjExistsDS("truth")) [========>----------------------------]  25% / 0s  Checking ds2 (testObjExistsDS("truth")) [===========>----------------------------------]  25% / 0s  Getting aggregate ds2 (testObjExistsDS("truth")) [=================>-------------------]  50% / 0s  Checking ds3 (testObjExistsDS("truth")) [======================>-----------------------]  50% / 0s  Getting aggregate ds3 (testObjExistsDS("truth")) [===========================>---------]  75% / 0s  Aggregated (testObjExistsDS("truth")) [================================================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (messageDS("truth")) [----------------------------------------------------]   0% / 0s  Getting aggregate ds1 (messageDS("truth")) [==========>--------------------------------]  25% / 0s  Checking ds2 (messageDS("truth")) [============>---------------------------------------]  25% / 0s  Getting aggregate ds2 (messageDS("truth")) [=====================>---------------------]  50% / 0s  Checking ds3 (messageDS("truth")) [=========================>--------------------------]  50% / 0s  Getting aggregate ds3 (messageDS("truth")) [===============================>-----------]  75% / 0s  Aggregated (messageDS("truth")) [======================================================] 100% / 1s
#> $is.object.created
#> [1] "A data object <truth> has been created in all specified data sources"
#> 
#> $validity.check
#> [1] "<truth> appears valid in all sources"
roc_glm = dsROCGLM(connections, truth_name = "truth", pred_name = "pred",
  dat_name = "D_complete", seed_object = "pred")
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (internDim("D_complete")) [-----------------------------------------------]   0% / 0s  Getting aggregate ds1 (internDim("D_complete")) [=========>----------------------------]  25% / 0s  Checking ds2 (internDim("D_complete")) [===========>-----------------------------------]  25% / 0s  Getting aggregate ds2 (internDim("D_complete")) [==================>-------------------]  50% / 0s  Checking ds3 (internDim("D_complete")) [=======================>-----------------------]  50% / 0s  Getting aggregate ds3 (internDim("D_complete")) [===========================>----------]  75% / 0s  Aggregated (...) [=====================================================================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (xXcols <- decodeBinary("580a000000030004020100030500000000055554462d38000000fe", ...  Finalizing assignment ds1 (xXcols <- decodeBinary("580a000000030004020100030500000000055554462d...  Checking ds2 (xXcols <- decodeBinary("580a000000030004020100030500000000055554462d38000000fe", ...  Finalizing assignment ds2 (xXcols <- decodeBinary("580a000000030004020100030500000000055554462d...  Checking ds3 (xXcols <- decodeBinary("580a000000030004020100030500000000055554462d38000000fe", ...  Finalizing assignment ds3 (xXcols <- decodeBinary("580a000000030004020100030500000000055554462d...  Assigned expr. (xXcols <- decodeBinary("580a000000030004020100030500000000055554462d38000000fe"...
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [--------------]   0% / 0s  Getting aggregate ds1 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [>----]  25% / 0s  Checking ds2 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [===>----------]  25% / 0s  Checking ds3 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [===>----------]  25% / 0s  Waiting...  (...) [================>---------------------------------------------------]  25% / 0s  Checking ds2 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [===>----------]  25% / 0s  Getting aggregate ds2 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [=>---]  50% / 0s  Checking ds3 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [======>-------]  50% / 1s  Waiting...  (...) [=================================>----------------------------------]  50% / 1s  Checking ds3 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [======>-------]  50% / 1s  Getting aggregate ds3 (l2sens("D_complete", "pred", 2292, "xXcols", diff, TRUE)) [===>-]  75% / 1s  Aggregated (...) [=====================================================================] 100% / 1s
#> 
#> [2022-10-26 17:18:42] L2 sensitivity is: 0.0015
#> 
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (l2s <- decodeBinary("580a000000030004020100030500000000055554462d380000000e000000...  Finalizing assignment ds1 (l2s <- decodeBinary("580a000000030004020100030500000000055554462d380...  Checking ds2 (l2s <- decodeBinary("580a000000030004020100030500000000055554462d380000000e000000...  Finalizing assignment ds2 (l2s <- decodeBinary("580a000000030004020100030500000000055554462d380...  Checking ds3 (l2s <- decodeBinary("580a000000030004020100030500000000055554462d380000000e000000...  Finalizing assignment ds3 (l2s <- decodeBinary("580a000000030004020100030500000000055554462d380...  Assigned expr. (l2s <- decodeBinary("580a000000030004020100030500000000055554462d380000000e0000...
#> 
#> [2022-10-26 17:18:42] Setting: epsilon = 0.2 and delta = 0.1
#> 
#> 
#> [2022-10-26 17:18:42] Initializing ROC-GLM
#> 
#> [2022-10-26 17:18:42] Host: Received scores of negative response
#> 
#> [2022-10-26 17:18:42] Receiving negative scores
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (getNegativeScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [------------]   0% / 0s  Getting aggregate ds1 (getNegativeScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [>--]  25% / 0s  Checking ds2 (getNegativeScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [==>---------]  25% / 0s  Getting aggregate ds2 (getNegativeScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [=>-]  50% / 0s  Checking ds3 (getNegativeScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [=====>------]  50% / 0s  Getting aggregate ds3 (getNegativeScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [=>-]  75% / 0s  Aggregated (...) [=====================================================================] 100% / 1s
#> [2022-10-26 17:18:43] Host: Pushing pooled scores
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (pooled_scores <- decodeBinary("580a000000030004020100030500000000055554462d380000...  Finalizing assignment ds1 (pooled_scores <- decodeBinary("580a000000030004020100030500000000055...  Checking ds2 (pooled_scores <- decodeBinary("580a000000030004020100030500000000055554462d380000...  Finalizing assignment ds2 (pooled_scores <- decodeBinary("580a000000030004020100030500000000055...  Checking ds3 (pooled_scores <- decodeBinary("580a000000030004020100030500000000055554462d380000...  Finalizing assignment ds3 (pooled_scores <- decodeBinary("580a000000030004020100030500000000055...  Assigned expr. (pooled_scores <- decodeBinary("580a000000030004020100030500000000055554462d3800...
#> [2022-10-26 17:18:44] Server: Calculating placement values and parts for ROC-GLM
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (roc_data <- rocGLMFrame("truth", "pred", "pooled_scores")) [-------------]   0% / 0s  Finalizing assignment ds1 (roc_data <- rocGLMFrame("truth", "pred", "pooled_scores")) []  25% / 0s  Checking ds2 (roc_data <- rocGLMFrame("truth", "pred", "pooled_scores")) [==>----------]  25% / 0s  Finalizing assignment ds2 (roc_data <- rocGLMFrame("truth", "pred", "pooled_scores")) []  50% / 0s  Checking ds3 (roc_data <- rocGLMFrame("truth", "pred", "pooled_scores")) [=====>-------]  50% / 0s  Finalizing assignment ds3 (roc_data <- rocGLMFrame("truth", "pred", "pooled_scores")) []  75% / 0s  Assigned expr. (roc_data <- rocGLMFrame("truth", "pred", "pooled_scores")) [===========] 100% / 0s
#> [2022-10-26 17:18:45] Server: Calculating probit regression to obtain ROC-GLM
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]  25% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds3 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  50% / 0s  Getting aggregate ds3 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 1s
#> [2022-10-26 17:18:45] Deviance of iter1=38.8162
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]  25% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds3 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  50% / 0s  Getting aggregate ds3 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 1s
#> [2022-10-26 17:18:46] Deviance of iter2=48.9408
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]  25% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds3 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  50% / 0s  Getting aggregate ds3 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 1s
#> [2022-10-26 17:18:46] Deviance of iter3=52.5077
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]  25% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds3 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  50% / 0s  Getting aggregate ds3 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 1s
#> [2022-10-26 17:18:47] Deviance of iter4=52.5684
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]  25% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds3 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  50% / 0s  Getting aggregate ds3 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 1s
#> [2022-10-26 17:18:47] Deviance of iter5=52.5684
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]  25% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds3 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  50% / 0s  Getting aggregate ds3 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 0s
#> [2022-10-26 17:18:48] Deviance of iter6=52.5684
#> [2022-10-26 17:18:48] Host: Finished calculating ROC-GLM
#> [2022-10-26 17:18:48] Host: Cleaning data on server
#> [2022-10-26 17:18:48] Host: Calculating AUC and CI
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (internLength("truth")) [-------------------------------------------------]   0% / 0s  Getting aggregate ds1 (internLength("truth")) [=========>------------------------------]  25% / 0s  Checking ds2 (internLength("truth")) [===========>-------------------------------------]  25% / 0s  Getting aggregate ds2 (internLength("truth")) [===================>--------------------]  50% / 0s  Checking ds3 (internLength("truth")) [=======================>-------------------------]  50% / 0s  Getting aggregate ds3 (internLength("truth")) [=============================>----------]  75% / 0s  Aggregated (...) [=====================================================================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (internSum("truth")) [----------------------------------------------------]   0% / 0s  Getting aggregate ds1 (internSum("truth")) [==========>--------------------------------]  25% / 0s  Checking ds2 (internSum("truth")) [============>---------------------------------------]  25% / 0s  Getting aggregate ds2 (internSum("truth")) [=====================>---------------------]  50% / 0s  Checking ds3 (internSum("truth")) [=========================>--------------------------]  50% / 0s  Getting aggregate ds3 (internSum("truth")) [===============================>-----------]  75% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (internLength("truth")) [-------------------------------------------------]   0% / 0s  Getting aggregate ds1 (internLength("truth")) [=========>------------------------------]  25% / 0s  Checking ds2 (internLength("truth")) [===========>-------------------------------------]  25% / 0s  Getting aggregate ds2 (internLength("truth")) [===================>--------------------]  50% / 0s  Checking ds3 (internLength("truth")) [=======================>-------------------------]  50% / 0s  Getting aggregate ds3 (internLength("truth")) [=============================>----------]  75% / 0s  Aggregated (...) [=====================================================================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (getNegativeScoresVar("truth", "pred", return_sum = TRUE)) [--------------]   0% / 0s  Getting aggregate ds1 (getNegativeScoresVar("truth", "pred", return_sum = TRUE)) [>----]  25% / 0s  Checking ds2 (getNegativeScoresVar("truth", "pred", return_sum = TRUE)) [===>----------]  25% / 0s  Getting aggregate ds2 (getNegativeScoresVar("truth", "pred", return_sum = TRUE)) [=>---]  50% / 0s  Checking ds3 (getNegativeScoresVar("truth", "pred", return_sum = TRUE)) [======>-------]  50% / 0s  Getting aggregate ds3 (getNegativeScoresVar("truth", "pred", return_sum = TRUE)) [===>-]  75% / 0s  Aggregated (...) [=====================================================================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (getPositiveScoresVar("truth", "pred", return_sum = TRUE)) [--------------]   0% / 0s  Getting aggregate ds1 (getPositiveScoresVar("truth", "pred", return_sum = TRUE)) [>----]  25% / 0s  Checking ds2 (getPositiveScoresVar("truth", "pred", return_sum = TRUE)) [===>----------]  25% / 0s  Getting aggregate ds2 (getPositiveScoresVar("truth", "pred", return_sum = TRUE)) [=>---]  50% / 0s  Checking ds3 (getPositiveScoresVar("truth", "pred", return_sum = TRUE)) [======>-------]  50% / 0s  Getting aggregate ds3 (getPositiveScoresVar("truth", "pred", return_sum = TRUE)) [===>-]  75% / 0s  Aggregated (...) [=====================================================================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (getNegativeScoresVar("truth", "pred", m = 1)) [--------------------------]   0% / 0s  Getting aggregate ds1 (getNegativeScoresVar("truth", "pred", m = 1)) [===>-------------]  25% / 0s  Checking ds2 (getNegativeScoresVar("truth", "pred", m = 1)) [=====>--------------------]  25% / 0s  Getting aggregate ds2 (getNegativeScoresVar("truth", "pred", m = 1)) [=======>---------]  50% / 0s  Checking ds3 (getNegativeScoresVar("truth", "pred", m = 1)) [============>-------------]  50% / 0s  Getting aggregate ds3 (getNegativeScoresVar("truth", "pred", m = 1)) [============>----]  75% / 0s  Aggregated (...) [=====================================================================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (getPositiveScoresVar("truth", "pred", m = 1)) [--------------------------]   0% / 0s  Getting aggregate ds1 (getPositiveScoresVar("truth", "pred", m = 1)) [===>-------------]  25% / 0s  Checking ds2 (getPositiveScoresVar("truth", "pred", m = 1)) [=====>--------------------]  25% / 0s  Getting aggregate ds2 (getPositiveScoresVar("truth", "pred", m = 1)) [=======>---------]  50% / 0s  Checking ds3 (getPositiveScoresVar("truth", "pred", m = 1)) [============>-------------]  50% / 0s  Getting aggregate ds3 (getPositiveScoresVar("truth", "pred", m = 1)) [============>----]  75% / 0s  Aggregated (...) [=====================================================================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (getNegativeScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [------------]   0% / 0s  Getting aggregate ds1 (getNegativeScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [>--]  25% / 0s  Checking ds2 (getNegativeScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [==>---------]  25% / 0s  Getting aggregate ds2 (getNegativeScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [=>-]  50% / 0s  Checking ds3 (getNegativeScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [=====>------]  50% / 0s  Getting aggregate ds3 (getNegativeScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [=>-]  75% / 0s  Aggregated (...) [=====================================================================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (getPositiveScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [------------]   0% / 0s  Getting aggregate ds1 (getPositiveScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [>--]  25% / 0s  Checking ds2 (getPositiveScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [==>---------]  25% / 0s  Getting aggregate ds2 (getPositiveScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [=>-]  50% / 0s  Checking ds3 (getPositiveScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [=====>------]  50% / 0s  Getting aggregate ds3 (getPositiveScores("truth", "pred", 0.2, 0.1, "pred", TRUE)) [=>-]  75% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
#> [2022-10-26 17:18:53] Finished!
roc_glm
#> 
#> ROC-GLM after Pepe:
#> 
#>  Binormal form: pnorm(0.69 + 0.54*qnorm(t))
#> 
#>  AUC and 0.95 CI: [0.66----0.73----0.79]

plot(roc_glm)
```

![](Readme_files/unnamed-chunk-8-1.png)<!-- -->

#### Assess calibration

``` r
dsBrierScore(connections, "truth", "pred")
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (brierScore("truth", "pred")) [-------------------------------------------]   0% / 0s  Getting aggregate ds1 (brierScore("truth", "pred")) [=======>--------------------------]  25% / 0s  Checking ds2 (brierScore("truth", "pred")) [==========>--------------------------------]  25% / 0s  Getting aggregate ds2 (brierScore("truth", "pred")) [================>-----------------]  50% / 0s  Checking ds3 (brierScore("truth", "pred")) [=====================>---------------------]  50% / 0s  Getting aggregate ds3 (brierScore("truth", "pred")) [=========================>--------]  75% / 0s  Aggregated (brierScore("truth", "pred")) [=============================================] 100% / 0s
#> [1] 0.01191

### Calculate and plot calibration curve:
cc = dsCalibrationCurve(connections, "truth", "pred")
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calibrationCurve("truth", "pred", 10, TRUE)) [---------------------------]   0% / 0s  Getting aggregate ds1 (calibrationCurve("truth", "pred", 10, TRUE)) [===>--------------]  25% / 0s  Checking ds2 (calibrationCurve("truth", "pred", 10, TRUE)) [======>--------------------]  25% / 0s  Getting aggregate ds2 (calibrationCurve("truth", "pred", 10, TRUE)) [========>---------]  50% / 0s  Checking ds3 (calibrationCurve("truth", "pred", 10, TRUE)) [=============>-------------]  50% / 0s  Getting aggregate ds3 (calibrationCurve("truth", "pred", 10, TRUE)) [=============>----]  75% / 0s  Aggregated (calibrationCurve("truth", "pred", 10, TRUE)) [=============================] 100% / 0s
cc
#> 
#> Calibration curve:
#> 
#>  Number of shared values:
#>            (0,0.1] (0.1,0.2] (0.2,0.3] (0.3,0.4] (0.4,0.5] (0.5,0.6] (0.6,0.7]
#> n             6791        44        16         9         5         2         7
#> not_shared       0         0         4         3         5         2         2
#>            (0.7,0.8] (0.8,0.9] (0.9,1]
#> n                  1         1       0
#> not_shared         1         1     NaN
#> 
#> Values of the calibration curve:
#>            (0,0.1] (0.1,0.2] (0.2,0.3] (0.3,0.4] (0.4,0.5] (0.5,0.6] (0.6,0.7]
#> truth     0.009571    0.2500    0.2500    0.1111         0         0    0.4286
#> predicted 0.010314    0.1393    0.1835    0.2283         0         0    0.4537
#>           (0.7,0.8] (0.8,0.9] (0.9,1]
#> truth             0         0     NaN
#> predicted         0         0     NaN
#> 
#> 
#> Missing values are indicated by the privacy level of 5.

plot(cc)
#> Warning: Removed 21 rows containing missing values (geom_point).
#> Warning: Removed 21 row(s) containing missing values (geom_path).
#> Warning: Removed 1 rows containing missing values (geom_point).
#> Warning: Removed 1 row(s) containing missing values (geom_path).
```

![](Readme_files/unnamed-chunk-9-1.png)<!-- -->

## Deploy information:

**Build by daniel (Linux) on 2022-10-26 17:18:55.**

This readme is built automatically after each push to the repository.
Hence, it also is a test if the functionality of the package works also
on the DataSHIELD servers. We also test these functionality in
`tests/testthat/test_on_active_server.R`. The system information of the
local and remote servers are as followed:

- Local machine:
  - `R` version: R version 4.2.1 (2022-06-23)
  - Version of DataSHELD client packages:

| Package      | Version |
|:-------------|:--------|
| DSI          | 1.5.0   |
| DSOpal       | 1.3.1   |
| dsBaseClient | 6.2.0   |
| dsBinVal     | 1.0.1   |

- Remote DataSHIELD machines:
  - OPAL version of the test instance: 4.5.2
  - `R` version of ds1: R version 4.2.1 (2022-06-23)
  - `R` version of ds2: R version 4.2.1 (2022-06-23)
  - Version of server packages:

| Package   | ds1: Version | ds2: Version | ds3: Version |
|:----------|:-------------|:-------------|:-------------|
| dsBase    | 6.2.0        | 6.2.0        | 6.2.0        |
| resourcer | 1.3.0        | 1.3.0        | 1.3.0        |
| dsBinVal  | 1.0.1        | 1.0.1        | 1.0.1        |
