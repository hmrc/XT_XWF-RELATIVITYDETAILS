library XT_XWF_RelativityDetails;
{
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

### *** License ***
  This code is open source software licensed under the [Apache 2.0 License]("http://www.apache.org/licenses/LICENSE-2.0.html")
  and The Open Government Licence (OGL) v3.0.
  (http://www.nationalarchives.gov.uk/doc/open-government-licence and
  http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).
}

{$mode objfpc}{$H+}

uses
  Classes, XT_API, Windows, Sysutils, CSVDocument,StrUtils;

//gloabl variables in here
var
  // Needed for XT_Init
  MainWnd              : THandle;
  csvStringList        : TStringList;     // Global variable containing the StringList
  commentCount         : Int32;           // Global variable to count Comments
  csvStringListLength  : int32;           // Global variabnle containing the size of the imported CSV
  csvPathSet           : Boolean = Default(boolean);
  csvPath              : array[0..255] of WideChar;    //path to the CSV
  startTime            : TDateTime;       // Global variable to
  md5hashLocation      : shortInt;

function XT_Init(nVersion, nFlags: DWord; hMainWnd: THandle; lpReserved: Pointer): LongInt; stdcall; export;
begin
  //any global variable can be initilaised here if necessary
  commentCount := 0;
  md5hashLocation := $0;
  //check XWF is ready to go. 1 is normal more, 2 is thread-safe
  if Assigned(XWF_OutputMessage) then
  begin
    result := 1; //lets go
    MainWnd := hMainWnd;
  end
  else result := -1; //stop
end;


// XT_About: Provides information about the X-Tension
function XT_About (hMainWnd : THandle; lpReserved : Pointer) : Longword; stdcall; export;
begin
  result := 0;
  MessageBox(MainWnd, 'This X-Tension is designed to match Relativity information with an X-Ways case utilising the MD5 Hash', 'XWF-RelativityInfo', MB_ICONINFORMATION);
end;

// LoadCSV: Loads the CSV file into the Tlist, csvStringList.
// Returns 0 on success, returns -1 on failure
function LoadCSV() : integer ; stdcall; export;
begin
  result := Default(integer);
  csvStringList:= TStringList.Create;
  csvStringList.LoadFromFile(csvPath);
  result := 0;
end;

// print: Prints string to XWF messages box
// Returns 0 on success, returns -1 on failure
function print(printString : String): integer ;stdcall; export;
const
  Buflen=255;
var
  Buf, outputmessage: array[0..Buflen-1] of WideChar;
begin
  result := Default(integer);
  outputmessage := printString;
  lstrcpyw(Buf, outputmessage);
  XWF_OutputMessage(@Buf[0],0);
  result := 0;

end;

// XT_Prepare: Ensures the X-Tension has been run correctly (i.e from the right click menu)
// Takes user inputted filepath/name as CSV file location.
function XT_Prepare(hVolume, hEvidence : THandle; nOpType : DWord; lpReserved: Pointer) : integer; stdcall; export;
begin

  if nOpType <> 4 then
  begin
    MessageBox(MainWnd, 'Error: This X-Tension can only be run from the right click menu', 'XWF-RelativityInfo', MB_ICONINFORMATION);
    result := -3;
  end
  else
  begin
    // If the filepath is already set, do not ask for it again
    if csvPathSet = False then
    begin
    // Ensures the File exists
      while not FileExists(csvPath) do
      begin
        XWF_GetUserInput('Please enter the full path & filename of CSV', csvPath, Length(csvPath), $00000002);
      end;
      csvPathSet := True;
    end;
    print('X-Tension Started (screen may become unresponsive, please wait)');

    // Checks to see where the MD5 hash is (primary/secondary)
    if XWF_GetVSProp(20, nil) = 7 then
    begin
      print('MD5 located as Primary Hash');
      md5hashLocation := $01
    end
    else if XWF_GetVSProp(21, nil) =  7 then
    begin
      print('MD5 located as Secondary Hash');
      md5hashLocation := $02
    end
    else
    begin
        print('MD5 hash cannot be found');
        exit;
    end;


    startTime := now;
    LoadCSV();
    result := XT_PREPARE_CALLPI;
  end;
end;



// addComment: Adds a comment based on the input ItemID and the CommentString
// Returns 0 on success, returns -1 on failure
function addComment(ItemID: LongWord; commentString: string): integer ;stdcall; export;
const
  BufLen=500;    // Needs to be long to ensure everything is captured, the comments with duplicate custodians can run to very long
var
  textToAdd      : array[0..Buflen-1] of WideChar;
  flag           : array of Byte;
  commentSuccess : Boolean;
begin
  result := Default(integer);
  SetLength(flag, 1);
  flag[0] := $01;         //flag is for adding comment

  textToAdd := commentString;
  try
    commentSuccess := XWF_AddComment(ItemID,textToAdd, flag[0]);
  except
     print('Error adding comment on item ' + IntToStr(ItemID));
     commentSuccess := false;
  end;
  if commentSuccess then
  begin
    //print('Comment "' + commentString + '" added to file X-Ways ID: ' + IntToStr(ItemID));
    Inc(commentCount,1 );
    if (commentCount mod 250 = 0) then
    begin
       print('Comments added for ' + IntToStr(commentCount) + ' items.');
    end;

    result := 0;
  end;
end;

// GetHashValue : returns a string representation of a hash value, if one exists.
// Returns empty string on failure.
// written by T SMITH (https://github.com/hmrc/XT_XWF-2-RT), edited by GP to use MD5 hash only
function GetHashValue(ItemID : LongWord) : string ; stdcall; export;
var
  i               : integer = Default(integer);
  HashValue       : string  = Default(string);
  HasAHashValue   : Boolean = Default(boolean);
  bufHashVal      : array of Byte;
begin
  result := Default(string);
  SetLength(bufHashVal, 16);  // MD5 is 128 bits, 16 bytes, so 32 hex chars produced.
  FillByte(HashValue, SizeOf(bufHashVal), $00);

  // XWF_GetHashValue returns the appropriate hash value as a digest, if one exists.
  // The buffer it stores it in has to start with 0x01 for the primary hash value, 0x02 for secondary hash.
  bufHashVal[0] := md5hashLocation;
  HasAHashValue := XWF_GetHashValue(ItemID, @bufHashVal[0]);

  // if a hash digest was returned, itterate it to a string
  if HasAHashValue then
  for i := 0 to Length(bufHashVal) -1 do
  begin
   HashValue := HashValue + IntToHex(bufHashVal[i],2);
  end;
  result := HashValue;
end;


// searchCSV: Searches the list for the matching hash
// Returns 0 on success (hash found and matched), returns -1 when no hash matched
function searchCSV(nItemID: LongWord; hashString : string) : integer ; stdcall; export;
var
   strItemComment, strDuplicateComment : string;
   i               : longint;
   strArray        : Array of String;
   hasComment      : Bool;
begin
  result := Default(integer);
  if not (hashString = '') then // Only continues if there is a hash value
  begin

    csvStringListLength := csvStringList.Count;  //get the amount of items in the CSV/array

    //loops over the array from start to end to match any hashes
    for i:= 0 to (csvStringListLength -1) do
    begin
      // 0 = MD5Hash, 1 = documentID, 2 = Nuix GUID, 3 = Duplicate custodians
      strArray     := csvStringList[i].Split(',');

      // If the hash is found in the list
      if (CompareText(strArray[0],hashString)=0) then
      begin

        // Check to determine if the item has a comment already.
        // If a comment exists, do not add the duplicate custodians comments to reduce overall report size
        // If a comment does not exist, add in the necessary ducplicate custodians. This is added on its own line for better report readability
        if (XWF_GetItemInformation(nItemID, XWF_ITEM_INFO_FLAGS, @hasComment) and $2000) = 0 then
        begin
          strDuplicateComment :=  'Duplicate Custodians (MD5 Hash): ' + strArray[3] ;
          addComment(nItemID, strDuplicateComment) // add this as a seperate line to ensure that it is added on a new line
        end;

      strItemComment := 'Relativity ID: ' + strArray[1] + '. Nuix GUID: '  +  strArray[2];
      addComment(nItemID, strItemComment);

      result := 1;
      end;
    end;
  end;

end;

// XT_ProcessItem: Called for each file selected
// Returns 0 on success, returns -1 on failure
function XT_ProcessItem(nItemID : LongWord; lpReserved : Pointer) : integer; stdcall; export;
begin
  result := Default(integer);
  searchCSV(nItemID,GetHashValue(nItemID));  //gets the HASH value as a string and uses that as the input into the fuction, SearchCSV
  result := 0;
end;

function XT_Finalize (hVolume, hEvidence : THandle; nOpType : DWord; lpReserved : Pointer) : integer; stdcall; export;
begin
  result := 0;
  end;

function XT_Done(lpReserved: Pointer) : integer; stdcall; export;
var
   endTime : TDateTime;
   timeTaken : string;
begin
  endTime := Now;
  timeTaken := FormatDateTime('HH:MM:SS',endTime-startTime);
  result := Default(integer);
  print('XWF_RelativityID v1.0');
  print('Time Take: ' + timeTaken);
  print(IntToStr(csvStringListLength) + ' lines in CSV');
  print(IntToStr(commentCount) + ' comments added.');
  FreeAndNil(csvStringList); // Clear list now finished
  result := 0;
end;


exports
XT_Init,
XT_About,
XT_Prepare,
XT_ProcessItem,
XT_Finalize,
XT_Done;

begin
end.

