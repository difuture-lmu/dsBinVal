context("Check internal helper")

test_that("internals are returning the same as the R base pendants", {

  expect_silent(dsBinVal:::.rmGlobalEnv())

  expect_error(internN("bla"))
  expect_error(internDim("bla"))
  expect_error(internSum("bla"))
  expect_error(internLength("bla"))

  x <<- rnorm(10)

  expect_equal(internN("iris"), nrow(iris))
  expect_equal(internDim("iris"), dim(iris))
  expect_equal(internSum("x"), sum(x))
  expect_equal(internLength("x"), length(x))

  iris2 = iris[1:4]
  x <<- rnorm(4)

  expect_error(internN("iris2"))
  expect_error(internDim("iris2"))
  expect_error(internSum("x"))
})
