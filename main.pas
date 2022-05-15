unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, PairSplitter, LazFileUtils, IniFiles, process, LCLProc;

type

  { TMainForm }

  TMainForm = class(TForm)
    PaintBox: TPaintBox;
    ProgressBar: TProgressBar;
    DirectoryDialog: TSelectDirectoryDialog;
    SourceDirectoryButton: TButton;
    ProcessButton: TButton;
    PhotoCenterCombo: TComboBox;
    PaperTypeCombo: TComboBox;
    SourceDirectoryEdit: TEdit;
    SourceDirectoryLabel: TLabel;
    PhotoCenterLabel: TLabel;
    PaperTypeLabel: TLabel;
    PhotoList: TListBox;
    PreviewPanel: TPanel;
    ComboSeparatorPanel: TPanel;
    ListSeparatorPanel: TPanel;
    Splitter1: TSplitter;
    procedure ConvertedImageClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure OriginalImageClick(Sender: TObject);
    procedure PaintBoxPaint(Sender: TObject);
    procedure PairSplitter1ChangeBounds(Sender: TObject);
    procedure PaperTypeComboChange(Sender: TObject);
    procedure PhotoCenterComboChange(Sender: TObject);
    procedure PhotoListSelectionChange(Sender: TObject; User: boolean);
    procedure ProcessButtonClick(Sender: TObject);
    procedure SourceDirectoryButtonClick(Sender: TObject);
    procedure Splitter1Moved(Sender: TObject);
  private
    fPhotoCenters: TStringList;
    fICCProfile: string;
    fPainting: Boolean;
    FOriginalImage, FConvertedImage: TPicture;
    function DstRect(Picture: TPicture): TRect;
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

procedure TMainForm.Splitter1Moved(Sender: TObject);
begin

end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Randomize;
  Init;
end;

procedure TMainForm.OriginalImageClick(Sender: TObject);
begin

end;

procedure TMainForm.PaintBoxPaint(Sender: TObject);
var
  R, DR, SR: TRect;
  C: TCanvas;
begin
  // detect loop
  if FPainting then exit;

  if (FOriginalImage.Graphic=nil) or (FConvertedImage.Graphic=nil) then exit;

    R := DstRect(FOriginalImage);

    C := PaintBox.Canvas;

    C.AntialiasingMode := amOff;

    FPainting:=true;
    try
      DR := Rect(R.Left, R.Top, Splitter1.Left, R.Bottom);
      SR := Rect(0, 0, round(FOriginalImage.Bitmap.Width*double(Splitter1.Left-R.Left)/double(R.Right-R.Left)), FOriginalImage.Bitmap.Height);
      C.CopyRect(DR, FOriginalImage.Bitmap.Canvas, SR);

      DR := Rect(Splitter1.Left, R.Top, R.Right, R.Bottom);
      SR := Rect(round(FConvertedImage.Bitmap.Width*double(Splitter1.Left-R.Left)/double(R.Right-R.Left)), 0, FConvertedImage.Bitmap.Width, FConvertedImage.Bitmap.Height);
      C.CopyRect(DR, FConvertedImage.Bitmap.Canvas, SR);
    finally
      FPainting:=false;
    end;
end;

procedure TMainForm.ConvertedImageClick(Sender: TObject);
begin

end;

procedure TMainForm.PairSplitter1ChangeBounds(Sender: TObject);
begin

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
  aConverted, aOriginal, aOutput: String;
  R: TRect;
begin
  aOriginal:=SourceDirectoryEdit.Text+DirectorySeparator+PhotoList.Items[PhotoList.ItemIndex];
  aConverted:=GetTempFileNameUTF8('', 'icco')+'.jpg';

  {$IFDEF WINDOWS}
  if not RunCommand(ExtractFileDir(Application.ExeName)+DirectorySeparator+'convert.exe', [aOriginal, '-resize', inttostr(PaintBox.Width)+'x'+inttostr(PaintBox.Height), aConverted], aOutput, [poWaitOnExit], swoHIDE) then exit;
  {$ELSE}
  if not RunCommand('/usr/bin/convert', [aOriginal, '-resize', inttostr(PaintBox.Width)+'x'+inttostr(PaintBox.Height), aConverted], aOutput, [poWaitOnExit], swoNone) then exit;
  {$ENDIF}
  aOriginal:=aConverted;
  aConverted:=GetTempFileNameUTF8('', 'iccc')+'.jpg';

  if FileExistsUTF8(aOriginal) then
  begin
    FOriginalImage.LoadFromFile(aOriginal);
    ProcessImage(aOriginal, aConverted);
    DeleteFileUTF8(aOriginal);
  end;
  if FileExistsUTF8(aConverted) then
  begin
    FConvertedImage.LoadFromFile(aConverted);
    DeleteFileUTF8(aConverted);
  end;
  PaintBox.Invalidate;
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
  FOriginalImage := TPicture.Create;
  FConvertedImage := TPicture.Create;
  PhotoCenterCombo.Clear;
  aIni := TIniFile.Create(ExtractFilePath(Application.ExeName)+'iccconvertor.ini');
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

function TMainForm.DstRect(Picture: TPicture):TRect;
var
  PicWidth: Integer;
  PicHeight: Integer;
  ImgWidth: Integer;
  ImgHeight: Integer;
  w: Integer;
  h: Integer;
  ChangeX, ChangeY: Integer;
  PicInside, PicOutside, PicOutsidePartial: boolean;
begin
  PicWidth := Picture.Width;
  PicHeight := Picture.Height;
  ImgWidth := PaintBox.ClientWidth;
  ImgHeight := PaintBox.ClientHeight;
  if (PicWidth=0) or (PicHeight=0) then Exit(Rect(0, 0, 0, 0));

  PicInside := (PicWidth<ImgWidth) and (PicHeight<ImgHeight);
  PicOutside := (PicWidth>ImgWidth) and (PicHeight>ImgHeight);
  PicOutsidePartial := (PicWidth>ImgWidth) or (PicHeight>ImgHeight);

  w:=ImgWidth;
  h:=(PicHeight*w) div PicWidth;
  if h>ImgHeight then begin
    h:=ImgHeight;
    w:=(PicWidth*h) div PicHeight;
  end;
  PicWidth:=w;
  PicHeight:=h;

  Result := Rect(0, 0, PicWidth, PicHeight);

  ChangeX := (ImgWidth-PicWidth) div 2;
  ChangeY := (ImgHeight-PicHeight) div 2;
  OffsetRect(Result, ChangeX, ChangeY);
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

