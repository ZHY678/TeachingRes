unit sfcontnrs;

interface


{$DEFINE MULTI_THREAD_QUEUE} //�̰߳�ȫ�汾���������Ҫ�̰߳�ȫ����ע�͵����д���



{$IFDEF MULTI_THREAD_QUEUE}
uses
  Windows;
{$ENDIF}

type
  TsfQueue = class
  private
    FCapacity: Integer;
    FTmpBuff: Pointer;
    FBuff: Pointer;
    FPosition: Integer;
  {$IFDEF MULTI_THREAD_QUEUE}
    FCS: TRTLCriticalSection;
  {$ENDIF}
    //\\
    FPushIndex: Integer;
    FPopIndex: Integer;
    Fcount: Integer;
    procedure Lock();
    procedure UnLock();
    procedure Inernal_SetCapacity(const Value: Integer);
    //\\
    procedure setCapacity(const Value: Integer);
    function getCapacity: Integer;
  public
    property count: Integer read Fcount;
    constructor Create(InitCapacity: Integer = 1024);
    destructor Destroy(); override;
    //\\
    function Push(AItem: Pointer): Pointer;
    function Pop(): Pointer;
    procedure clear;
  public
    property Capacity: Integer read getCapacity write setCapacity;
  end;

implementation


{ TsfQueue }

constructor TsfQueue.Create(InitCapacity: Integer);
begin
  {$IFDEF MULTI_THREAD_QUEUE}
  InitializeCriticalSection(FCS);
  {$ENDIF}


  if InitCapacity < 1024 then
    InitCapacity := 1024;

  Inernal_SetCapacity(InitCapacity);

end;

destructor TsfQueue.Destroy;
begin

  FreeMem(FBuff);
  if FTmpBuff <> nil then
    FreeMem(FTmpBuff);
  //\\
  {$IFDEF MULTI_THREAD_QUEUE}
  DeleteCriticalSection(FCS);
  {$ENDIF}


  inherited;
end;

procedure TsfQueue.Lock;
begin
  {$IFDEF MULTI_THREAD_QUEUE}
  EnterCriticalSection(FCS);
  {$ENDIF}
end;

procedure TsfQueue.UnLock;
begin
  {$IFDEF MULTI_THREAD_QUEUE}
  LeaveCriticalSection(FCS);
  {$ENDIF}
end;

procedure TsfQueue.Inernal_SetCapacity(const Value: Integer);
var
  PageCount, ASize: Integer;
begin
  if Value > FCapacity then
  begin
    if FTmpBuff <> nil then
      FreeMem(FTmpBuff);


      //����
    ASize := Value * 4; //���������Ҫ���ֽ�����
    Pagecount := ASize div 4096;
    if (ASize mod 4096) > 0 then
      Inc(PageCount);


      //ת������
    GetMem(FTmpBuff, PageCount * 4096);
    FillChar(FTmpBuff^, PageCount * 4096, #0);

    if FBuff <> nil then
    begin
      Move(FBuff^, FTmpBuff^, FCapacity * 4);
      FreeMem(FBuff);
    end;

    FBuff := FTmpBuff;


      //�����µ�����
    FCapacity := (PageCount * 4096) div 4;

    if FCapacity >= 2048 then
    begin
         //FTmpBuff ��������Popʱ���ƶ��ڴ���
      GetMem(FTmpBuff, PageCount * 4096);
    end
    else
      FTmpBuff := nil;
  end;
end;

function TsfQueue.Pop: Pointer;

  procedure AdjuestMem();
  var
    pSrc: PInteger;
    pTmp: Pointer;
  begin
    FillChar(FTmpBuff^, FCapacity * 4, #0);
    pSrc := PInteger(FBuff);
    Inc(pSrc, FPopIndex);
    Move(pSrc^, FTmpBuff^, (FCapacity - FPopIndex) * 4);
    //\\
    //����ָ��
    pTmp := FBuff;
    FBuff := FTmpBuff;
    FTmpBuff := pTmp;
    //\\
  end;

const
  _MoveRange_ = 2048;
var
  P: PInteger;
begin
  Lock();
  try
    Result := nil;
    if (FPopIndex = FPushIndex) then
      Exit;
    P := PInteger(FBuff);
    Inc(P, FPopIndex);
    Result := Pointer(P^);
    Inc(FPopIndex);
    Dec(Fcount);
    //���еײ������ڴ�ﵽ 8192 �����Ǩ
    if FPopIndex = _MoveRange_ then
    begin
      AdjuestMem();
      FPopIndex := 0;
      Dec(FPushIndex, _MoveRange_);
    end;
  finally
    UnLock();
  end;
end;

function TsfQueue.Push(AItem: Pointer): Pointer;
var
  P: PInteger;
begin
  Lock();
  try
    P := PInteger(FBuff);
    Inc(P, FPushIndex);
    P^ := Integer(AItem);
    Inc(FPushIndex);
    inc(Fcount);
    if FPushIndex >= FCapacity then
    begin
      //���ݼ� 1024 ��λ��
      Inernal_SetCapacity(FCapacity + 1024);
    end;

  finally
    UnLock();
  end;
end;

procedure TsfQueue.clear;
var
  temp:Pointer;
  I: Integer;
begin
  Lock;
  try
    for I := 0 to Fcount do
    begin
      temp:=pop;
      dispose(temp);
    end;
    FPushIndex:=0;
    Fcount:=0;
    FPopIndex:=0;
  finally
    UnLock;
  end;
end;

procedure TsfQueue.setCapacity(const Value: Integer);
begin
  Lock();
  try
    Inernal_SetCapacity(Value);
  finally
    UnLock();
  end;
end;

function TsfQueue.getCapacity: Integer;
begin
  Lock();
  try
    Result := Self.FCapacity;
  finally
    UnLock();
  end;
end;

end.


