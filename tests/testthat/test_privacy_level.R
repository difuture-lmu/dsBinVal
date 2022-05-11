context("Privacy level getter")

test_that("test if privacy level can be obtained", {
  expect_equal(dsBinVal:::.getPrivacyLevel(), 5)
})
