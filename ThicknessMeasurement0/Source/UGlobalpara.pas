unit UGlobalpara;

interface

Uses
  System.SysUtils, Vcl.Dialogs, sfContnrs, Winapi.Windows, UThicknessMeasurement2D, Winapi.Messages, USoftwareFunction;

type
  TGlobalpara = class
    public
      Procedure ShowAndSaveErrorLog(TxtPath, ErrorProcedure, ErrorResult: string; TestFlag: Boolean);   //�������������ڴ����Ƿ�ʹ��
      function IsValid(TempValue : Integer) : Boolean;
      function IsNumberType(InputString : string) : Byte;   //����ֵ��0�����ַ�����1����������2����С��
      //��������������ɾ��
      procedure StartTest;
      procedure Test;
      procedure EndTest;
  end;

  TConfigParameter = record
    IsThermalCompensation, IsDebug : Byte;
    UpperSensorAngle, LowerSensorAngle, SensorsDistance, UpperLineMeanValue, LowerLineMeanValue, UpperSensorTemperature, LowerSensorTemperature, StandardThickness, CenterPoint : Double;
  end;

  TTemperature = record
    TemperatureData : array[0..7] of Double;
  end;

  TSensorPoints = record
    VdValueX, VdValueZ : array [0..1279] of Double;
  end;

  TXYAxis = record
    XAxis, ZAxis : Double;
  end;

  TKB = record
    K, B : Double;
  end;

  TDataArray = record
    DataArray : array [0..5127] of Double;
  end;

var
  ErrorLogPath, ConfigurationFilePath, BackupFilePath, SavedOriginalDataPath, SavedResultDataPath : string;
//  SensorTemperatureCache, UpperSensorCache, LowerSensorCache : TsfQueue;
  RealTimeCache, PlayBackCache : TsfQueue;
  IsSaving, IsOpenSensor, IsMeasuring, FanFormIsShow, LightFormIsShow, AutoShow, IsOriginalDataSave, IsPlayBackReady, TempIsOriginalDataSave, IsDetecting, IsCalibrating : Boolean;
  GConfigParameter, CalibConfigParameter : TConfigParameter;
  SerialPort, UpperLaserCore, LowerLaserCore, RecordUpperLaserCore, RecordLowerLaserCore : Cardinal;
  TimerCounts, SaveCounts, CalAverageIndex, CalCounts, CalibUpperCounts, CalibLowerCounts, WarningCounts : Byte;
  TempDataSavePath, TempOrignalDataSavePath, TempResultDataSavePath : string;
//  Orig1VdValueX, Orig1VdValueZ, Orig2VdValueX, Orig2VdValueZ, Rot1VdValueX, Rot1VdValueZ, Rot2VdValueX, Rot2VdValueZ : array [0..1279] of Double;   //��ʱ��ɾ������������ԸĻ���
  RealTimeData, PlayBackData : TDataArray;
  ThicknessMeasurementFormHandle : LongWord;
  AverageCounts : Word;
  AverageTestArray, AverageArray, CalAverageArray : array of Double;
  CalibUpperK, CalibLowerK : array [0..9] of Double;
  GMotorControl : TMotorControl;
  Controller, ID : string;

//  RTLCriticalSection : TRTLCriticalSection;
  //2D��ر���
  SenSor2D1, SenSor2D2 : Byte;
  IRetValue, M_TscanCONTROLType1, M_TscanCONTROLType2 : Integer;
  VdwResolutions1, VdwResolutions2 : array[0..6] of DWORD;
  VucProfileBuffer1, VucProfileBuffer2 : array of Byte;
  VuiEthernetInterfaces : array[0..5] of Cardinal;
  FThicknessMeasurement2D : TThicknessMeasurement2D;
  UpperSensorPoints, LowerSensorPoints : TSensorPoints;

  TempFile, TempOriginal : TextFile;
  TempTxtPath : String;

const
  MinResidualDiskSize = 5.0;

  DetectWidth = 200;
  CalibWidth = 200;
  IniDifX = -2;
  WeightH = 0;   //��ֵȨ��

  CalAverageLength = 100;

  WM_PaintPointer = WM_USER + $1000;
  WM_PlayBackPaintPointer = WM_USER + $1001;

implementation

procedure TGlobalpara.ShowAndSaveErrorLog(TxtPath: string; ErrorProcedure: string; ErrorResult: string; TestFlag: Boolean);
var
  ErrorInformation : String;
  ErrorFile : TextFile;
begin
  ErrorInformation := FormatDateTime('yyyy��mm��dd�� hhʱnn��ss��', now()) + ':������ϢΪ' + ErrorResult + ',����ص�λ��' + ErrorProcedure;
  AssignFile(ErrorFile, TxtPath);
  if FileExists(TxtPath) then append(ErrorFile)
  else
  begin
    ForceDirectories(ExtractFilePath(TxtPath));
    Rewrite(ErrorFile);
  end;
  writeln(ErrorFile, ErrorInformation);
  CloseFile(ErrorFile);
  if TestFlag then ShowMessage(ErrorResult);
end;

function TGlobalpara.IsValid(TempValue : Integer) : Boolean;
begin
  if (TempValue = Integer($80000000)) Or (TempValue = Integer($80000001)) Or (TempValue = Integer($80000002)) Or (TempValue = Integer($80000003)) then Result := False
  else Result := True;
end;

function TGlobalpara.IsNumberType(InputString: string) : Byte;   //����ֵ��0�����ַ�����1����������2����С��
var
  I : Word;
begin
  Result := 0;
  if Length(InputString) > 0 then
  Begin
    for I := 1 to Length(InputString) do
    Begin
      if (InputString[I] < '0') or (InputString[I] > '9') then
      Begin
        if (InputString[I] = '.') And (I <> 1) And (I <> Length(InputString)) then
        Begin
          if Result = 2 then
          Begin
            Result := 0;
            Exit;
          End;
          Result := 2;
          Continue;
        End;
        if (I = 1) And (InputString[I] = '-') And (Length(InputString) > 1) then Result := 1
        else
        Begin
          Result := 0;
          Exit;
        End;
      End;
    End;
    if Result <> 2 then Result := 1;
  End;
end;

procedure TGlobalpara.StartTest;
begin
  TempTxtPath := 'E:\ThicknessMeasurement\Bin\���Բ�����.txt';
  AssignFile(TempFile, TempTxtPath);
  if FileExists(TempTxtPath) then append(TempFile)
  else
  begin
    ForceDirectories(ExtractFilePath(TempTxtPath));
    Rewrite(TempFile);
  end;
end;

procedure TGlobalpara.Test;
begin
  writeln(TempFile, FormatDateTime('yyyy��mm��dd�� hh:nn:ss', Now));
end;

procedure TGlobalpara.EndTest;
begin
  CloseFile(TempFile);
end;
end.