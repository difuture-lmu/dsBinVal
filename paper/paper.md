---
title: 'dsBinVal: Conducting distributed ROC analysis using DataSHIELD'
tags:
  - DataSHIELD
  - distributed computing
  - distributed analysis
  - privacy-preserving
  - diagnostic tests
  - prognostic model
  - model validation
  - ROC-GLM
  - discrimination
  - calibration
  - Brier score
authors:
  - name: Daniel Schalk
    orcid: 0000-0003-0950-1947
    affiliation: "1, 3"
  - name: Verena Sophia Hoffmann
    affiliation: "2, 3"
  - name: Bernd Bischl
    affiliation: 1
  - name: Ulrich Mansmann
    affiliation: "2, 3"
affiliations:
 - name: Department of Statistics, LMU Munich, Munich, Germany
   index: 1
 - name: Institute for Medical Information Processing, Biometry and Epidemiology, LMU Munich, Munich, Germany
   index: 2
 - name: DIFUTURE (DataIntegration for Future Medicine, www.difuture.de), LMU Munich, Munich, Germany
   index: 3
date: 23 March 2022
bibliography: paper.bib
---

# Summary

Our `R` [@rcore] package `dsBinVal` implements the methodology explained by @schalk2022rocglm. It extends the ROC-GLM [@pepe2000interpretation] to distributed data by using techniques of differential privacy [@dwork2006calibrating] and the idea of sharing highly aggregated values only. The package also exports functionality to calculate distributed calibration curves and assess the calibration. Using the package allows us to evaluate a prognostic model based on a binary outcome using the DataSHIELD [@gaye2014datashield] framework. Therefore, the main functionality makes it able to 1) compute the ROC curve using the ROC-GLM from which 2) the AUC and confidence intervals are derived to conduct hypothesis testing according to @delong1988. Furthermore, 3) the calibration can be assessed distributively via calibration curves and the Brier score. Visualizing the approximated ROC curve, the AUC with confidence intervals, and the calibration curves is also supported based on [`ggplot2`](https://ggplot2.tidyverse.org/reference/ggplot.html). Examples can be found in the [README](https://github.com/difuture-lmu/dsBinVal) file of the repository.

# Statement of need

Privacy protection of patient data plays a major role for a variety of tasks in medical research. Uncontrolled release of health information may cause personal disadvantages for individuals. The individual patient needs to be protected against personal details becoming visible to people not authorized to know them.

In statistics or machine learning, one of these tasks is to gain insights by building statistical or prognostic models. Prognosis on the development of severe health conditions or covariates coding critical health information like genetic susceptibility need to be handled with care. Furthermore, using confidential data comes with administrative burdens and mostly requires a consent around data usage. Additionally, the data can be distributed over multiple sites (e.g. hospitals) which makes their access even more challenging. Modern approaches in distributed analysis allow work on distributed confidential data by providing frameworks that allow retrieval of information without sharing sensitive information. Since no sensitive information is shared through the use of privacy-preserving and distributed algorithms, their use helps to meet administrative, ethical, and legal requirements in medical research as users do not have access to personal data.

One of these frameworks for privacy protected analysis is DataSHIELD [@gaye2014datashield]. It allows the analysis of data in a non-disclosive setting. The framework already provides techniques for descriptive statistics, basic summary statistics, and basic statistical modeling. Within a multiple sclerosis use-case to enhance patient medication in the DIFUTURE consortium of the German Medical Informatics Initiative [@prasser2018difuture], a prognostic model was developed on individual patient data. One goal of the multiple sclerosis use-case is to validate that prognostic model using ROC and calibration analysis on patient data distributed across five hospitals using DataSHIELD.

In this package we close the gap between distributed model building and the validation of binary outcomes also on the distributed data. Therefore, our package seamlessly integrates into the DataSHIELD framework, which does not yet provide distributed ROC analysis and calibration assessment.

# Functionality

The integration of the package into the DataSHIELD framework hence extends its functionality and allows users to assess the discrimination and calibration of a binary classification model without harming the privacy of individuals. Based on privacy-preserving distributed algorithms [@schalk2022rocglm], the assessing the discrimination is done by the `dsROCGLM()` function that calculates a ROC curve based on the ROC-GLM as well as an AUC with CI. The calibration is estimated distributively using the functions `dsBrierScore()` and `dsCalibrationCurve()`. Additional helper functions, namely `dsConfusion` or `dsL2Sens`, can be used to calculate several measures, e.g. sensitivity, specificity, accuracy, or the F1 score, from the confusion matrix or the L2-sensitivity. Note that measures from the confusion matrix may be disclosive for specific thresholds and are therefore checked and protected by DataSHIELDs privacy mechanisms. During the call to `dsROCGLM()`, parts of the data set are communicated twice, first, to calculate the ROC-GLM based on prediction scores, and second, to calculate the CI of the AUC. In both steps, the information is protected by differential privacy to prevent individuals from re-identification. The amount of noise generated for differential privacy is carefully chosen based on a simulation study that takes the variation of the predicted values into account. We refer to the [README](https://github.com/difuture-lmu/dsBinVal) file of the repository for a demonstration and usage of the functionality.

__Technical details:__ To ensure the functioning of our package on DataSHIELD, it is constantly unit tested on an active DataSHIELD [test instance](opal-demo.obiba.org). The reference, username, and password are available at the [OPAL documentation](opaldoc.obiba.org/en/latest/resources.html) in the "Types" section. Parts of the tests also cover checks against privacy breaches by attempting to call functions with data sets that do not pass the safety mechanisms of DataSHIELD. Hence, individual functions attempt to prevent accidental disclosures when data is not sufficient to ensure privacy.

__State of field:__ To the best of our knowledge, there is no distributed ROC-GLM implementation available in `R`. Current state-of-the-art techniques require to share sensitive information from the sites and using existing implementation such as `pROC` [@pROC] for the ROC curve or standard software for the GLM to calculate the ROC-GLM (as stated by @pepe2000interpretation).

# Acknowledgements

This work was supported by the German Federal Ministry of Education and Research (BMBF)
under Grant No. 01IS18036A and Federal Ministry for Research and Technology (BMFT) under
Grant No. 01ZZ1804C (DIFUTURE, MII). The authors of this work take full responsibilities
for its content.

# References

