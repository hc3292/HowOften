HowOften
===============

This analysis calculates the observed risk in a population for all drugs and conditions in a dataset. This analysis only works with CDM v5.


Getting Started
===============

1. Make sure that you have Java installed. If you don't have Java already intalled on your computed (on most computers it already is installed), go to [java.com](http://java.com) to get the latest version.  (If you have trouble building with rJava below, be sure on Windows that your Path variable includes the path to jvm.dll (Windows Button --> type "path" --> Edit Environmental Variables --> Edit PATH variable, add to end ;C:/Program Files/Java/jre/bin/server) or wherever it is on your system.)

2. in R, use the following commands to install Achilles (if you have prior package installations of aony of these packages, you may need to first unistall them using the command remove.packages()).

  ```r
  install.packages("devtools")
  library(devtools)
  install_github("ohdsi/SqlRender")
  install_github("ohdsi/DatabaseConnector")
  install_github("cukarthik/HowOften")
  #source('HowOften.R') #you should be running R from the directory where this script is located or qualify the path
  ```
  
4. To run the HowOften analysis, use the following commands in R: 

  ```r
  library(ohdsi/SqlRender)
  library(ohdsi/DatabaseConnector)
  connectionDetails <- createConnectionDetails(dbms="sql server", server="DB Server Name", user="secret",
                              password='secret', schema="ohdsi", port="1433")
  howoftenResults <- howoften_analysis(connectionDetails, cdmDatabaseSchema="ohdsi.dbo", 
                              resultsDatabaseSchema="ohdsi.results",  minPersonsExposed = "10")
  ```
  "ohdsi" cdmDatabaseSchema parmater and "results" resultsDatabaseSchema parameter the names of the schemas holding the CDM data, targeted for result writing. 


