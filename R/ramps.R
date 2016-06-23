#' Ramp of an area
#'
#' This function computes the ramp of the consumption and the balance of areas
#' and/or districts and add them to the data.
#'
#' @param x
#'   Object of class \code{antaresData} containing data for areas and/or
#'   districts. it must contain the column \code{BALANCE} and either the column
#'   "netLoad" or the columns needed to compute the net load.
#' @inheritParams surplus
#'
#' @return
#' \code{addRamps} returns a data.table or a list of data.tables with the
#' following columns:
#' \item{netLoadRamp}{Ramp of the net load of an area. If \code{timeStep} is not hourly, then these columns contain the average value for the given time step.}
#' \item{balanceRamp}{Ramp of the balance of an area. If \code{timeStep} is not hourly, then these columns contain the average value for the given time step.}
#' \item{areaRamp}{Sum of the two previous columns. If \code{timeStep} is not hourly, then these columns contain the average value for the given time step.}
#' \item{minNetLoadRamp}{Minimum ramp of the net load of an area.}
#' \item{minBalanceRamp}{Minimum ramp of the balance of an area.}
#' \item{minAreaRamp}{Minimum ramp sum of the sum of balance and net load.}
#' \item{maxNetLoadRamp}{Maximum ramp of the net load of an area.}
#' \item{maxBalanceRamp}{Maximum ramp of the balance of an area.}
#' \item{maxAreaRamp}{Maximum ramp of the sum of balance and net load.}
#'
#' For convenience the function invisibly returns the modified input.
#'
#'
#' @examples
#' \dontrun{
#'
#'   mydata <- readAntares(areas = "all", mustRun = TRUE, timeStep = "monthly")
#'
#'   addRamps(mydata)
#' }
#'
#' @export
#'
netLoadRamp <- function(x, timeStep = "hourly", synthesis = FALSE, ignoreMustRun = FALSE) {
  .checkAttrs(x, "hourly", "FALSE")
  opts <- simOptions(x)

  if (is(x, "antaresDataList")) {
    if (is.null(x$areas) & is.null(x$districts)) stop("'x' does not contain area or district data")

    res <- list()

    if (!is.null(x$areas)) res$areas <- netLoadRamp(x$areas, timeStep, synthesis, ignoreMustRun)
    if (!is.null(x$districts)) res$districts <- netLoadRamp(x$districts, timeStep, synthesis, ignoreMustRun)

    if (length(res) == 0) stop("'x' needs to contain area and/or district data.")
    if (length(res) == 1) return(res[[1]])

    class(res) <- append(c("antaresDataList", "antaresData"), class(res))
    attr(res, "timeStep") <- timeStep
    attr(res, "synthesis") <- synthesis
    attr(res, "opts") <- simOptions(x)

    return(res)

  }

  if(! attr(x, "type") %in% c("areas", "districts")) stop("'x' does not contain area or district data")

  if (is.null(x$BALANCE)) stop("Column 'BALANCE' is needed but missing.")
  if (is.null(x$netLoad)) addNetLoad(x, ignoreMustRun)

  x <- x[, c(.idCols(x), "BALANCE", "netLoad"), with = FALSE]

  idVars <- setdiff(.idCols(x), "timeId")

  setorderv(x, c(idVars, "timeId"))
  x[, `:=`(netLoadRamp = netLoad - shift(netLoad, fill = 0),
           balanceRamp = BALANCE - shift(BALANCE, fill = 0))]

  x[timeId == min(timeId), c("netLoadRamp", "balanceRamp") := 0]
  x[, areaRamp := netLoadRamp + balanceRamp]

  x <- x[, c(idVars, "timeId", "netLoadRamp", "balanceRamp", "areaRamp"), with = FALSE]

  x <- .setAttrs(x, "netLoadRamp", opts)

  if (timeStep != "hourly" | synthesis) {
    x[, `:=`(
      minNetLoadRamp = netLoadRamp,
      minBalanceRamp = balanceRamp,
      minAreaRamp = areaRamp,
      maxNetLoadRamp = netLoadRamp,
      maxBalanceRamp = balanceRamp,
      maxAreaRamp = areaRamp
    )]

    x <- changeTimeStep(x, timeStep,
                        fun = c("mean", "mean", "mean",
                                "min", "min", "min",
                                "max", "max", "max"))

    if (synthesis) x <- .aggregateMcYears(x, c(mean, mean, mean,
                                               min, min, min,
                                               max, max, max))
  }

  x
}