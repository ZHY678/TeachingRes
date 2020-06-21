unit U2950Program;

interface

uses Winapi.Windows, classes, scanCONTRAL, math,System.SysUtils;

type
  Tarr = array of Double;
  axis = array[0..1] of Double;
  TTimeMessage = record
    Head : Byte;
    ProfileCounter : Integer;
    OpenSecondsCounter : Byte;
    OpenCycleCounter : Word;
    OpenCycleOffset : Word;
    OpenTimestamp : Double;
    EdgeCounter : Integer;
    Reserved : Word;
    CloseSecondsCounter : Byte;
    CloseCycleCounter : Word;
    CloseCycleOffset : Word;
    CloseTimestamp : Double;
  end;
  TRetVal = record
    D1 : Single;
    D2 : Single;
  end;
  TConfig = record
    UpArf     : Single;
    DownArf   : Single;
    UpBeta    : Single;
    DownBeta  : Single;
    UpValue   : Single;
    DownValue : Single;
    DistanceL : Single;
    IsHotAdd  : Boolean;
  end;



TscanControl = class
  private
    //Sum2D: Double;
    FConnectFlag1: Boolean;
    FConnectFlag2: Boolean;
  public
    Dev1ValueX:Tarr;
    Dev1ValueZ:Tarr;
    Dev2ValueX:Tarr;
    Dev2ValueZ:Tarr;
    Dev1ProfileBuffer:array of byte;
    Dev2ProfileBuffer:array of byte;
    OrigData : TFileStream;
    constructor Create;
    destructor Destroy;override;
    procedure Connect;
    procedure Disconnect;
    procedure CreateOrigDataFile;
    procedure CloseOrigDataFile;
    function GetProfile_Ethernet: TRetVal;
//    procedure disconnect;
//    function getprofile_Ethernet:Double;
    property ConnectFlag1 : Boolean read FconnectFlag1;
    property ConnectFlag2 : Boolean read FconnectFlag2;
end;

implementation

uses
  MainInterface, UGlobalpara;
{ TscanControl }

constructor TscanControl.Create;
begin
  inherited;
  //Sum2D:=0;
  //AVGlaser2D:=0;
  FConnectFlag1:= False;
  FConnectFlag2:= False;
  gIpAdress[0]:=$A9FE006F;
  gIpAdress[1]:=$A9FE00DE;
end;

destructor TscanControl.Destroy;
begin
  if gDevConnected>0 then
  begin
    if gCreate_dev1>0 then
      s_disconnect(gCreate_dev1);
    if gCreate_dev2>0 then
      s_disconnect(gCreate_dev2);
    SetLength(gCalPointsFlag1,0);
    SetLength(gCalPointsFlag2,0);
  end;
end;

procedure TscanControl.Connect;
var
  bok,Connectflag : Integer;
begin
  Connectflag:=0;
  while True do
  begin
    inc(Connectflag);
    gCreate_dev1:=s_CreateLLTDevice(INTF_TYPE_ETHERNET);
    //e:=s_GetDeviceInterfacesFast(Create_dev1,@IpAdress[0],SizeOf(IpAdress));   //获得设备IP
    bok:=s_SetDeviceInterface(gCreate_dev1,gIpAdress[0],0);
    gDevConnected:=s_Connect(gCreate_dev1);
    bok:=s_SetFeature(gCreate_dev1,FEATURE_FUNCTION_SHUTTERTIME,100);
    bok:=s_SetFeature(gCreate_dev1,FEATURE_FUNCTION_IDLETIME,900);
    if (Connectflag>3) then
    begin
      ThicknessMeasurement.RibbonStatusBar.Panels[2].Text:='上传感器连接失败！';
      Break;
    end
    else if (gDevConnected>0) then Break;
  end;
  if gDevConnected>0 then
  begin
    s_GetLLTType(gCreate_dev1,@gScanType1);
    bOK:=s_GetResolutions(gCreate_dev1,@gPresolution[0],SizeOf(gPresolution));
    if bok>0 then
    begin
      SetLength(Dev1ValueX,gPresolution[0]);
      SetLength(Dev1ValueZ,gPresolution[0]);
      SetLength(gCalPointsFlag1,gPresolution[0]);
      SetLength(Dev1ProfileBuffer,gPresolution[0]*4+16);
      s_TransferProfiles(gCreate_dev1, NORMAL_TRANSFER,True);
      FConnectFlag1:= True;
      Inc(gDevConnectNum);
      gDev1DataIsRight:=True;
    end;
  end
  else
  begin
    s_disconnect(gCreate_dev1);
    if gDevConnectNum>0 then  Dec(gDevConnectNum);
  end;
  Connectflag:=0;
  while True do
  begin
    inc(Connectflag);
    gCreate_dev2:=s_CreateLLTDevice(INTF_TYPE_ETHERNET);
    //e:=s_GetDeviceInterfacesFast(Create_dev2,@ipadress[0],SizeOf(IpAdress2));  //获得设备IP
    bok:=s_SetDeviceInterface(gCreate_dev2,gIpAdress[1],0);
    gDevConnected:=s_Connect(gCreate_dev2);
    bok:=s_SetFeature(gCreate_dev2,FEATURE_FUNCTION_SHUTTERTIME,100);
    bok:=s_SetFeature(gCreate_dev2,FEATURE_FUNCTION_IDLETIME,900);
    if (Connectflag>3) then
    begin
      ThicknessMeasurement.RibbonStatusBar.Panels[2].Text:=ThicknessMeasurement.RibbonStatusBar.Panels[2].Text + '下传感器连接失败！';
      Break;
    end
    else
    if (gDevConnected>0) then Break;
  end;
  if gDevConnected>0 then
  begin
    s_GetLLTType(gCreate_dev2,@gScanType2);
    bOK:=s_GetResolutions(gCreate_dev2,@gPresolution[0],SizeOf(gPresolution));
    if bok>0 then
    begin
      SetLength(Dev2ValueX,gPresolution[0]);
      SetLength(Dev2ValueZ,gPresolution[0]);
      SetLength(gCalPointsFlag2,gPresolution[0]);
      SetLength(Dev2ProfileBuffer,gPresolution[0]*4+16);
      s_TransferProfiles(gCreate_dev2, NORMAL_TRANSFER,True);
      FConnectFlag2:= True;
      Inc(gDevConnectNum);
      gDev2DataIsRight:=True;
    end;
  end
  else
  begin
    s_disconnect(gCreate_dev2);
    if gDevConnectNum>0 then  Dec(gDevConnectNum);
  end;
end;

procedure TscanControl.Disconnect;
begin
  if gCreate_dev1>0 then
  begin
    s_Disconnect(gCreate_dev1);
    Dec(gDevConnectNum);
  end;
  FConnectFlag1:=False;
  if gCreate_dev2>0 then
  begin
    s_Disconnect(gCreate_dev2);
    Dec(gDevConnectNum);
  end;
  FConnectFlag2:=False;
end;

function TscanControl.GetProfile_Ethernet: TRetVal;
var
  transOK,k,NozeroNum1,NozeroNum2:Integer;
  sum2d2,Sum2D1:Double;
  i,j,index1,index2: Integer;
  OrgiFileName,FilePath : string;
begin
  if (FConnectFlag1=True) then
  begin
    sum2d1:=0;
    NozeroNum1:=0;
    transok:=s_GetActualProfile(gCreate_dev1,@Dev1ProfileBuffer[0],gPresolution[0]*4+16,PURE_PROFILE,nil);
    if transok>0 then
    begin
      if not gDev1DataIsRight then gDev1DataIsRight:=True;
      transok:=s_ConvertProfile2Values(gCreate_dev1,@Dev1ProfileBuffer[0],gPresolution[0],PURE_PROFILE,gScanType1,
                0, true, nil, nil, nil, @Dev1ValueX[0], @Dev1ValueZ[0], nil, nil);
//      transok:=s_Timestamp2TimeAndCount(@Dev1ProfileBuffer[5120],@gTimeShutterOpen1,@gTimeShutterClose1,@gProfileCount1);
//      index1:=frmMain.BinarySearchNear(Dev1ValueX,0,High(Dev1ValueX),gCalibCenterX,True);
      index2 := 1;
      for i := 0 to Length(Dev1ValueZ)- 1 do
      begin
        gCalPointsFlag1[i]:=False;
        if Dev1ValueZ[i]<>0 then
        begin
          Sum2D1:= Sum2D1+ Dev1ValueZ[i];
          gCalPointsFlag1[Length(Dev1ValueZ)-1-i]:=True;
          Inc(NozeroNum1);
        end
        else
        begin
          if (index1+DetectWidth<i) or (index1-DetectWidth>i) then
          Dev1ValueZ[i]:=Dev1ValueZ[i-1];
        end;
      end;
      if Sum2D1<>0 then
        Result.D1:= Roundto(Sum2D1/nozeroNum1,-3)
      else
        Result.D1:=0;
      if (Result.D1>30) and (Result.D1<160) then
        gDev1DataIsOut:= False
      else
        gDev1DataIsOut:= True;
//      CopyMemory(@frmMain.TimeArr[0],@Dev1ProfileBuffer[5120],16);
//      gUpTimeMess:=ThicknessMeasurement.GetTimeMessage(frmMain.TimeArr);
    end
    else
    begin
      for i := 0 to Length(Dev1ValueZ)- 1 do
      begin
        Dev1ValueZ[i]:=0;
      end;
      result.D1:=-1;
      if gDev1DataIsRight then gDev1DataIsRight:=False;
    end;
  end
  else
    result.D1:=0;
//***********
  if (FConnectFlag2=True) then
  begin
    sum2d2:=0;
    NozeroNum2:=0;
    transok:=s_GetActualProfile(gCreate_dev2,@Dev2ProfileBuffer[0],gPresolution[0]*4+16,PURE_PROFILE,nil);
    if transok>0 then
    begin
      if not gDev2DataIsRight then gDev2DataIsRight:=True;
      transok:=s_ConvertProfile2Values(gCreate_dev2,@Dev2ProfileBuffer[0],gPresolution[0],PURE_PROFILE,gScanType2,
                  0, true, nil, nil, nil, @Dev2ValueX[0], @Dev2ValueZ[0], nil, nil);
//      transok:=s_Timestamp2TimeAndCount(@Dev2ProfileBuffer[5120],@gTimeShutterOpen2,@gTimeShutterClose2,@gProfileCount2);
//      index2:=frmMain.BinarySearchNear(Dev2ValueX,0,High(Dev2ValueX),gCalibCenterX,True);

      index2 := 1;
      for i := 0 to  Length(Dev2ValueZ) - 1 do
      begin
        gCalPointsFlag2[i]:=False;
        if Dev2ValueZ[i]<>0 then
        begin
          Sum2D2:= Sum2D2+ Dev2ValueZ[i];
          gCalPointsFlag2[i]:=True;
          Inc(NozeroNum2);
        end
        else
        begin
          if (index2+DetectWidth<i) or (index2-DetectWidth>i) then
            Dev2ValueZ[i]:=Dev2ValueZ[i-1];
        end;
      end;
      if Sum2D2<>0 then
        Result.D2:= Roundto(Sum2D2/nozeroNum2,-3)
      else
        Result.D2:=0;
      if (Result.D2>30) and (Result.D2<160) then
        gDev2DataIsOut:= False
      else
        gDev2DataIsOut:= True;
//      CopyMemory(@frmMain.TimeArr2[0],@Dev2ProfileBuffer[5120],16);
//      gDownTimeMess:=frmMain.GetTimeMessage(frmMain.TimeArr2);
    end
    else
    begin
      for i := 0 to Length(Dev2ValueZ)- 1 do
      begin
        Dev2ValueZ[i]:=0;
      end;
      result.D2:=-1;
      if gDev2DataIsRight then gDev2DataIsRight:=False;
    end;
  end
  else
    result.D2:=0;
//  if False then
//  begin
//    if not Assigned(OrigData) then
//    begin
//      if not DirectoryExists(FilePath) then
//      begin
//        FilePath:='E:\HDJC\Win32\Debug' + 'SaveData';
//        CreateDir(FilePath);
//      end
//      else
//      begin
//
//      end;
//      OrgiFileName:=FilePath+'\'+FormatDateTime('yymmddhhnnss',Now())+'.txt';
//    end
//    else
//    begin
//
//    end;
//  end;

end;

procedure TscanControl.CreateOrigDataFile;
begin

end;

procedure TscanControl.CloseOrigDataFile;
begin

end;

end.
