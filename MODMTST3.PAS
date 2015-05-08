uses
  Objects;

var
  f : file;
begin
  Assign(f,'cum2');
  Rewrite(f);
  close(f);
  Assign(f,'cum3');
  Rewrite(f);
  close(f);
end.
