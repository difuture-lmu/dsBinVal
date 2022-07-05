
<!-- README.md is generated from README.Rmd. Please edit that file -->

[![R-CMD-check](https://github.com/difuture-lmu/dsBinVal/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/difuture-lmu/dsBinVal/actions/workflows/R-CMD-check.yaml)
[![License: LGPL
v3](https://img.shields.io/badge/License-LGPL%20v3-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0)
[![codecov](https://codecov.io/gh/difuture-lmu/dsBinVal/branch/main/graph/badge.svg?token=E8AZRM6XJX)](https://codecov.io/gh/difuture-lmu/dsBinVal)

# ROC-GLM and Calibration for DataSHIELD

The package provides functionality to conduct and visualize ROC analysis
and calibration on decentralized data. The basis is the
DataSHIELD\](<https://www.datashield.org/>) infrastructure for
distributed computing. This package provides the calculation of the
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
default. The methodology is explained in detail
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
  - Select `GitHub` as source, and use `difuture-lmu` as user,
    `dsBinVal` as name, and `main` as Git reference.

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
  password = password
)
builder$append(
  server   = "ds2",
  url      = surl,
  user     = username,
  password = password
)

connections = datashield.login(logins = builder$build(), assign = TRUE)
#> 
#> Logging into the collaborating servers
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Login ds1 [========================>---------------------------------------------------]  33% / 0s  Login ds2 [==================================================>-------------------------]  67% / 0s  Logged in all servers [================================================================] 100% / 1s
```

#### Assign iris and validation vector at DataSHIELD (just for testing)

``` r
datashield.assign(connections, "iris", quote(iris))
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (iris <- iris) [----------------------------------------------------------]   0% / 1s  Finalizing assignment ds1 (iris <- iris) [==============>------------------------------]  33% / 1s  Checking ds2 (iris <- iris) [==================>---------------------------------------]  33% / 1s  Finalizing assignment ds2 (iris <- iris) [=============================>---------------]  67% / 1s  Assigned expr. (iris <- iris) [========================================================] 100% / 1s
vcall = paste0("quote(c(", paste(rep(c(1, 0), times = c(50, 100)), collapse = ", "), "))")
datashield.assign(connections, "y", eval(parse(text = vcall)))
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (y <- c(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, ) [---]   0% / 0s  Finalizing assignment ds1 (y <- c(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, )...  Checking ds2 (y <- c(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, ) [>--]  33% / 0s  Finalizing assignment ds2 (y <- c(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, )...  Assigned expr. (y <- c(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, ) [=] 100% / 0s
```

#### Load test model, push to DataSHIELD, and calculate predictions

``` r
# Model predicts if species of iris is setosa or not.
iris$y = ifelse(iris$Species == "setosa", 1, 0)
mod = glm(y ~ Sepal.Length, data = iris, family = binomial())

# Push the model to the DataSHIELD servers using `dsPredictBase`:
pushObject(connections, mod)
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (mod <- decodeBinary("580a000000030004020000030500000000055554462d3800000313000000...  Finalizing assignment ds1 (mod <- decodeBinary("580a000000030004020000030500000000055554462d380...  Checking ds2 (mod <- decodeBinary("580a000000030004020000030500000000055554462d3800000313000000...  Finalizing assignment ds2 (mod <- decodeBinary("580a000000030004020000030500000000055554462d380...  Assigned expr. (mod <- decodeBinary("580a000000030004020000030500000000055554462d38000003130000...

# Calculate scores and save at the servers using `dsPredictBase`:
pfun =  "predict(mod, newdata = D, type = 'response')"
predictModel(connections, mod, "pred", "iris", predict_fun = pfun)
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (pred <- assignPredictModel("580a000000030004020000030500000000055554462d380000001...  Finalizing assignment ds1 (pred <- assignPredictModel("580a000000030004020000030500000000055554...  Checking ds2 (pred <- assignPredictModel("580a000000030004020000030500000000055554462d380000001...  Finalizing assignment ds2 (pred <- assignPredictModel("580a000000030004020000030500000000055554...  Assigned expr. (pred <- assignPredictModel("580a000000030004020000030500000000055554462d3800000...

datashield.symbols(connections)
#> $ds1
#> [1] "iris" "mod"  "pred" "y"   
#> 
#> $ds2
#> [1] "iris" "mod"  "pred" "y"
```

#### Calculate l2-sensitivity

``` r
# In order to securely calculate the ROC-GLM, we have to assess the
# l2-sensitivity to set the privacy parameters of differential
# privacy adequately:
l2s = dsL2Sens(connections, "iris", "pred")
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (internDim("iris")) [-----------------------------------------------------]   0% / 0s  Getting aggregate ds1 (internDim("iris")) [==============>-----------------------------]  33% / 0s  Checking ds2 (internDim("iris")) [=================>-----------------------------------]  33% / 0s  Getting aggregate ds2 (internDim("iris")) [============================>---------------]  67% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (xXcols <- decodeBinary("580a000000030004020000030500000000055554462d38000000fe", ...  Finalizing assignment ds1 (xXcols <- decodeBinary("580a000000030004020000030500000000055554462d...  Checking ds2 (xXcols <- decodeBinary("580a000000030004020000030500000000055554462d38000000fe", ...  Finalizing assignment ds2 (xXcols <- decodeBinary("580a000000030004020000030500000000055554462d...  Assigned expr. (xXcols <- decodeBinary("580a000000030004020000030500000000055554462d38000000fe"...
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (l2sens("iris", "pred", 100, "xXcols", diff, TRUE)) [---------------------]   0% / 0s  Getting aggregate ds1 (l2sens("iris", "pred", 100, "xXcols", diff, TRUE)) [===>--------]  33% / 0s  Checking ds2 (l2sens("iris", "pred", 100, "xXcols", diff, TRUE)) [======>--------------]  33% / 0s  Getting aggregate ds2 (l2sens("iris", "pred", 100, "xXcols", diff, TRUE)) [=======>----]  67% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
l2s
#> [1] 0.1281

# Due to the results presented in https://arxiv.org/abs/2203.10828, we set the privacy parameters to
# - epsilon = 0.2, delta = 0.1 if        l2s <= 0.01
# - epsilon = 0.3, delta = 0.4 if 0.01 < l2s <= 0.03
# - epsilon = 0.5, delta = 0.3 if 0.03 < l2s <= 0.05
# - epsilon = 0.5, delta = 0.5 if 0.05 < l2s <= 0.07
# - epsilon = 0.5, delta = 0.5 if 0.07 < l2s BUT results may be not good!
```

#### Calculate ROC-GLM

``` r
roc_glm = dsROCGLM(connections, truth_name = "y", pred_name = "pred",
  dat_name = "iris", seed_object = "y")
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (internDim("iris")) [-----------------------------------------------------]   0% / 0s  Getting aggregate ds1 (internDim("iris")) [==============>-----------------------------]  33% / 0s  Checking ds2 (internDim("iris")) [=================>-----------------------------------]  33% / 0s  Getting aggregate ds2 (internDim("iris")) [============================>---------------]  67% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (xXcols <- decodeBinary("580a000000030004020000030500000000055554462d38000000fe", ...  Finalizing assignment ds1 (xXcols <- decodeBinary("580a000000030004020000030500000000055554462d...  Checking ds2 (xXcols <- decodeBinary("580a000000030004020000030500000000055554462d38000000fe", ...  Finalizing assignment ds2 (xXcols <- decodeBinary("580a000000030004020000030500000000055554462d...  Assigned expr. (xXcols <- decodeBinary("580a000000030004020000030500000000055554462d38000000fe"...
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (l2sens("iris", "pred", 100, "xXcols", diff, TRUE)) [---------------------]   0% / 0s  Getting aggregate ds1 (l2sens("iris", "pred", 100, "xXcols", diff, TRUE)) [===>--------]  33% / 0s  Checking ds2 (l2sens("iris", "pred", 100, "xXcols", diff, TRUE)) [======>--------------]  33% / 0s  Getting aggregate ds2 (l2sens("iris", "pred", 100, "xXcols", diff, TRUE)) [=======>----]  67% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
#> 
#> [2022-07-05 16:22:18] L2 sensitivity is: 0.1281
#> 
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (l2s <- decodeBinary("580a000000030004020000030500000000055554462d380000000e000000...  Finalizing assignment ds1 (l2s <- decodeBinary("580a000000030004020000030500000000055554462d380...  Checking ds2 (l2s <- decodeBinary("580a000000030004020000030500000000055554462d380000000e000000...  Finalizing assignment ds2 (l2s <- decodeBinary("580a000000030004020000030500000000055554462d380...  Assigned expr. (l2s <- decodeBinary("580a000000030004020000030500000000055554462d380000000e0000...
#> Warning in dsROCGLM(connections, truth_name = "y", pred_name = "pred", dat_name
#> = "iris", : l2-sensitivity may be too high for good results! Epsilon = 0.5 and
#> delta = 0.5 is used which may lead to bad results.
#> 
#> [2022-07-05 16:22:18] Setting: epsilon = 0.5 and delta = 0.5
#> 
#> 
#> [2022-07-05 16:22:18] Initializing ROC-GLM
#> 
#> [2022-07-05 16:22:18] Host: Received scores of negative response
#> 
#> [2022-07-05 16:22:18] Receiving negative scores
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (getNegativeScores("y", "pred", 0.5, 0.5, "y", TRUE)) [-------------------]   0% / 0s  Getting aggregate ds1 (getNegativeScores("y", "pred", 0.5, 0.5, "y", TRUE)) [==>-------]  33% / 0s  Checking ds2 (getNegativeScores("y", "pred", 0.5, 0.5, "y", TRUE)) [=====>-------------]  33% / 0s  Getting aggregate ds2 (getNegativeScores("y", "pred", 0.5, 0.5, "y", TRUE)) [======>---]  67% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
#> [2022-07-05 16:22:19] Host: Pushing pooled scores
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (pooled_scores <- decodeBinary("580a000000030004020000030500000000055554462d380000...  Finalizing assignment ds1 (pooled_scores <- decodeBinary("580a000000030004020000030500000000055...  Checking ds2 (pooled_scores <- decodeBinary("580a000000030004020000030500000000055554462d380000...  Finalizing assignment ds2 (pooled_scores <- decodeBinary("580a000000030004020000030500000000055...  Assigned expr. (pooled_scores <- decodeBinary("580a000000030004020000030500000000055554462d3800...
#> [2022-07-05 16:22:19] Server: Calculating placement values and parts for ROC-GLM
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (roc_data <- rocGLMFrame("y", "pred", "pooled_scores")) [-----------------]   0% / 0s  Finalizing assignment ds1 (roc_data <- rocGLMFrame("y", "pred", "pooled_scores")) [>---]  33% / 0s  Checking ds2 (roc_data <- rocGLMFrame("y", "pred", "pooled_scores")) [=====>-----------]  33% / 0s  Finalizing assignment ds2 (roc_data <- rocGLMFrame("y", "pred", "pooled_scores")) [==>-]  67% / 0s  Assigned expr. (roc_data <- rocGLMFrame("y", "pred", "pooled_scores")) [===============] 100% / 0s
#> [2022-07-05 16:22:19] Server: Calculating probit regression to obtain ROC-GLM
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  33% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 0s
#> [2022-07-05 16:22:20] Deviance of iter1=137.2431
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  33% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 0s
#> [2022-07-05 16:22:20] Deviance of iter2=121.5994
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  33% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 0s
#> [2022-07-05 16:22:21] Deviance of iter3=147.7237
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  33% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 0s
#> [2022-07-05 16:22:21] Deviance of iter4=140.4008
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  33% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 0s
#> [2022-07-05 16:22:21] Deviance of iter5=129.2244
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  33% / 1s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 1s
#> [2022-07-05 16:22:22] Deviance of iter6=123.9979
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  33% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 0s
#> [2022-07-05 16:22:22] Deviance of iter7=123.1971
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  33% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 0s
#> [2022-07-05 16:22:23] Deviance of iter8=124.1615
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  33% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 0s
#> [2022-07-05 16:22:23] Deviance of iter9=124.5356
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  33% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 0s
#> [2022-07-05 16:22:24] Deviance of iter10=124.5503
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  33% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 0s
#> [2022-07-05 16:22:24] Deviance of iter11=124.5504
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [--]   0% / 0s  Getting aggregate ds1 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Checking ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [>-]  33% / 0s  Getting aggregate ds2 (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) []...  Aggregated (calculateDistrGLMParts(formula = y ~ x, data = "roc_data", w = "w", ) [====] 100% / 0s
#> [2022-07-05 16:22:24] Deviance of iter12=124.5504
#> [2022-07-05 16:22:24] Host: Finished calculating ROC-GLM
#> [2022-07-05 16:22:24] Host: Cleaning data on server
#> [2022-07-05 16:22:25] Host: Calculating AUC and CI
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (internLength("y")) [-----------------------------------------------------]   0% / 0s  Getting aggregate ds1 (internLength("y")) [==============>-----------------------------]  33% / 0s  Checking ds2 (internLength("y")) [=================>-----------------------------------]  33% / 1s  Getting aggregate ds2 (internLength("y")) [============================>---------------]  67% / 1s  Aggregated (...) [=====================================================================] 100% / 1s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (internSum("y")) [--------------------------------------------------------]   0% / 0s  Getting aggregate ds1 (internSum("y")) [===============>-------------------------------]  33% / 0s  Checking ds2 (internSum("y")) [==================>-------------------------------------]  33% / 0s  Getting aggregate ds2 (internSum("y")) [==============================>----------------]  67% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (internLength("y")) [-----------------------------------------------------]   0% / 0s  Getting aggregate ds1 (internLength("y")) [==============>-----------------------------]  33% / 0s  Checking ds2 (internLength("y")) [=================>-----------------------------------]  33% / 0s  Getting aggregate ds2 (internLength("y")) [============================>---------------]  67% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (getNegativeScoresVar("y", "pred", return_sum = TRUE)) [------------------]   0% / 0s  Getting aggregate ds1 (getNegativeScoresVar("y", "pred", return_sum = TRUE)) [==>------]  33% / 0s  Checking ds2 (getNegativeScoresVar("y", "pred", return_sum = TRUE)) [=====>------------]  33% / 0s  Getting aggregate ds2 (getNegativeScoresVar("y", "pred", return_sum = TRUE)) [=====>---]  67% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (getPositiveScoresVar("y", "pred", return_sum = TRUE)) [------------------]   0% / 0s  Getting aggregate ds1 (getPositiveScoresVar("y", "pred", return_sum = TRUE)) [==>------]  33% / 0s  Checking ds2 (getPositiveScoresVar("y", "pred", return_sum = TRUE)) [=====>------------]  33% / 0s  Getting aggregate ds2 (getPositiveScoresVar("y", "pred", return_sum = TRUE)) [=====>---]  67% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (getNegativeScoresVar("y", "pred", m = 1)) [------------------------------]   0% / 0s  Getting aggregate ds1 (getNegativeScoresVar("y", "pred", m = 1)) [======>--------------]  33% / 0s  Checking ds2 (getNegativeScoresVar("y", "pred", m = 1)) [=========>--------------------]  33% / 0s  Getting aggregate ds2 (getNegativeScoresVar("y", "pred", m = 1)) [=============>-------]  67% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (getPositiveScoresVar("y", "pred", m = 1)) [------------------------------]   0% / 0s  Getting aggregate ds1 (getPositiveScoresVar("y", "pred", m = 1)) [======>--------------]  33% / 0s  Checking ds2 (getPositiveScoresVar("y", "pred", m = 1)) [=========>--------------------]  33% / 0s  Getting aggregate ds2 (getPositiveScoresVar("y", "pred", m = 1)) [=============>-------]  67% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (getNegativeScores("y", "pred", 0.5, 0.5, "y", TRUE)) [-------------------]   0% / 0s  Getting aggregate ds1 (getNegativeScores("y", "pred", 0.5, 0.5, "y", TRUE)) [==>-------]  33% / 0s  Checking ds2 (getNegativeScores("y", "pred", 0.5, 0.5, "y", TRUE)) [=====>-------------]  33% / 0s  Getting aggregate ds2 (getNegativeScores("y", "pred", 0.5, 0.5, "y", TRUE)) [======>---]  67% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (getPositiveScores("y", "pred", 0.5, 0.5, "y", TRUE)) [-------------------]   0% / 0s  Getting aggregate ds1 (getPositiveScores("y", "pred", 0.5, 0.5, "y", TRUE)) [==>-------]  33% / 0s  Checking ds2 (getPositiveScores("y", "pred", 0.5, 0.5, "y", TRUE)) [=====>-------------]  33% / 0s  Getting aggregate ds2 (getPositiveScores("y", "pred", 0.5, 0.5, "y", TRUE)) [======>---]  67% / 0s  Aggregated (...) [=====================================================================] 100% / 0s
#> [2022-07-05 16:22:29] Finished!
roc_glm
#> 
#> ROC-GLM after Pepe:
#> 
#>  Binormal form: pnorm(2.51 + 1.55*qnorm(t))
#> 
#>  AUC and 0.95 CI: [0.86----0.91----0.95]

plot(roc_glm)
```

![](Readme_files/unnamed-chunk-9-1.png)<!-- -->

#### Assess calibration

``` r
dsBrierScore(connections, "y", "pred")
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (brierScore("y", "pred")) [-----------------------------------------------]   0% / 0s  Getting aggregate ds1 (brierScore("y", "pred")) [============>-------------------------]  33% / 0s  Checking ds2 (brierScore("y", "pred")) [===============>-------------------------------]  33% / 0s  Getting aggregate ds2 (brierScore("y", "pred")) [========================>-------------]  67% / 1s  Aggregated (brierScore("y", "pred")) [=================================================] 100% / 1s
#> [1] 0.07432

### Calculate and plot calibration curve:
cc = dsCalibrationCurve(connections, "y", "pred", 10, 3)
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (calibrationCurve("y", "pred", 10, 3)) [----------------------------------]   0% / 0s  Getting aggregate ds1 (calibrationCurve("y", "pred", 10, 3)) [=======>-----------------]  33% / 0s  Checking ds2 (calibrationCurve("y", "pred", 10, 3)) [==========>-----------------------]  33% / 0s  Getting aggregate ds2 (calibrationCurve("y", "pred", 10, 3)) [================>--------]  67% / 0s  Aggregated (calibrationCurve("y", "pred", 10, 3)) [====================================] 100% / 0s
cc
#> 
#> Calibration curve:
#> 
#>  Number of shared values:
#>            (0,0.1] (0.1,0.2] (0.2,0.3] (0.3,0.4] (0.4,0.5] (0.5,0.6] (0.6,0.7]
#> n              140        30        12        14        12         2         0
#> not_shared       0         0         0         0         0         2       NaN
#>            (0.7,0.8] (0.8,0.9] (0.9,1]
#> n                  8        38      44
#> not_shared         8         0       0
#> 
#> Values of the calibration curve:
#>           (0,0.1] (0.1,0.2] (0.2,0.3] (0.3,0.4] (0.4,0.5] (0.5,0.6] (0.6,0.7]
#> truth     0.00000    0.2000    0.0000    0.2857    0.8333         0       NaN
#> predicted 0.01075    0.1312    0.2395    0.3457    0.4700         0       NaN
#>           (0.7,0.8] (0.8,0.9] (0.9,1]
#> truth             0    0.8421  0.9091
#> predicted         0    0.8432  0.9604
#> 
#> 
#> Missing values are indicated by the privacy level of 5.

plot(cc)
#> Warning: Removed 6 rows containing missing values (geom_point).
#> Warning: Removed 6 row(s) containing missing values (geom_path).
#> Warning: Removed 1 rows containing missing values (geom_point).
#> Warning: Removed 1 row(s) containing missing values (geom_path).
```

![](Readme_files/unnamed-chunk-10-1.png)<!-- -->

#### Further performance metrics

``` r
dsConfusion(connections, "y", "pred")
#>    [-------------------------------------------------------------------------------------]   0% / 0s  Checking ds1 (confusion("y", "pred", 0.5)) [-------------------------------------------]   0% / 0s  Getting aggregate ds1 (confusion("y", "pred", 0.5)) [==========>-----------------------]  33% / 0s  Checking ds2 (confusion("y", "pred", 0.5)) [=============>-----------------------------]  33% / 0s  Getting aggregate ds2 (confusion("y", "pred", 0.5)) [======================>-----------]  67% / 0s  Aggregated (confusion("y", "pred", 0.5)) [=============================================] 100% / 0s
#> $confusion
#>      predicted
#> truth   0   1
#>     0 188  12
#>     1  20  80
#> 
#> $measures
#>      npos      nneg        f1       acc       npv       tpr       tnr       fnr 
#> 208.00000 100.00000   0.90385   0.89333   0.80000   0.90385   0.80000   0.09615 
#>       fpr 
#>   0.20000
```

## Deploy information:

**Build by daniel (Linux) on 2022-07-05 16:22:31.**

This readme is built automatically after each push to the repository.
Hence, it also is a test if the functionality of the package works also
on the DataSHIELD servers. We also test these functionality in
`tests/testthat/test_on_active_server.R`. The system information of the
local and remote servers are as followed:

  - Local machine:
      - `R` version: R version 4.2.0 (2022-04-22)
      - Version of DataSHELD client packages:

| Package      | Version |
| :----------- | :------ |
| DSI          | 1.4.0   |
| DSOpal       | 1.3.1   |
| dsBaseClient | 6.2.0   |
| dsBinVal     | 1.0.1   |

  - Remote DataSHIELD machines:
      - `R` version of ds1: R version 4.2.0 (2022-04-22)
      - `R` version of ds2: R version 4.2.0 (2022-04-22)
      - Version of server packages:

| Package   | ds1: Version | ds2: Version |
| :-------- | :----------- | :----------- |
| dsBase    | 6.2.0        | 6.2.0        |
| resourcer | 1.2.0        | 1.2.0        |
| dsBinVal  | 1.0.1        | 1.0.1        |
