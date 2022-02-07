drop table test;
drop table test_insert;

create table test (c clob);

insert into test (c) values (
'azertyuiop
qsdfghjklm
wxcvbn
');

create table test_insert (i varchar2(100));

select * from test;

declare
    nStartIndex number := 1;
    nEndIndex number := 1;
    nLineIndex number := 0;
    vLine varchar2(2000);

    cursor c_clob is
    select c from test;

    c clob;
    -------------------------------
    procedure printout
       (p_clob in out nocopy clob) is
      offset number := 1;
      amount number := 32767;
      len    number := dbms_lob.getlength(p_clob);
      lc_buffer varchar2(32767);
      i pls_integer := 1;
    begin
      if ( dbms_lob.isopen(p_clob) != 1 ) then
        dbms_lob.open(p_clob, 0);
      end if;
      amount := instr(p_clob, chr(10), offset);
      while ( offset < len )
      loop
        dbms_lob.read(p_clob, amount, offset, lc_buffer);
        dbms_output.put_line('Line #'||i||':'||lc_buffer);
        insert into test_insert values (lc_buffer);
        
       offset := offset + amount;
       i := i + 1;
      end loop; 
          if ( dbms_lob.isopen(p_clob) = 1 ) then
        dbms_lob.close(p_clob);
      end if; 
    exception
      when others then
         dbms_output.put_line('Error : '||sqlerrm);
    end printout;
    ---------------------------
begin
    dbms_output.put_line('-----------');
    open c_clob;
    loop
       fetch c_clob into c;
       exit when c_clob%notfound;
       printout(c);
    end loop;
    close c_clob;
end;
/


select * from test_insert;

pck_ele_transacoes_monetaria
