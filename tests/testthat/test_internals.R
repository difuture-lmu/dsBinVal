context("Check if predict works locally")

test_that("Predict works locally", {

  expect_silent(dsBinVal:::.rmGlobalEnv())

  expect_error(internN("bla"))
  expect_error(internDim("bla"))
  expect_error(internMean("bla"))
  expect_error(internLength("bla"))

  x <<- rnorm(10)

  expect_equal(internN("iris"), nrow(iris))
  expect_equal(internDim("iris"), dim(iris))
  expect_equal(internMean("x"), mean(x))
  expect_equal(internLength("x"), length(x))

  iris2 = iris[1:4]
  x <<- rnorm(4)

  expect_error(internN("iris2"))
  expect_error(internDim("iris2"))
  expect_error(internMean("x"))
})