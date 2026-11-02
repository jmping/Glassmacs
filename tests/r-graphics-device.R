#!/usr/bin/env Rscript
# Real, headless R graphics smoke test.  This checks R's device semantics,
# not Cocoa/Quartz window visibility or Glassmacs GUI focus.
options(warn = 2)
stopifnot(capabilities("png"))
path <- tempfile("glassmacs-r-graphics-", fileext = ".png")
on.exit <- NULL
tryCatch({
  grDevices::png(filename = path, width = 480L, height = 320L)
  stopifnot(grDevices::dev.cur() > 1L)
  graphics::plot(cars)
  stopifnot(!is.null(grDevices::dev.list()))
  grDevices::dev.off()
  stopifnot(identical(unname(grDevices::dev.cur()), 1L))
  stopifnot(file.exists(path), file.info(path)$size > 100L)
  con <- file(path, open = "rb")
  signature <- readBin(con, "raw", n = 8L)
  close(con)
  stopifnot(identical(as.integer(signature),
                      c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L)))
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    grDevices::png(filename = path, width = 480L, height = 320L)
    print(ggplot2::ggplot(cars, ggplot2::aes(speed, dist)) +
            ggplot2::geom_point())
    grDevices::dev.off()
    stopifnot(file.exists(path), file.info(path)$size > 100L)
  }
  cat("R graphics device test passed (PNG, base plot",
      if (requireNamespace("ggplot2", quietly = TRUE)) ", ggplot2" else "",
      "); native Quartz GUI not tested.\n", sep = "")
}, finally = {
  if (grDevices::dev.cur() > 1L) grDevices::graphics.off()
  unlink(path)
})
