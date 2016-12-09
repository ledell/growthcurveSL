#' @useDynLib growthcurveSL
#' @import R6
#' @importFrom Rcpp sourceCpp
#' @importFrom graphics axis barplot hist par text  legend plot
#' @importFrom methods is
#' @importFrom stats approx binomial gaussian coef glm.control glm.fit plogis predict qlogis qnorm quantile rnorm terms var predict glm.control
#' @importFrom utils data head str
#' @importFrom stats as.formula glm na.exclude rbinom terms.formula
NULL

## -----------------------------------------------------------------------------
## Class Membership Tests
## -----------------------------------------------------------------------------
is.DataStorageClass <- function(DataStorageClass) "DataStorageClass"%in%class(DataStorageClass)
is.PredictionModel <- function(PredictionModel) "PredictionModel"%in%class(PredictionModel)
is.PredictionStack <- function(PredictionStack) "PredictionStack"%in%class(PredictionStack)

# ---------------------------------------------------------------------------------------
#' Import data, define nodes (columns), define dummies for factor columns and define input data R6 object
#'
#' @param data Input dataset, can be a \code{data.frame} or a \code{data.table}.
#' @param ID A character string name of the column that contains the unique subject identifiers.
#' @param t_name A character string name of the column with integer-valued measurement time-points (in days, weeks, months, etc).
#' @param covars Names of predictors (covariates) in the data.
#' @param OUTCOME Character name of the column containing outcomes.
#' @param verbose Set to \code{TRUE} to print messages on status and information to the console. Turn this on by default using \code{options(growthcurveSL.verbose=TRUE)}.
#' @return An R6 object that contains the input data. This can be passed as an argument to \code{get_fit} function.
# @example tests/examples/1_growthcurveSL_example.R
#' @export
importData <- function(data, ID = "Subject_ID", t_name = "time_period", covars, OUTCOME = "Y", verbose = getOption("growthcurveSL.verbose")) {
  gvars$verbose <- verbose
  # if (verbose) {
  #   current.options <- capture.output(str(gvars$opts))
  #   print("Using the following growthcurveSL options/settings: ")
  #   cat('\n')
  #   cat(paste0(current.options, collapse = '\n'), '\n')
  # }

  if (missing(covars)) { # define time-varing covars (L) as everything else in data besides these vars
    covars <- setdiff(colnames(data), c(ID, OUTCOME))
  }

  nodes <- list(Lnodes = covars, Ynode = OUTCOME, IDnode = ID, tnode = t_name)
  OData <- DataStorageClass$new(Odata = data, nodes = nodes)

  ## --------------------------------------------------------------------------------------------------------
  ## Convert all character covars into factors?
  ## --------------------------------------------------------------------------------------------------------
  # ....?

  ## --------------------------------------------------------------------------------------------------------
  ## Create dummies for each factor
  ## --------------------------------------------------------------------------------------------------------
  # factor.Ls <- unlist(lapply(OData$dat.sVar, is.factor))
  # factor.Ls <- factor.Ls[covars]
  # factor.Ls <- names(factor.Ls)[factor.Ls]

  # new.factor.names <- vector(mode="list", length=length(factor.Ls))
  # names(new.factor.names) <- factor.Ls
  # if (length(factor.Ls)>0 && verbose)
  #   message("...converting the following factor(s) to binary dummies (and droping the first factor levels): " %+% paste0(factor.Ls, collapse=","))
  # for (factor.varnm in factor.Ls) {
  #   factor.levs <- levels(OData$dat.sVar[,factor.varnm, with=FALSE][[1]])
  #   factor.levs <- factor.levs[-1] # remove the first level (reference class)
  #   # use levels to define cat indicators:
  #   OData$dat.sVar[,(factor.varnm %+% "_" %+% factor.levs) := lapply(factor.levs, function(x) levels(get(factor.varnm))[get(factor.varnm)] %in% x)]
  #   # to remove the origional factor var: # OData$dat.sVar[,(factor.varnm):=NULL]
  #   new.factor.names[[factor.varnm]] <- factor.varnm %+% "_" %+% factor.levs
  # }
  # OData$new.factor.names <- new.factor.names

  ## --------------------------------------------------------------------------------------------------------
  ## Convert all logical vars to binary integers
  ## --------------------------------------------------------------------------------------------------------
  # logical.Ls <- unlist(lapply(OData$dat.sVar, is.logical))
  # logical.Ls <- names(logical.Ls)[logical.Ls]
  # if (length(logical.Ls)>0 && verbose) message("...converting logical columns to binary integers (0 = FALSE)...")
  # for (logical.varnm in logical.Ls) {
  #   OData$dat.sVar[,(logical.varnm) := as.integer(get(logical.varnm))]
  # }

  # for (Nnode in nodes$Nnodes) CheckVarNameExists(OData$dat.sVar, Nnode)
  for (Ynode in nodes$Ynode)  CheckVarNameExists(OData$dat.sVar, Ynode)
  for (Lnode in nodes$Lnodes) CheckVarNameExists(OData$dat.sVar, Lnode)
  return(OData)
}

## -----------------------------------------------------------------------------
## General utilities / Global Vars
## -----------------------------------------------------------------------------
`%+%` <- function(a, b) paste0(a, b)
is.integerish <- function (x) is.integer(x) || (is.numeric(x) && all(x == as.integer(x)))

# Return the left hand side variable of formula f as a character
LhsVars <- function(f) {
  f <- as.formula(f)
  return(as.character(f[[2]]))
}
# Return the right hand side variables of formula f as a character vector
RhsVars <- function(f) {
  f <- as.formula(f)
  return(all.vars(f[[3]]))
}

checkpkgs <- function(pkgs) {
  for (pkg in pkgs) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(pkg %+% " package needed for this function to work. Please install it.", call. = FALSE)
    }
  }
}

#if warning is in ignoreWarningList, ignore it; otherwise post it as usual
SuppressGivenWarnings <- function(expr, warningsToIgnore) {
  h <- function (w) {
    if (w$message %in% warningsToIgnore) invokeRestart( "muffleWarning" )
  }
  withCallingHandlers(expr, warning = h )
}

GetWarningsToSuppress <- function(update.step=FALSE) {
  warnings.to.suppress <- c("glm.fit: fitted probabilities numerically 0 or 1 occurred",
                            "prediction from a rank-deficient fit may be misleading",
                            "non-integer #successes in a binomial glm!",
                            "the matrix is either rank-deficient or indefinite")
  if (update.step) {
    warnings.to.suppress <- c(warnings.to.suppress, "glm.fit: algorithm did not converge")
  }
  return(warnings.to.suppress)
}

# returns NULL if no factors exist, otherwise return the name of the factor variable(s)
CheckExistFactors <- function(data) {
  testvec <- unlist(lapply(data, is.factor))
  if (any(testvec)) {
    return(names(data)[which(testvec)])
  } else {
    return(NULL)
  }
}

# throw exception if 1) varname doesn't exist; 2) more than one varname is matched
CheckVarNameExists <- function(data, varname) {
  idvar <- names(data) %in% varname
  if (sum(idvar) < 1) stop("variable name " %+% varname %+% " not found in data input")
  if (sum(idvar) > 1) stop("more than one column in the input data has been matched to name "
                            %+% varname %+% ". Consider renaming some of the columns: " %+%
                            paste0(names(data)[idvar], collapse=","))
  return(invisible(NULL))
}

# ---------------------------------------------------------------------------------------
#' Plot the top K smallest MSEs for a given model ensemble object.
#'
#' @param PredictionModel Must be an R6 object of class \code{PredictionModel} (returned by \code{get_fit} function)
#' or an object of class \code{PredictionStack} (returned by \code{make_PredictionStack} function).
#' Must also contain validation /test set predictions and corresponding MSEs.
#' @param K How many top (smallest) MSEs should be plotted? Default is 5.
#' @export
plotMSEs <- function(PredictionModel, K = 1, interactive = FALSE) {
  # require("ggplot2")
  require("ggiraph")
  assert_that(is.PredictionModel(PredictionModel) || is.PredictionStack(PredictionModel))
  assert_that(is.integerish(K))

  datMSE <- PredictionModel$get_best_MSE_table(K = K)
  # datMSE$model <- factor(datMSE$model, levels = datMSE$model[order(datMSE$MSE.CV)]) # order when not flipping coords
  datMSE$model <- factor(datMSE$model, levels = datMSE$model[order(datMSE$MSE.CV, decreasing = TRUE)]) # order when flipping coords

  # datMSE$tooltip <- "MSE.CV = " %+% round(datMSE$MSE.CV, 2) %+% "; 95% CI: [" %+% round(datMSE$CIlow,2) %+% "-" %+% round(datMSE$CIhi,2)  %+%"]"
  # datMSE$tooltip <- "MSE.CV = " %+% format(datMSE$MSE.CV, digits = 3, nsmall=2) %+% "; 95% CI: [" %+% format(datMSE$CIlow, digits = 3, nsmall=2) %+% "-" %+% format(datMSE$CIhi, digits = 3, nsmall=2)  %+% "]"
  datMSE$tooltip <- "MSE.CV = " %+% format(datMSE$MSE.CV, digits = 3, nsmall=2) %+% " [" %+% format(datMSE$CIlow, digits = 3, nsmall=2) %+% "-" %+% format(datMSE$CIhi, digits = 3, nsmall=2)  %+% "]"

  datMSE$onclick <- "window.location.hash = \"#jump" %+% 1:nrow(datMSE) %+% "\""
  # open a new browser window:
  # datMSE$onclick <- sprintf("window.open(\"%s%s\")", "http://en.wikipedia.org/wiki/", "Florida")  # pop-up box:
  # datMSE$onclick = paste0("alert(\"",datMSE$model.id, "\")")

  p <- ggplot(datMSE, aes(x = model, y = MSE.CV, ymin=CIlow, ymax=CIhi)) # will use model name (algorithm)
  if (interactive) {
    p <- p + geom_point_interactive(aes(color = algorithm, tooltip = tooltip, data_id = model.id, onclick = onclick), size = 2, position = position_dodge(0.01)) # alpha = 0.8
    # p <- p + geom_point_interactive(aes(color = algorithm, tooltip = model.id, data_id = model.id, onclick = onclick), size = 2, position = position_dodge(0.01)) # alpha = 0.8
  } else {
    p <- p + geom_point(aes(color = algorithm), size = 2, position = position_dodge(0.01)) # alpha = 0.8
  }
  p <- p + geom_errorbar(aes(color = algorithm), width = 0.2, position = position_dodge(0.01))
  p <- p + theme_bw() + coord_flip()

  if (interactive){
    ggiraph(code = print(p), width = .6,
            tooltip_extra_css = "padding:2px;background:rgba(70,70,70,0.1);color:black;border-radius:2px 2px 2px 2px;",
            hover_css = "fill:#1279BF;stroke:#1279BF;cursor:pointer;"
            )
    # to active zoom on a plot:
    # zoom_max = 2
  } else {
    print(p)
  }
  # return(invisible(NULL))
  # ggiraph(code = {print(p)})
  # , tooltip_offx = 20, tooltip_offy = -10
  # p <- p + facet_grid(N ~ ., labeller = label_both) + xlab('Scenario')
  # # p <- p + facet_grid(. ~ N, labeller = label_both) + xlab('Scenario')
  # p <- p + ylab('Mean estimate \\& 95\\% CI length')
  # p <- p + theme(axis.title.y = element_blank(),
  #                axis.title.x = element_text(size = 8),
  #                plot.margin = unit(c(1, 0, 1, 1), "lines"),
  #                legend.position="top")
}