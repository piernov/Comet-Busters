brc -r comet.rc
brc -r cometenu.rc
dcc cometenu
set FLAGS=-U\delphi\source\rtl70;\bp\units;\delphi\lib -$S- -$R- -$I-
\delphi\bin\dcc -B -Dcheat -Dsplash -Dwing %FLAGS% %1 %2 %3 comet.pas
\delphi\bin\dcc -B %FLAGS% nuclwint.pas
\delphi\bin\w8loss comet.exe
\delphi\bin\w8loss nuclwint.exe
del *.dcu
