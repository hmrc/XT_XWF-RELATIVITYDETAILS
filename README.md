### XT_XWF-RelativityDetails
  Most recently tested on: v19.7 (July 2021)

###  *** Requirements ***
  This X-Tension is designed for use only with X-Ways Forensics, x64 edition (for now).
  This X-Tension is designed for use only with v18.5 of X-Ways Forensics or later

###  *** Functionality Overview ***
  This X-Tension links Relativity Document ID's, along with Nuix GUIDs to X-Ways Items
  by virtue of their MD5 hashes. All linked details (Document ID's, Nuix GUIDs and Duplicate
  Custodians) are written to the Comments of each individual file.

  ** CSV Requirements **
  X-Tension takes a CSV input (No column headers), where:
  MD5 Hash is the first column
  Relativity DocumentID is the second column
  Nuix GUID is the third column
  Duplicate Custodians is the Fourth Column

  ** Case Processing Requirements **
  Case must have MD5 hash value computed
  X-Tension to be executed by right clicking files and running the X-Tension DLL itself

### *** License ***
  This code is open source software licensed under the [Apache 2.0 License]("http://www.apache.org/licenses/LICENSE-2.0.html")
  and The Open Government Licence (OGL) v3.0.
  (http://www.nationalarchives.gov.uk/doc/open-government-licence and
  http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).
