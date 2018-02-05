#' Todo: add title
#'
#' @description
#' Todo: add description
#'
#' @details
#' Todo: add details
#'
#' @param connectionDetails		An R object of type \code{ConnectionDetails} created using the function \code{createConnectionDetails} in the \code{DatabaseConnector} package.
#' @param oracleTempSchema		A schema where temp tables can be created in Oracle.
#' @param cdmDatabaseSchema 		
#' @param resultsDatabaseSchema 		
#' @param minPersonsExposed 		
#'
#' @export
howoften_analysis <- function(connectionDetails,
                         oracleTempSchema = NULL,
                         cdmDatabaseSchema = "ohdsi.dbo",
                         resultsDatabaseSchema = "ohdsi.dbo",
                         minPersonsExposed = "10") {
  cdmDatabase <- strsplit(cdmDatabaseSchema ,"\\.")[[1]][1]
  resultsDatabase <- strsplit(resultsDatabaseSchema ,"\\.")[[1]][1]
  renderedSql <- SqlRender::loadRenderTranslateSql("howoften_analysis.sql",
              packageName = "HowOften",
              dbms = connectionDetails$dbms,
              oracleTempSchema = oracleTempSchema,
              cdm_database = cdmDatabase,
              cdm_database_schema = cdmDatabaseSchema,
              results_database = resultsDatabase,
              results_database_schema = resultsDatabaseSchema,
              min_persons_exposed = minPersonsExposed)
  conn <- DatabaseConnector::connect(connectionDetails)

  writeLines("Executing multiple queries. This could take a while")
  DatabaseConnector::executeSql(conn,renderedSql)
  writeLines(paste("Done. Analysis results can now be found in ",resultsDatabaseSchema))

  dummy <- RJDBC::dbDisconnect(conn)
}
