program mypascal;

uses
  Sysutils;

const
  FNAME = 'mypascal.pas';
  nKeywords = 20;
  KW_START = 14;

type
  TTokenType = (T_IDENT=0, T_NUMBER, T_STRLITERAL,
                T_PLUS, T_MINUS, T_STAR, T_SLASH, T_EQ, T_NEQ, T_LE, T_GE, T_L, T_G, T_WALRUS,
                T_AND, T_ARRAY, T_BEGIN, T_CASE, T_CONST, T_DO, T_ELSE, T_END, T_FUNC, T_IF, T_NIL, T_NOT, T_OF, T_OR, T_PROCEDURE, T_PROG, T_THEN, T_VAR, T_WHILE, T_WRITELN,
                T_COMMA, T_PERIOD, T_CIRCUMFLEX, T_DBLPERIOD, T_LPAREN, T_RPAREN, T_LBRACK, T_RBRACK, T_COLON, T_SEMICOLON, T_UNKNOWN);

var
  fileIn: TextFile;
  kwords: array[0..nKeywords-1] of string;
  Look, _look, Look_prev: char;
  tokenType: TTokenType;
  lexeme: string;
  lineno, colno, colno_prev, col_start: integer;
  _flag: boolean;
  tokAvailable: boolean;

function ScanningDone: boolean;
begin
  if _look <> ^@ then ScanningDone := false
  else ScanningDone := Eof(fileIn);
end;

procedure GetChar;
var
  haveChar: boolean;
begin
  haveChar := false;
  if _look <> ^@ then
  begin
    Look := _look;
    _look := ^@;
    haveChar := true;
  end
  else if not Eof(fileIn) then
  begin
    Look_prev := Look;
    Read(fileIn, Look);
    haveChar := true;
  end;
  if haveChar then
  begin
    if Look = ^J then
    begin
      lineno := lineno + 1;
      colno_prev := colno;
      colno := 0;
      _flag := true;
    end
    else
    begin
      colno := colno + 1;
      _flag := false;
    end;
  end
  else Look := ^@;
end;

procedure UngetChar;
begin
  _look := Look;
  Look := Look_prev;
  if not _flag then
  begin
    colno := colno - 1;
  end
  else
  begin
    lineno := lineno - 1;
    colno := colno_prev;
  end;
end;

procedure Error(s: string);
begin
  WriteLn;
  WriteLn('Error: ', s, '.');
end;

procedure Abort(s: string);
begin
  Error(s);
  Halt;
end;

procedure Expected(s: string);
begin
  Abort(s + ' Expected');
end;

procedure Match(x: char);
begin
  if Look = x then GetChar
  else Expected('''' + x + '''');
end;

function IsAlpha(c: char): boolean;
begin
  IsAlpha := upcase(c) in ['A'..'Z'];
end;

function IsDigit(c: char): boolean;
begin
  IsDigit := c in ['0'..'9'];
end;

function IsValidIdentChar(c: char; includeDigits: boolean): boolean;
begin
  if includeDigits then IsValidIdentChar := IsAlpha(c) or (c = '_')
  else IsValidIdentChar := IsAlpha(c) or IsDigit(c) or (c = '_');
end;

function IsWhiteSpace(c: char): boolean;
begin
  case c of
    ' ', (* space *)
    ^I,  (* TAB *)
    ^J,  (* LF *)
    ^F,  (* FF *)
    ^M:  (* CR *)
      IsWhiteSpace := true;
    else
      IsWhiteSpace := false;
  end;
end;

function GetName: char;
begin
  if not IsAlpha(Look) then Expected('Name');
  GetName := UpCase(Look);
  GetChar;
end;

function GetNum: char;
begin
  if not IsDigit(Look) then Expected('Integer');
  GetNum := Look;
  GetChar;
end;

procedure Emit(s: string);
begin
  Write(^I, s);
end;

procedure EmitLn(s: string);
begin
  Emit(s);
  WriteLn;
end;

function TestLook(testCh: char; pass: TTokenType; fail: TTokenType): boolean;
begin
  GetChar;
  if Look = testCh then
  begin
    tokenType := pass;
    TestLook := true
  end
  else
  begin
    UngetChar;
    tokenType := fail;
    TestLook := false;
  end
end;

function GetToken: boolean;
var
  kword: string;
  ok, found: boolean;
  i: integer;
begin
  lexeme := '';
  if ScanningDone then
    GetToken := false
  else
  begin
    GetChar;
    ok := false;
    while not ok do
    begin
      if IsWhiteSpace(Look) then
      begin
        GetChar
      end
      else if Look = '(' then
      begin
        GetChar;
        if Look = '*' then (* confirm if it is actually a comment *)
        begin
          while true do (* TODO fix infinite loop if the source code ends with the comment initializer *)
          begin
            GetChar;
            if Look = '*' then
            begin
              GetChar;
              if Look = ')' then
              begin
                GetChar;
                Break;
              end;
            end;
          end;
        end
        else
        begin
          UngetChar;
          ok := true;
        end;
      end
      else if Eof(fileIn) then
      begin
        GetToken := false;
        Exit;
      end
      else ok := true;
    end;
    col_start := colno;
    case Look of
      '+': tokenType := T_PLUS;
      '-': tokenType := T_MINUS;
      '*': tokenType := T_STAR;
      '/': tokenType := T_SLASH;
      ':': TestLook('=', T_WALRUS, T_COLON);
      '=': tokenType := T_EQ;
      '<':
      begin
        if not TestLook('>', T_NEQ, T_L) then
          TestLook('=', T_LE, T_L)
      end;
      '>': TestLook('=', T_GE, T_G);
      ',': tokenType := T_COMMA;
      '.': TestLook('.', T_DBLPERIOD, T_PERIOD);
      '^': tokenType := T_CIRCUMFLEX;
      '''': (* beginning of string literal *)
      begin
        while true do
        begin
          GetChar;
          if Look <> '''' then
            lexeme := lexeme + Look
          else
          begin
            Break;
          end;
        end;
        tokenType := T_STRLITERAL;
      end;
      '(': tokenType := T_LPAREN;
      ')': tokenType := T_RPAREN;
      '[': tokenType := T_LBRACK;
      ']': tokenType := T_RBRACK;
      ';': tokenType := T_SEMICOLON;
    else
      if IsValidIdentChar(Look, false) then
      begin
        lexeme := '' + Look;
        while true do
        begin
          GetChar;
          if IsValidIdentChar(Look, true) then
            lexeme := lexeme + Look
          else
          begin
            UngetChar;
            Break;
          end;
        end;
        found := false;
        i := 0;
        for kword in kwords do
        begin
          if CompareText(lexeme, kword) = 0 then
          begin
            tokenType := TTokenType(KW_START + i);
            found := true;
            Break;
          end;
          i := i + 1;
        end;
        if not found then tokenType := T_IDENT;
      end
      else if IsDigit(Look) then
      begin
        lexeme := '' + Look;
        while true do
        begin
          GetChar;
          if IsDigit(Look) then
            lexeme := lexeme + Look
          else
          begin
            UngetChar;
            Break;
          end;
        end;
        tokenType := T_NUMBER;
      end
      else
      begin
        lexeme := Look;
        tokenType := T_UNKNOWN;
      end;
    end;
    GetToken := true;
  end;
end;

procedure Init;
begin
  Assign(fileIn, FNAME);
  Reset(fileIn);
  lineno := 1;
  kwords[0] := 'and';
  kwords[1] := 'array';
  kwords[2] := 'begin';
  kwords[3] := 'case';
  kwords[4] := 'const';
  kwords[5] := 'do';
  kwords[6] := 'else';
  kwords[7] := 'end';
  kwords[8] := 'function';
  kwords[9] := 'if';
  kwords[10] := 'nil';
  kwords[11] := 'not';
  kwords[12] := 'of';
  kwords[13] := 'or';
  kwords[14] := 'procedure';
  kwords[15] := 'program';
  kwords[16] := 'then';
  kwords[17] := 'var';
  kwords[18] := 'while';
  kwords[19] := 'writeln';
end;

procedure CleanUp;
begin
  Close(fileIn);
end;

begin
  Init;
  while true do
  begin
    tokAvailable := GetToken;
    if not tokAvailable then
      Break
    else
    begin
      WriteLn(tokenType, ':', lineno, ',', col_start, ': ', lexeme);
    end;
  end;
  CleanUp;
end.
