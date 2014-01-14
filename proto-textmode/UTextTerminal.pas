unit UTextTerminal;

interface

uses
	Windows, SysUtils, Classes, Types, GR32, GR32_Image;

type

	TColorArray = GR32.TArrayOfColor32;

	TTextModePalette = class

		private
			xColors : TColorArray;

			function xGetColor(Index : integer) : TColor32;
			procedure xSetColor(Index : integer; Value : TColor32);
			function xGetSize : integer;

		public
   	   constructor Create(aSize : integer);
			property Size : integer read xGetSize;
			property Colors[Index : integer] : TColor32 read xGetColor write xSetColor;

   end;

	TCGA16Palette = class(TTextModePalette)
      constructor Create;
   end;

	TTextCell = record
      c : char;
		fore, back : word;
		blink : boolean;
   end;

	TTextModeTerminal = class

		Screen : TBitmap32;

		Cursor : TPoint;

		styleForegroundColorIndex, styleBackgroundColorIndex : integer;
		styleTextBlink : boolean;

		constructor Create(aColumns, aRows : integer);

		function Columns : integer;
		function Rows : integer;

		procedure SetupFont(aFontName : string; aFontSize : integer; hMargin : integer = 0; vMargin : integer = 0);
		procedure SetupPalette(aPalette : TTextModePalette);

		function Buffer : TBitmap32;
		function Update : TBitmap32;

		procedure TextStyle(aForegroundColorIndex, aBackgroundColorIndex : integer; aTextBlink : boolean = false);
		procedure TextOut(aText : string; moveCursor : boolean = true; wrapLine : boolean = true; scroll : boolean = true);
		procedure TextOutLine(aText : string);
      procedure ScrollDown;
      function GetChar(col, row : integer) : char;
		procedure ClearMatrix;
		procedure FillMatrix(bg : integer; fg : integer = 0; ch : char = #0; bl : boolean = false);

		private
			xTextMatrix : array of array of TTextCell;
			xFontName : string;
			xFontSize : integer;
         xPalette : TTextModePalette;
			xBuffers : array [0..1] of TBitmap32;
			xActiveBuffer : integer;
			xCellDims : TPoint;
			xColumns, xRows : integer;

			procedure xDraw;
			procedure xDrawText;
   end;


implementation

	constructor TTextModePalette.Create(aSize : integer);
	begin
		setlength(xColors, aSize);
   end;

	function TTextModePalette.xGetColor(Index : integer) : TColor32;
	begin
		if (Index >= 0) and (Index < length(xColors)) then
			Result:= xColors[Index]
		else
			Result:= GR32.clBlack32;
   end;

   procedure TTextModePalette.xSetColor(Index : integer; Value : TColor32);
	begin
		if (Index >= 0) and (Index < length(xColors)) then
			xColors[Index]:= Value;
   end;

	function TTextModePalette.xGetSize : integer;
	begin
   	Result:= length(xColors);
   end;

   constructor TCGA16Palette.Create;
	begin
   	inherited Create(16);

		Colors[0]:=  Color32(0,   0,   0  );
		Colors[1]:=  Color32(0,   0,   255);
		Colors[2]:=  Color32(0,   128, 0  );
		Colors[3]:=  Color32(0,   128, 128);
		Colors[4]:=  Color32(128, 0,   0  );
		Colors[5]:=  Color32(128, 0,   128);
		Colors[6]:=  Color32(128, 128, 0  );
		Colors[7]:=  Color32(128, 128, 128);
		Colors[8]:=  Color32(64,  64,  64 );
		Colors[9]:=  Color32(32,  96,  255);
		Colors[10]:= Color32(0,   255, 0  );
		Colors[11]:= Color32(0,   255, 255);
		Colors[12]:= Color32(255, 0,   0  );
		Colors[13]:= Color32(255, 0,   255);
		Colors[14]:= Color32(255, 255, 0  );
		Colors[15]:= Color32(255, 255, 255);
   end;


   constructor TTextModeTerminal.Create(aColumns, aRows : integer);
	var buf : integer;

   begin
   	setlength(xTextMatrix, aColumns, aRows);
      xFontName:= '';
      xFontSize:= 0;
      xPalette:= nil;
      for buf:= 0 to high(xBuffers) do
			xBuffers[buf]:= TBitmap32.Create;
      xActiveBuffer:= 0;
		xColumns:= aColumns;
		xRows:= aRows;

		Cursor.X:= 0;
		Cursor.Y:= 0;
		styleForegroundColorIndex:= 0;
		styleBackgroundColorIndex:= 0;
		styleTextBlink:= false;
   end;

   function TTextModeTerminal.Columns : integer;
	begin
		Result:= xColumns;
   end;

   function TTextModeTerminal.Rows : integer;
	begin
		Result:= xRows;
   end;

	procedure TTextModeTerminal.SetupFont(aFontName : string; aFontSize : integer; hMargin, vMargin : integer);
   var buf : integer;

   begin
   	for buf:= 0 to high(xBuffers) do begin
			xBuffers[buf].Font.Name:= aFontName;
			xBuffers[buf].Font.Size:= aFontSize;
      end;

		xCellDims.X:= xBuffers[0].TextWidth('A') + hMargin;
		xCellDims.Y:= xBuffers[0].TextHeight('A') + vMargin;

   	for buf:= 0 to high(xBuffers) do
         xBuffers[buf].SetSize(xColumns*xCellDims.X, xRows*xCellDims.Y);
   end;

   procedure TTextModeTerminal.SetupPalette(aPalette : TTextModePalette);
   begin
   	xPalette:= aPalette;
   end;

   function TTextModeTerminal.Buffer : TBitmap32;
	begin
   	Result:= xBuffers[xActiveBuffer];
   end;

   function TTextModeTerminal.Update : TBitmap32;
	begin
		xDraw;
   	Screen:= Buffer;
		Result:= Buffer;
		//xActiveBuffer:= (xActiveBuffer+1) mod length(xBuffers);
   end;

   procedure TTextModeTerminal.TextStyle(aForegroundColorIndex, aBackgroundColorIndex : integer; aTextBlink : boolean = false);
	begin
   	styleForegroundColorIndex:= aForegroundColorIndex mod xPalette.Size;
   	styleBackgroundColorIndex:= aBackgroundColorIndex mod xPalette.Size;
		styleTextBlink:= aTextBlink;
   end;

   procedure TTextModeTerminal.TextOut(aText : string; moveCursor : boolean = true; wrapLine : boolean = true; scroll : boolean = true);
   var pos : TPoint;
       i : integer;

	begin
		pos:= Cursor;
		for i:= 1 to length(aText) do begin
			if pos.Y >= xRows then begin
				if not scroll then
					Break
				else begin
            	ScrollDown;
					pos.Y:= xRows-1;
					pos.X:= 0;
            end;
         end;

         with xTextMatrix[pos.X, pos.Y] do begin
         	c:= aText[i];
				fore:= styleForegroundColorIndex;
				back:= styleBackgroundColorIndex;
				blink:= styleTextBlink;
         end;

			pos.x:= pos.x + 1;
			if pos.x >= xColumns then begin
            if wrapLine then begin
					pos.x:= 0;
					pos.y:= pos.y + 1;
            end else
					Break;
         end;
      end;

		if moveCursor then
			Cursor:= pos;
   end;

	procedure TTextModeTerminal.TextOutLine(aText : string);
	begin
      TextOut(aText, true, true, true);
      Cursor.Y:= Cursor.Y+1;
		Cursor.X:= 0;
   end;

   function TTextModeTerminal.GetChar(col, row : integer) : char;
	begin
   	if (col >= 0) and (col < xColumns) and (row >= 0) and (row < xRows) then
			Result:= xTextMatrix[col, row].c
		else
			Result:= #0;
   end;

	procedure TTextModeTerminal.ScrollDown;
	var i, j : integer;

	begin
		for i:= 0 to xColumns-1 do
			for j:= 0 to xRows-1 do
				if j < xRows-1 then
					xTextMatrix[i, j]:= xTextMatrix[i, j+1]
				else begin
               with xTextMatrix[i, j] do begin
                  c:= #0;
						fore:= 0;
						back:= 0;
						blink:= false;
               end;
            end;

   end;

   procedure TTextModeTerminal.FillMatrix(bg : integer; fg : integer = 0; ch : char = #0; bl : boolean = false);
	var i, j : integer;

	begin
		for i:= 0 to xColumns-1 do
			for j:= 0 to xRows-1 do begin
         	xTextMatrix[i, j].c:= ch;
         	xTextMatrix[i, j].fore:= fg;
         	xTextMatrix[i, j].back:= bg;
         	xTextMatrix[i, j].blink:= bl;
         end;

   end;

	procedure TTextModeTerminal.ClearMatrix;
	begin
		FillMatrix(0);
   end;

   procedure TTextModeTerminal.xDraw;
   var i, j : integer;
   	 pos : TPoint;

	begin
		Buffer.Clear;

		for i:= 0 to xColumns-1 do
			for j:= 0 to xRows-1 do begin
         	pos.X:= i * xCellDims.X;
				pos.Y:= j * xCellDims.Y;

            with xTextMatrix[i, j] do begin
            	if back > 0 then
						Buffer.FillRect(pos.X, pos.Y, pos.X + xCellDims.X, pos.Y + xCellDims.Y, xPalette.Colors[back]);
               //Buffer.Font.Color:= WinColor(xPalette.Colors[fore]);
					//Buffer.Textout(pos.X, pos.Y, c);
            end;
         end;

		xDrawText;
   end;

	procedure TTextModeTerminal.xDrawText;
	var i, j, n, start : integer;
		 line : array of string;
       offsets : array of integer;
       colors : array of integer;
       s : string;
		 prevch : char;
       prevcol : integer;

   begin
		setlength(line, xColumns);
		setlength(colors, xColumns);
		setlength(offsets, xColumns);
   	for j:= 0 to xRows-1 do begin
			n:= 0;
			start:= 0;
			prevch:= #0;
			prevcol:= -1;
         s:= '';

         // Detecting monochrome continious strings
			for i:= 0 to xColumns-1 do begin
				if ((xTextMatrix[i, j].c = #0) xor (prevch = #0)) or (xTextMatrix[i, j].fore <> prevcol) then begin
					if s <> '' then begin
                  line[n]:= s;
						colors[n]:= prevcol;
						offsets[n]:= start;
						n:= n + 1;
               end;

					s:= '';
               if xTextMatrix[i, j].c <> #0 then
						start:= i;
            end;

            if xTextMatrix[i, j].c <> #0 then
					s:= s + xTextMatrix[i, j].c;

            prevch:= xTextMatrix[i, j].c;
				prevcol:= xTextMatrix[i, j].fore;
         end;

			// Drawing strings
			for i:= 0 to n-1 do begin
         	Buffer.Font.Color:= WinColor(xPalette.Colors[colors[i]]);
            Buffer.Textout(offsets[i]*xCellDims.X, j*xCellDims.Y, line[i]);
         end;
      end;
   end;
end.
