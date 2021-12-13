unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, LazFileUtils, IniFiles, process;

type

  { TMainForm }

  TMainForm = class(TForm)
    ProgressBar: TProgressBar;
    DirectoryDialog: TSelectDirectoryDialog;
    SourceDirectoryButton: TButton;
    ProcessButton: TButton;
    PhotoCenterCombo: TComboBox;
    PaperTypeCombo: TComboBox;
    SourceDirectoryEdit: TEdit;
    OriginalImage: TImage;
    ConvertedImage: TImage;
    SourceDirectoryLabel: TLabel;
    PhotoCenterLabel: TLabel;
    PaperTypeLabel: TLabel;
    PhotoList: TListBox;
    PreviewPanel: TPanel;
    ComboSeparatorPanel: TPanel;
    ListSeparatorPanel: TPanel;
    ImageSeparatorPanel: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure PaperTypeComboChange(Sender: TObject);
    procedure PhotoCenterComboChange(Sender: TObject);
    procedure PhotoListSelectionChange(Sender: TObject; User: boolean);
    procedure ProcessButtonClick(Sender: TObject);
    procedure SourceDirectoryButtonClick(Sender: TObject);
  private
    fPhotoCenters: TStringList;
    fICCProfile: string;
    procedure LoadDirectory;
    procedure Init;
    function ProcessImage(aSource: string; aDestination: string): boolean;
    function DeleteBrackets(aSrc: string): string;
  public

  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

{ TMainForm }

procedure TMainForm.SourceDirectoryButtonClick(Sender: TObject);
begin
  if DirectoryDialog.Execute then
  begin
    SourceDirectoryEdit.Text:=DirectoryDialog.FileName;
    LoadDirectory;
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Randomize;
  Init;
end;

procedure TMainForm.PaperTypeComboChange(Sender: TObject);
var
  aSection: TStringList;
begin
  if PhotoCenterCombo.ItemIndex<>-1 then
  begin
    aSection:=fPhotoCenters.Objects[PhotoCenterCombo.ItemIndex] as TStringList;
    fICCProfile:=fPhotoCenters.Names[PhotoCenterCombo.ItemIndex]+'_'+aSection.Names[PaperTypeCombo.ItemIndex]+'.icc';
  end;
  if PhotoList.ItemIndex<>-1 then PhotoList.OnSelectionChange(PhotoList, false);
end;

procedure TMainForm.PhotoCenterComboChange(Sender: TObject);
var
  aSection: TStringList;
  aLast: string;
  i: Integer;
begin
  if PhotoCenterCombo.ItemIndex<>-1 then
  begin
    aLast:=PaperTypeCombo.Text;
    PaperTypeCombo.Clear;
    aSection:=fPhotoCenters.Objects[PhotoCenterCombo.ItemIndex] as TStringList;
    for i:=0 to aSection.Count-1 do
    begin
      PaperTypeCombo.Items.Add(aSection.ValueFromIndex[i]);
    end;
    if PaperTypeCombo.Items.Count>0 then
    begin
      if PaperTypeCombo.Items.IndexOf(aLast)<>-1 then
        PaperTypeCombo.ItemIndex:=PaperTypeCombo.Items.IndexOf(aLast)
      else
        PaperTypeCombo.ItemIndex:=0;
      PaperTypeCombo.OnChange(PaperTypeCombo);
    end;
  end;
end;

procedure TMainForm.PhotoListSelectionChange(Sender: TObject; User: boolean);
var
  aConverted, aOriginal: String;
begin
  aOriginal:=SourceDirectoryEdit.Text+DirectorySeparator+PhotoList.Items[PhotoList.ItemIndex];
  aConverted:=GetTempFileNameUTF8('', 'icc')+'.jpg';
  ProcessImage(aOriginal, aConverted);
  OriginalImage.Picture.LoadFromFile(aOriginal);
  if FileExistsUTF8(aConverted) then
  begin
    ConvertedImage.Picture.LoadFromFile(aConverted);
    DeleteFileUTF8(aConverted);
  end;
end;

procedure TMainForm.ProcessButtonClick(Sender: TObject);
var
  aConverted, aOriginal, aDstDir: String;
  i: Integer;
begin
  ProcessButton.Enabled:=false;
  PhotoList.Enabled:=false;
  SourceDirectoryButton.Enabled:=false;
  PhotoCenterCombo.Enabled:=false;
  PaperTypeCombo.Enabled:=false;
  ProgressBar.Position:=0;
  ProgressBar.Max:=PhotoList.Items.Count;
  aDstDir:=SourceDirectoryEdit.Text+DirectorySeparator+DeleteBrackets(PhotoCenterCombo.Text)+'_'+DeleteBrackets(PaperTypeCombo.Text);
  if not DirectoryExistsUTF8(aDstDir) then
  begin
    CreateDirUTF8(aDstDir);
  end;
  for i:=0 to PhotoList.Items.Count-1 do
  begin
    Application.ProcessMessages;
    aOriginal:=SourceDirectoryEdit.Text+DirectorySeparator+PhotoList.Items[i];
    aConverted:=aDstDir+DirectorySeparator+PhotoList.Items[i];
    ProcessImage(aOriginal, aConverted);
    ProgressBar.Position:=i+1;
  end;
  ProcessButton.Enabled:=true;
  PhotoList.Enabled:=true;
  SourceDirectoryButton.Enabled:=true;
  PhotoCenterCombo.Enabled:=true;
  PaperTypeCombo.Enabled:=true;
end;

procedure TMainForm.LoadDirectory;
var
  aRec: TSearchRec;
begin
  PhotoList.Clear;
  if FindFirstUTF8(SourceDirectoryEdit.Text+'/*.jpg', faAnyFile, aRec)=0 then
  begin
    repeat
      PhotoList.Items.Add(aRec.Name);
    until FindNextUTF8(aRec)<>0;
  end;
  FindCloseUTF8(aRec);
  if (PaperTypeCombo.ItemIndex<>-1) and (PhotoCenterCombo.ItemIndex<>-1) and DirectoryExistsUTF8(SourceDirectoryEdit.Text) and (PhotoList.Items.Count>0) then
  begin
    ProcessButton.Enabled:=true;
    PhotoList.ItemIndex:=0;
  end else
  begin
    ProcessButton.Enabled:=false;
  end;
end;

procedure TMainForm.Init;
var
  aIni: TIniFile;
  aPhotoSection: TStrings;
  aSection: TStrings;
  i, r: Integer;
  fSection: TStringList;
begin
  PhotoCenterCombo.Clear;
  aIni := TIniFile.Create(ExtractFileNameWithoutExt(Application.ExeName)+'.ini');
  fPhotoCenters := TStringList.Create;
  aPhotoSection := TStringList.Create;
  aSection := TStringList.Create;
  aIni.ReadSection('photocenters', aPhotoSection);
  for i:=0 to aPhotoSection.Count-1 do
  begin
    if aIni.SectionExists(aPhotoSection[i]) then
    begin
      aSection.Clear;
      fSection := TStringList.Create;
      aIni.ReadSection(aPhotoSection[i], aSection);
      for r:=0 to aSection.Count-1 do
      begin
        fSection.AddPair(aSection[r], aIni.ReadString(aPhotoSection[i], aSection[r], ''));
      end;
      fPhotoCenters.AddPair(aPhotoSection[i], aIni.ReadString('photocenters', aPhotoSection[i], ''), fSection);
      PhotoCenterCombo.Items.Add(fPhotoCenters.Values[aPhotoSection[i]]);
    end;
  end;
  aIni.Free;
  if PhotoCenterCombo.Items.Count>0 then
  begin
    PhotoCenterCombo.ItemIndex:=0;
    PhotoCenterCombo.OnChange(PhotoCenterCombo);
  end;
end;

function TMainForm.ProcessImage(aSource: string; aDestination: string): boolean;
var
  aOutput, aICC: string;
begin
  result:=false;
  aICC:=ExtractFileDir(Application.ExeName)+DirectorySeparator+'icc'+DirectorySeparator+fICCProfile;
  if FileExistsUTF8(aICC) then
  begin
    {$IFDEF WINDOWS}
    if not RunCommand(ExtractFileDir(Application.ExeName)+DirectorySeparator+'convert.exe', [aSource, '-profile', aICC, '-strip', aDestination], aOutput, [poWaitOnExit], swoHIDE) then exit;
    {$ELSE}
    if not RunCommand('/usr/bin/convert', [aSource, '-profile', aICC, '-strip', aDestination], aOutput, [poWaitOnExit], swoNone) then exit;
    {$ENDIF}
    result:=true;
  end;
end;

function TMainForm.DeleteBrackets(aSrc: string): string;
var
  bpos: SizeInt;
begin
  bpos:=Pos('(', aSrc);
  if bpos<>-1 then
  begin
    aSrc:=trim(Copy(aSrc, 1, bpos-1));
  end;
  result:=aSrc;
end;

end.

